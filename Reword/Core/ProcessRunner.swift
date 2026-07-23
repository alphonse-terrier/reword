import Foundation

enum ProcessRunnerError: LocalizedError {
    case executableNotFound(String)
    case launchFailed(String)
    case nonZeroExit(status: Int32, output: String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let path):
            return String(localized: "Executable not found:") + " \(path)"
        case .launchFailed(let detail):
            return String(localized: "Couldn't launch process:") + " \(detail)"
        case .nonZeroExit(let status, let output):
            return String(localized: "Command exited with status") + " \(status): \(output)"
        case .timedOut:
            return String(localized: "The command timed out.")
        }
    }
}

/// Runs an external process robustly, fixing the failure modes a naive `Process` + `Pipe`
/// implementation runs into:
/// - stdout/stderr are drained continuously via `readabilityHandler` while stdin is being
///   written, so output larger than the OS pipe buffer (~64 KB) can't deadlock the parent
///   waiting to write while the child blocks waiting to flush its own stdout;
/// - stdin is written with the throwing `write(contentsOf:)`, not the non-throwing
///   `write(_:)`, so a broken pipe (child exits early) surfaces as a normal Swift error
///   instead of an uncatchable Objective-C exception that crashes the app;
/// - a hard timeout terminates a stuck process instead of hanging the caller forever;
/// - cancelling the enclosing `Task` terminates the process too.
enum ProcessRunner {
    private final class OutputBox: @unchecked Sendable {
        private let lock = NSLock()
        private var stdoutData = Data()
        private var stderrData = Data()
        private var timedOut = false

        func appendStdout(_ data: Data) { lock.withLock { stdoutData.append(data) } }
        func appendStderr(_ data: Data) { lock.withLock { stderrData.append(data) } }
        func markTimedOut() { lock.withLock { timedOut = true } }

        func snapshot() -> (stdout: String, stderr: String, timedOut: Bool) {
            lock.withLock {
                (
                    String(data: stdoutData, encoding: .utf8) ?? "",
                    String(data: stderrData, encoding: .utf8) ?? "",
                    timedOut
                )
            }
        }
    }

    /// Runs `executablePath` with `arguments`, optionally feeding `stdin`, and returns stdout.
    /// Throws `ProcessRunnerError` on a missing executable, launch failure, non-zero exit, or
    /// timeout.
    static func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String]? = nil,
        stdin: String? = nil,
        timeout: TimeInterval = 60
    ) async throws -> String {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw ProcessRunnerError.executableNotFound(executablePath)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        if let environment { process.environment = environment }

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        if stdin != nil { process.standardInput = stdinPipe }
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let box = OutputBox()
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { box.appendStdout(data) }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { box.appendStderr(data) }
        }

        return try await withTaskCancellationHandler(
            operation: {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                    let timeoutItem = DispatchWorkItem {
                        box.markTimedOut()
                        if process.isRunning { process.terminate() }
                    }
                    DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutItem)

                    process.terminationHandler = { finished in
                        timeoutItem.cancel()
                        stdoutPipe.fileHandleForReading.readabilityHandler = nil
                        stderrPipe.fileHandleForReading.readabilityHandler = nil
                        let (stdout, stderr, timedOut) = box.snapshot()

                        if timedOut {
                            continuation.resume(throwing: ProcessRunnerError.timedOut)
                        } else if finished.terminationStatus != 0 {
                            let trimmedStderr = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                            let detail = trimmedStderr.isEmpty ? stdout : trimmedStderr
                            continuation.resume(throwing: ProcessRunnerError.nonZeroExit(status: finished.terminationStatus, output: detail))
                        } else {
                            continuation.resume(returning: stdout)
                        }
                    }

                    do {
                        try process.run()
                        if let stdin {
                            let writer = stdinPipe.fileHandleForWriting
                            let data = Data(stdin.utf8)
                            DispatchQueue.global().async {
                                do {
                                    try writer.write(contentsOf: data)
                                } catch {
                                    // A broken pipe here just means the child exited before
                                    // reading all of stdin — the termination handler above
                                    // will still fire and report the real failure.
                                }
                                try? writer.close()
                            }
                        }
                    } catch {
                        timeoutItem.cancel()
                        stdoutPipe.fileHandleForReading.readabilityHandler = nil
                        stderrPipe.fileHandleForReading.readabilityHandler = nil
                        continuation.resume(throwing: ProcessRunnerError.launchFailed(error.localizedDescription))
                    }
                }
            },
            onCancel: {
                if process.isRunning { process.terminate() }
            }
        )
    }
}
