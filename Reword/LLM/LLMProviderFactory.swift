import Foundation

/// Single place that maps a provider configuration to its `LLMProvider` implementation, shared
/// by the live reformulation pipeline (`ReformulationRequest`) and the Settings UI's "Test
/// Connection" (`AppSettings.makeProvider`), so the two can never drift apart.
enum LLMProviderFactory {
    static func make(
        providerType: ProviderType,
        baseURL: String,
        model: String,
        apiKey: String,
        commandExecutable: String,
        commandArgumentsLine: String
    ) -> LLMProvider {
        switch providerType {
        case .openAICompatible:
            return OpenAICompatibleProvider(baseURL: baseURL, apiKey: apiKey, model: model)
        case .anthropic:
            return AnthropicProvider(baseURL: baseURL, apiKey: apiKey, model: model)
        case .ollama:
            return OllamaProvider(host: baseURL, model: model)
        case .claudeCLI:
            let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
            return ClaudeCLIProvider(model: trimmedModel.isEmpty ? ProviderType.claudeCLI.defaultModel : trimmedModel)
        case .customCommand:
            return CommandProvider(
                executable: commandExecutable,
                arguments: ShellLikeTokenizer.tokenize(commandArgumentsLine),
                model: model
            )
        }
    }
}
