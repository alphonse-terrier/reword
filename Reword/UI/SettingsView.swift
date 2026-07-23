import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        TabView {
            ProviderSettingsView(settings: settings)
                .tabItem { Label("Fournisseur", systemImage: "cpu") }

            PresetsSettingsView(settings: settings)
                .tabItem { Label("Presets", systemImage: "list.bullet") }

            GeneralSettingsView(settings: settings)
                .tabItem { Label("Général", systemImage: "gearshape") }
        }
        .padding(20)
        .frame(width: 560, height: 420)
    }
}

private struct GeneralSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Raccourci global") {
                KeyboardShortcutRow(
                    name: .reformulateDefault,
                    label: "Reformuler avec le preset actif"
                )
            }

            Section("Presse-papiers") {
                Toggle("Restaurer le presse-papiers après remplacement", isOn: $settings.restorePasteboard)
            }
        }
        .formStyle(.grouped)
    }
}
