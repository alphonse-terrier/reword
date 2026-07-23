import Foundation

struct TimeoutError: LocalizedError {
    var errorDescription: String? {
        String(localized: "The request took too long and was cancelled.")
    }
}

/// Races `operation` against a timer; if the timer wins, `operation`'s task is cancelled (best
/// effort — cooperative primitives like `URLSession` and `ProcessRunner` both react to
/// cancellation) and `TimeoutError` is thrown instead of whatever `operation` eventually does.
func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        defer { group.cancelAll() }
        guard let result = try await group.next() else {
            throw TimeoutError()
        }
        return result
    }
}
