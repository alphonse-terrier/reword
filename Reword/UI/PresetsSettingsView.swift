import SwiftUI
import KeyboardShortcuts

struct PresetsSettingsView: View {
    @Bindable var settings: AppSettings
    @State private var selectedPresetID: UUID?
    @State private var presetPendingDeletion: Preset?

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $selectedPresetID) {
                ForEach(settings.presets) { preset in
                    Text(displayName(for: preset))
                        .tag(preset.id)
                }
                .onMove { indices, newOffset in
                    settings.presets.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .frame(width: 180)
            .overlay(alignment: .bottom) {
                HStack {
                    Button(action: addPreset) { Image(systemName: "plus") }
                        .accessibilityLabel(Text("Add preset"))
                    Button(action: confirmRemoveSelected) { Image(systemName: "minus") }
                        .accessibilityLabel(Text("Remove preset"))
                        .disabled(selectedPresetID == nil || settings.presets.count <= 1)
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
        .onDisappear { SettingsStore.save(settings) }
        .confirmationDialog(
            "Delete preset?",
            isPresented: Binding(
                get: { presetPendingDeletion != nil },
                set: { if !$0 { presetPendingDeletion = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let preset = presetPendingDeletion { remove(preset) }
            }
            Button("Cancel", role: .cancel) { presetPendingDeletion = nil }
        } message: {
            Text("This can't be undone. Any dedicated shortcut for this preset will stop working.")
        }
    }

    private func displayName(for preset: Preset) -> String {
        let trimmed = preset.name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? String(localized: "Untitled preset") : trimmed
    }

    @ViewBuilder
    private func presetEditor(index: Int) -> some View {
        Form {
            Section("Name") {
                TextField("Preset name", text: $settings.presets[index].name)
                    .textFieldStyle(.roundedBorder)
                if settings.presets[index].name.trimmingCharacters(in: .whitespaces).isEmpty {
                    validationWarning("Give this preset a name so it's recognizable in the menu.")
                }
            }

            Section("System Prompt") {
                TextEditor(text: $settings.presets[index].systemPrompt)
                    .frame(minHeight: 140)
                    .font(.body)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
                if settings.presets[index].systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    validationWarning("No instructions — the AI will get no guidance beyond the language instruction, if any.")
                }
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

    @ViewBuilder
    private func validationWarning(_ message: LocalizedStringKey) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
    }

    private func addPreset() {
        let preset = Preset(name: "New preset", systemPrompt: "Rephrase the following text.")
        settings.presets.append(preset)
        selectedPresetID = preset.id
    }

    private func confirmRemoveSelected() {
        guard let id = selectedPresetID, let preset = settings.presets.first(where: { $0.id == id }) else { return }
        presetPendingDeletion = preset
    }

    private func remove(_ preset: Preset) {
        guard let index = settings.presets.firstIndex(where: { $0.id == preset.id }) else { return }
        settings.presets.remove(at: index)

        // Clear the deleted preset's dedicated shortcut so it doesn't linger and silently
        // fall back to whatever preset ends up active.
        KeyboardShortcuts.removeHandler(for: .forPreset(preset.id))
        KeyboardShortcuts.reset(.forPreset(preset.id))

        if settings.activePresetID == preset.id {
            settings.activePresetID = settings.presets.first?.id
        }
        selectedPresetID = settings.presets.first?.id
        presetPendingDeletion = nil
    }
}
