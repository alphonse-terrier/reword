import Foundation

/// Ready-made "Custom Command" starting points shown in Settings, since hand-writing the right
/// CLI invocation for each tool is the biggest friction point in configuring this provider.
/// Users can freely edit the command/arguments after loading one — these are starting points,
/// not guarantees every flag matches every version of every tool.
struct CommandPreset: Identifiable {
    let id = UUID()
    let name: String
    let executable: String
    let arguments: [String]
    let defaultModel: String
}

enum CommandPresets {
    static let all: [CommandPreset] = [
        CommandPreset(
            name: "Claude Code CLI",
            executable: "claude",
            arguments: ["-p", "--system-prompt", "{system}", "--model", "{model}"],
            defaultModel: "haiku"
        ),
        CommandPreset(
            name: "Ollama (ollama run)",
            executable: "ollama",
            arguments: ["run", "{model}"],
            defaultModel: "llama3"
        ),
        CommandPreset(
            name: "Gemini CLI",
            executable: "gemini",
            arguments: ["-p", "{system}", "-m", "{model}"],
            defaultModel: "gemini-2.5-flash"
        ),
        CommandPreset(
            name: "llm (Simon Willison)",
            executable: "llm",
            arguments: ["-s", "{system}", "-m", "{model}"],
            defaultModel: "gpt-4o-mini"
        ),
    ]
}
