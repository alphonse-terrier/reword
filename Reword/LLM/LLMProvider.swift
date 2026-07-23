import Foundation

/// The kind of backend the user has configured. Each case maps to one `LLMProvider` implementation.
enum ProviderType: String, Codable, CaseIterable, Identifiable {
    case openAICompatible
    case anthropic
    case ollama

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAICompatible: return "API OpenAI-compatible"
        case .anthropic: return "Anthropic (Claude)"
        case .ollama: return "Ollama natif"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openAICompatible: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com"
        case .ollama: return "http://localhost:11434"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAICompatible: return "gpt-4o-mini"
        case .anthropic: return "claude-sonnet-5"
        case .ollama: return "llama3"
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
            return "Le modèle n'a renvoyé aucun texte."
        case .invalidResponse(let detail):
            return "Réponse invalide du fournisseur : \(detail)"
        case .httpError(let code, let body):
            return "Erreur HTTP \(code) : \(body)"
        case .network(let error):
            return "Erreur réseau : \(error.localizedDescription)"
        }
    }
}

/// Common interface implemented by every LLM backend Reword can talk to.
protocol LLMProvider {
    /// Sends `text` to the model with `systemPrompt` as instructions and returns the rewritten text.
    func reformulate(text: String, systemPrompt: String) async throws -> String
}

extension LLMProvider {
    /// Strips common wrapping the model sometimes adds despite instructions (quotes, code fences).
    func cleaned(_ raw: String) -> String {
        var result = raw.trimmingCharacters(in: .whitespacesAndNewlines)
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
