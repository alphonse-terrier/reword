import Foundation

/// Resolves executables and captures the user's login-shell environment, shared by any provider
/// that shells out to a locally-installed CLI (Claude CLI, generic custom commands). Caches are
/// protected by a lock since provider calls can run concurrently.
enum ShellEnvironment {
    private static let lock = NSLock()
    private static var pathCache: [String: String] = [:]
    private static var environmentCache: [String: String]?

    /// Resolves `name` to an absolute executable path: returns it as-is if already absolute
    /// (after validating it's executable), checks a few common install locations, then falls
    /// back to `command -v` in the user's login shell.
    static func resolvePath(for name: String) throws -> String {
        if name.hasPrefix("/") {
            guard FileManager.default.isExecutableFile(atPath: name) else {
                throw ProcessRunnerError.executableNotFound(name)
            }
            return name
        }

        lock.lock()
        if let cached = pathCache[name] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let candidates = [
            "\(NSHomeDirectory())/.claude/local/\(name)",
            "\(NSHomeDirectory())/.local/bin/\(name)",
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
        ]
        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            lock.lock(); pathCache[name] = candidate; lock.unlock()
            return candidate
        }

        if let resolved = try? runLoginShell("command -v \(name)"),
           resolved.hasPrefix("/"),
           FileManager.default.isExecutableFile(atPath: resolved) {
            lock.lock(); pathCache[name] = resolved; lock.unlock()
            return resolved
        }

        throw ProcessRunnerError.executableNotFound(name)
    }

    /// The user's login-shell environment (PATH plus everything else), so wrapper scripts that
    /// shell out to other tools (nvm, asdf, custom agent shims) resolve the same as they would
    /// in a real terminal.
    static func loginEnvironment() -> [String: String] {
        lock.lock()
        if let cached = environmentCache {
            lock.unlock()
            return cached
        }
        lock.unlock()

        var env = ProcessInfo.processInfo.environment
        if let path = try? runLoginShell("printf '%s' \"$PATH\""), !path.isEmpty {
            env["PATH"] = path
        }
        // Some Claude Code hook setups (e.g. the Superset agent wrapper) fire a sound/notification
        // on session start/stop keyed off this variable. Reword's calls are quick one-shot
        // rephrasings, not sessions the user is watching, so silence that here — this only
        // affects the process Reword launches, not the user's normal terminal sessions.
        env.removeValue(forKey: "SUPERSET_HOME_DIR")

        lock.lock(); environmentCache = env; lock.unlock()
        return env
    }

    private static func runLoginShell(_ command: String) throws -> String {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-l", "-c", command]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
