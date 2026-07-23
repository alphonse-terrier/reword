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
        .frame(width: 560, height: 420)
    }
}

private struct GeneralSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Global Shortcut") {
                KeyboardShortcutRow(
                    name: .reformulateDefault,
                    label: "Rephrase with the active preset"
                )
            }

            Section("Clipboard") {
                Toggle("Restore clipboard after replacement", isOn: $settings.restorePasteboard)
            }

            Section("Language") {
                TextEditor(text: $settings.languageInstruction)
                    .frame(minHeight: 80)
                    .font(.body)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
                Text("Applied before every preset's system prompt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onDisappear { SettingsStore.save(settings) }
    }
}
