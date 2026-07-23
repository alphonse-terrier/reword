import SwiftUI

struct ProviderSettingsView: View {
    @Bindable var settings: AppSettings
    @State private var apiKey: String = ""
    @State private var testState: TestState = .idle
    @State private var testTask: Task<Void, Never>?

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
                .onChange(of: settings.providerType) { _, newValue in
                    settings.resetBaseURLAndModelToDefaults()
                    reloadAPIKey(for: newValue)
                    testState = .idle
                }

                if settings.providerType == .ollama {
                    TextField("Host", text: $settings.baseURL)
                        .textFieldStyle(.roundedBorder)
                } else if settings.providerType == .openAICompatible || settings.providerType == .anthropic {
                    TextField("Base URL", text: $settings.baseURL)
                        .textFieldStyle(.roundedBorder)
                    if !isValidHTTPURL(settings.baseURL) {
                        validationWarning("Enter a valid http(s) URL.")
                    }
                }

                if settings.providerType == .openAICompatible || settings.providerType == .anthropic {
                    SecureField("API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: apiKey) { _, newValue in
                            SettingsStore.saveAPIKey(newValue, for: settings.providerType)
                        }
                }

                if settings.providerType == .customCommand {
                    Menu("Load a Command Preset…") {
                        ForEach(CommandPresets.all) { preset in
                            Button(preset.name) { apply(preset) }
                        }
                    }

                    TextField("Command", text: $settings.commandExecutable)
                        .textFieldStyle(.roundedBorder)
                    if settings.commandExecutable.trimmingCharacters(in: .whitespaces).isEmpty {
                        validationWarning("Enter the command to run, e.g. \"claude\" or \"ollama\".")
                    }

                    TextField("Arguments", text: $settings.commandArgumentsLine)
                        .textFieldStyle(.roundedBorder)
                    Text("Use {system} and {model} as placeholders; the selected text is sent on stdin.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    if settings.model.trimmingCharacters(in: .whitespaces).isEmpty {
                        validationWarning("Enter a model name.")
                    }
                case .customCommand:
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
                            .lineLimit(3)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { reloadAPIKey(for: settings.providerType) }
        .onDisappear {
            SettingsStore.save(settings)
            testTask?.cancel()
        }
    }

    private func apply(_ preset: CommandPreset) {
        settings.commandExecutable = preset.executable
        settings.commandArgumentsLine = preset.arguments.joined(separator: " ")
        if settings.model.trimmingCharacters(in: .whitespaces).isEmpty {
            settings.model = preset.defaultModel
        }
    }

    private func reloadAPIKey(for provider: ProviderType) {
        apiKey = SettingsStore.loadAPIKey(for: provider)
    }

    private func isValidHTTPURL(_ string: String) -> Bool {
        guard
            let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            url.host != nil
        else { return false }
        return true
    }

    @ViewBuilder
    private func validationWarning(_ message: LocalizedStringKey) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
    }

    private func testConnection() {
        testState = .testing
        testTask?.cancel()
        let provider = settings.makeProvider(apiKey: apiKey)
        testTask = Task {
            do {
                _ = try await withTimeout(seconds: 20) {
                    try await provider.reformulate(
                        text: "This is a test.",
                        systemPrompt: "Reply with only the word OK."
                    )
                }
                guard !Task.isCancelled else { return }
                testState = .success
            } catch {
                guard !Task.isCancelled else { return }
                testState = .failure(error.localizedDescription)
            }
        }
    }
}
