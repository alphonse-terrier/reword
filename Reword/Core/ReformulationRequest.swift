import Foundation

/// An immutable, `Sendable` snapshot of everything a reformulation needs, captured on the main
/// actor from `AppSettings` before handing work off to a background `Task` — this is what keeps
/// the pipeline from reading mutable, main-actor-isolated settings off the main actor while a
/// request is in flight (e.g. if the user edits Settings mid-request).
struct ReformulationRequest: Sendable {
    let providerType: ProviderType
    let baseURL: String
    let model: String
    let apiKey: String
    let commandExecutable: String
    let commandArgumentsLine: String
    let systemPrompt: String
    let restorePasteboard: Bool
    let replacementMode: TextReplacementMode

    func makeProvider() -> LLMProvider {
        LLMProviderFactory.make(
            providerType: providerType,
            baseURL: baseURL,
            model: model,
            apiKey: apiKey,
            commandExecutable: commandExecutable,
            commandArgumentsLine: commandArgumentsLine
        )
    }
}
