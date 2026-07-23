import Foundation
import Observation

/// The single source of truth for user configuration: which provider is active, its connection
/// details, the list of reformulation presets, and which preset the default shortcut applies to.
/// API keys are NOT stored here — they live in the Keychain, see `SettingsStore`.
@Observable
final class AppSettings {
    var providerType: ProviderType = .openAICompatible
    var baseURL: String = ProviderType.openAICompatible.defaultBaseURL
    var model: String = ProviderType.openAICompatible.defaultModel

    var presets: [Preset] = Preset.defaults
    /// Which preset is applied when the user presses the default global shortcut.
    var activePresetID: UUID?

    /// Whether to restore the user's previous pasteboard contents after pasting the result.
    var restorePasteboard: Bool = true

    init() {
        activePresetID = presets.first?.id
    }

    var activePreset: Preset? {
        presets.first { $0.id == activePresetID } ?? presets.first
    }

    func resetBaseURLAndModelToDefaults() {
        baseURL = providerType.defaultBaseURL
        model = providerType.defaultModel
    }

    func makeProvider(apiKey: String) -> LLMProvider {
        switch providerType {
        case .openAICompatible:
            return OpenAICompatibleProvider(baseURL: baseURL, apiKey: apiKey, model: model)
        case .anthropic:
            return AnthropicProvider(baseURL: baseURL, apiKey: apiKey, model: model)
        case .ollama:
            return OllamaProvider(host: baseURL, model: model)
        }
    }
}
