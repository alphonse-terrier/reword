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
            Section("Fournisseur") {
                Picker("Type", selection: $settings.providerType) {
                    ForEach(ProviderType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .onChange(of: settings.providerType) { _, _ in
                    settings.resetBaseURLAndModelToDefaults()
                }

                TextField(settings.providerType == .ollama ? "Host" : "Base URL", text: $settings.baseURL)
                    .textFieldStyle(.roundedBorder)

                if settings.providerType != .ollama {
                    SecureField("Clé API", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: apiKey) { _, newValue in
                            SettingsStore.saveAPIKey(newValue)
                        }
                }

                TextField("Modèle", text: $settings.model)
                    .textFieldStyle(.roundedBorder)
            }

            Section {
                HStack {
                    Button("Tester la connexion") { testConnection() }
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
                    text: "Ceci est un test.",
                    systemPrompt: "Réponds uniquement par le mot OK."
                )
                testState = .success
            } catch {
                testState = .failure(error.localizedDescription)
            }
        }
    }
}
