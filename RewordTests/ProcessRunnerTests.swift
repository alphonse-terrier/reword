import XCTest
@testable import Reword

final class ProcessRunnerTests: XCTestCase {
    func testCapturesStdout() async throws {
        let output = try await ProcessRunner.run(executablePath: "/bin/echo", arguments: ["hello"])
        XCTAssertEqual(output.trimmingCharacters(in: .whitespacesAndNewlines), "hello")
    }

    func testEchoesStdin() async throws {
        let output = try await ProcessRunner.run(executablePath: "/bin/cat", arguments: [], stdin: "round trip")
        XCTAssertEqual(output, "round trip")
    }

    func testThrowsOnMissingExecutable() async throws {
        do {
            _ = try await ProcessRunner.run(executablePath: "/no/such/binary", arguments: [])
            XCTFail("Expected executableNotFound error")
        } catch ProcessRunnerError.executableNotFound {
            // expected
        }
    }

    func testThrowsOnNonZeroExit() async throws {
        do {
            _ = try await ProcessRunner.run(executablePath: "/bin/sh", arguments: ["-c", "exit 3"])
            XCTFail("Expected nonZeroExit error")
        } catch ProcessRunnerError.nonZeroExit(let status, _) {
            XCTAssertEqual(status, 3)
        }
    }

    func testTimesOutOnStuckProcess() async throws {
        do {
            _ = try await ProcessRunner.run(executablePath: "/bin/sleep", arguments: ["5"], timeout: 0.3)
            XCTFail("Expected timedOut error")
        } catch ProcessRunnerError.timedOut {
            // expected
        }
    }

    /// Regression test for the pipe-buffer deadlock: writing more stdin than the OS pipe buffer
    /// (~64 KB) to a process that echoes it straight back used to hang forever when stdin was
    /// fully written before any stdout was read.
    func testHandlesLargeStdinWithoutDeadlock() async throws {
        let largeInput = String(repeating: "x", count: 300_000)
        let output = try await ProcessRunner.run(executablePath: "/bin/cat", arguments: [], stdin: largeInput, timeout: 15)
        XCTAssertEqual(output, largeInput)
    }
}
