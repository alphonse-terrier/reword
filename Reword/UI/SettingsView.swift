import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        TabView {
            ProviderSettingsView(settings: settings)
                .tabItem { Label("Provider", systemImage: "cpu") }

            PresetsSettingsView(settings: settings)
                .tabItem { Label("Presets", systemImage: "list.bullet") }

            GeneralSettingsView(settings: settings)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .padding(20)
        .frame(minWidth: 560, idealWidth: 680, minHeight: 460, idealHeight: 620)
    }
}

private struct GeneralSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                KeyboardShortcutRow(
                    name: .reformulateDefault,
                    label: "Rephrase with the active preset"
                )
            } header: {
                Text("Global Shortcut")
            } footer: {
                Text("Each preset can also have its own dedicated shortcut — set those in the Presets tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Restore clipboard after replacement", isOn: $settings.restorePasteboard)
                    .help("Only matters when Reword falls back to copy/paste — apps with direct Accessibility support never touch the clipboard.")
            } header: {
                Text("Clipboard")
            }

            Section {
                TextEditor(text: $settings.languageInstruction)
                    .frame(minHeight: 80)
                    .font(.body)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
                HStack {
                    Text("Applied before every preset's system prompt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset to Default") {
                        settings.languageInstruction = AppSettings.defaultLanguageInstruction
                    }
                    .font(.caption)
                    .disabled(settings.languageInstruction == AppSettings.defaultLanguageInstruction)
                }
            } header: {
                Text("Language")
            }
        }
        .formStyle(.grouped)
        .onDisappear { SettingsStore.save(settings) }
    }
}
