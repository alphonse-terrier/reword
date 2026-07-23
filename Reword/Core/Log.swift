import os

/// Centralized `Logger` instances, one per subsystem, so `log stream --predicate` and Console.app
/// can filter Reword's diagnostics without grepping through unrelated system noise.
enum Log {
    private static let subsystem = "com.polyconseil.alphonse.Reword"

    /// The reformulation pipeline: capture → provider call → replace.
    static let pipeline = Logger(subsystem: subsystem, category: "pipeline")
    /// LLM provider calls (HTTP and CLI/process-based).
    static let provider = Logger(subsystem: subsystem, category: "provider")
    /// Text capture/replacement strategies (Accessibility, pasteboard).
    static let textReplace = Logger(subsystem: subsystem, category: "textReplace")
    /// Settings persistence and migration.
    static let settings = Logger(subsystem: subsystem, category: "settings")
}
