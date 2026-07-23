import SwiftUI

struct ProviderSettingsView: View {
    @Bindable var settings: AppSettings
    @State private var apiKey: String = SettingsStore.loadAPIKey()
    @State private var testState: TestState = .idle

    enum TestState: Equatable {
        case idle, testing, success, failure(String)
    }

    var body: some View {
        Form {
            Section("Provider") {
                Picker("Type", selection: $settings.providerType) {
                    ForEach(ProviderType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .onChange(of: settings.providerType) { _, _ in
                    settings.resetBaseURLAndModelToDefaults()
                }

                if settings.providerType == .ollama {
                    TextField("Host", text: $settings.baseURL)
                        .textFieldStyle(.roundedBorder)
                } else if settings.providerType != .claudeCLI {
                    TextField("Base URL", text: $settings.baseURL)
                        .textFieldStyle(.roundedBorder)
                }

                if settings.providerType != .ollama && settings.providerType != .claudeCLI {
                    SecureField("API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: apiKey) { _, newValue in
                            SettingsStore.saveAPIKey(newValue)
                        }
                }

                switch settings.providerType {
                case .anthropic:
                    Picker("Model", selection: $settings.model) {
                        ForEach(ClaudeModels.apiChoices) { choice in
                            Text(choice.label).tag(choice.id)
                        }
                    }
                case .claudeCLI:
                    Picker("Model", selection: $settings.model) {
                        Text("CLI default").tag("")
                        ForEach(ClaudeModels.cliChoices) { choice in
                            Text(choice.label).tag(choice.id)
                        }
                    }
                case .openAICompatible, .ollama:
                    TextField("Model", text: $settings.model)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Section {
                HStack {
                    Button("Test Connection") { testConnection() }
                        .disabled(testState == .testing)

                    switch testState {
                    case .idle: EmptyView()
                    case .testing: ProgressView().controlSize(.small)
                    case .success: Label("OK", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    case .failure(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onDisappear { SettingsStore.save(settings) }
    }

    private func testConnection() {
        testState = .testing
        let provider = settings.makeProvider(apiKey: apiKey)
        Task {
            do {
                _ = try await provider.reformulate(
                    text: "This is a test.",
                    systemPrompt: "Reply with only the word OK."
                )
                testState = .success
            } catch {
                testState = .failure(error.localizedDescription)
            }
        }
    }
}
