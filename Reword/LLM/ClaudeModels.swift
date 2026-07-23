import Foundation

/// Curated Claude model choices shown as a picker instead of a free-text field, since both the
/// Anthropic API and the Claude CLI only ever talk to this fixed set of models.
struct ClaudeModelChoice: Identifiable, Hashable {
    /// The exact value stored in `AppSettings.model` and sent to the backend.
    let id: String
    let label: String
}

enum ClaudeModels {
    /// Model IDs as expected by the Anthropic Messages API.
    static let apiChoices: [ClaudeModelChoice] = [
        ClaudeModelChoice(id: "claude-opus-4-8", label: "Opus 4.8"),
        ClaudeModelChoice(id: "claude-sonnet-5", label: "Sonnet 5"),
        ClaudeModelChoice(id: "claude-haiku-4-5-20251001", label: "Haiku 4.5"),
    ]

    /// Short aliases accepted by the `claude` CLI's `--model` flag.
    static let cliChoices: [ClaudeModelChoice] = [
        ClaudeModelChoice(id: "opus", label: "Opus 4.8"),
        ClaudeModelChoice(id: "sonnet", label: "Sonnet 5"),
        ClaudeModelChoice(id: "haiku", label: "Haiku 4.5"),
    ]
}
