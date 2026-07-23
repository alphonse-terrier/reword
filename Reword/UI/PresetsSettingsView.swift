import SwiftUI
import KeyboardShortcuts

struct PresetsSettingsView: View {
    @Bindable var settings: AppSettings
    @State private var selectedPresetID: UUID?

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $selectedPresetID) {
                ForEach(settings.presets) { preset in
                    Text(preset.name).tag(preset.id)
                }
                .onMove { indices, newOffset in
                    settings.presets.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .frame(width: 180)
            .overlay(alignment: .bottom) {
                HStack {
                    Button(action: addPreset) { Image(systemName: "plus") }
                    Button(action: removeSelected) { Image(systemName: "minus") }
                        .disabled(selectedPresetID == nil)
                }
                .padding(6)
            }

            Divider()

            if let index = settings.presets.firstIndex(where: { $0.id == selectedPresetID }) {
                presetEditor(index: index)
                    .padding()
            } else {
                Text("Select or create a preset")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if selectedPresetID == nil { selectedPresetID = settings.presets.first?.id }
        }
    }

    @ViewBuilder
    private func presetEditor(index: Int) -> some View {
        Form {
            Section("Name") {
                TextField("Preset name", text: $settings.presets[index].name)
                    .textFieldStyle(.roundedBorder)
            }

            Section("System Prompt") {
                TextEditor(text: $settings.presets[index].systemPrompt)
                    .frame(minHeight: 140)
                    .font(.body)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
            }

            Section("Dedicated Shortcut (optional)") {
                KeyboardShortcutRow(
                    name: .forPreset(settings.presets[index].id),
                    label: "Apply this preset directly"
                )
            }
        }
        .formStyle(.grouped)
    }

    private func addPreset() {
        let preset = Preset(name: "New preset", systemPrompt: "Rephrase the following text.")
        settings.presets.append(preset)
        selectedPresetID = preset.id
    }

    private func removeSelected() {
        guard let id = selectedPresetID, let index = settings.presets.firstIndex(where: { $0.id == id }) else { return }
        settings.presets.remove(at: index)
        selectedPresetID = settings.presets.first?.id
    }
}
