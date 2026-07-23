import Foundation

/// The kind of backend the user has configured. Each case maps to one `LLMProvider` implementation.
enum ProviderType: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAICompatible
    case anthropic
    case ollama
    case claudeCLI
    case customCommand

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAICompatible: return String(localized: "OpenAI-compatible API")
        case .anthropic: return String(localized: "Anthropic (Claude)")
        case .ollama: return String(localized: "Ollama (native)")
        case .claudeCLI: return String(localized: "Claude CLI (claude -p)")
        case .customCommand: return String(localized: "Custom Command")
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openAICompatible: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com"
        case .ollama: return "http://localhost:11434"
        case .claudeCLI, .customCommand: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .openAICompatible: return "gpt-4o-mini"
        case .anthropic: return "claude-sonnet-5"
        case .ollama: return "llama3"
        case .claudeCLI: return "haiku"
        case .customCommand: return ""
        }
    }
}

enum LLMError: LocalizedError {
    case emptyResponse
    case invalidResponse(String)
    case httpError(Int, String)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return String(localized: "The model returned no text.")
        case .invalidResponse(let detail):
            return String(localized: "Invalid response from provider:") + " \(detail)"
        case .httpError(let code, let body):
            return String(localized: "HTTP error") + " \(code): \(body)"
        case .network(let error):
            return String(localized: "Network error:") + " \(error.localizedDescription)"
        }
    }
}

/// Common interface implemented by every LLM backend Reword can talk to. `Sendable` so a
/// provider value built on the main actor can be safely passed into a background `Task`.
protocol LLMProvider: Sendable {
    /// Sends `text` to the model with `systemPrompt` as instructions and returns the rewritten text.
    func reformulate(text: String, systemPrompt: String) async throws -> String
}

extension LLMProvider {
    /// Strips common wrapping the model sometimes adds despite instructions (reasoning blocks,
    /// quotes, code fences).
    func cleaned(_ raw: String) -> String {
        var result = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Some reasoning-capable models emit their chain of thought inline even when asked not
        // to; strip it rather than pasting it into the user's document.
        while let range = result.range(of: "<think>[\\s\\S]*?</think>", options: [.regularExpression, .caseInsensitive]) {
            result.removeSubrange(range)
        }
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        if result.hasPrefix("```") {
            result = result.replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if result.count >= 2, result.hasPrefix("\""), result.hasSuffix("\"") {
            result = String(result.dropFirst().dropLast())
        }
        return result
    }
}
