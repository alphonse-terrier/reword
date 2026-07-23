import Foundation
import KeyboardShortcuts

/// Wires global keyboard shortcuts (default + per-preset) to a reformulation callback.
/// Built on `KeyboardShortcuts`, which handles OS-level registration and persists bindings
/// itself, so `AppSettings`/`SettingsStore` don't need to store the key combos.
@MainActor
final class HotkeyManager {
    private var onReformulate: (UUID?) -> Void
    private var registeredPresetIDs: Set<UUID> = []

    init(onReformulate: @escaping (UUID?) -> Void) {
        self.onReformulate = onReformulate
    }

    /// Registers the default shortcut plus one shortcut per preset, and unregisters bindings for
    /// presets that no longer exist — otherwise a deleted preset's old shortcut keeps firing and
    /// silently falls back to whatever preset is currently active, which is surprising.
    func registerShortcuts(for presets: [Preset]) {
        KeyboardShortcuts.onKeyUp(for: .reformulateDefault) { [weak self] in
            self?.onReformulate(nil)
        }

        let currentIDs = Set(presets.map(\.id))

        for staleID in registeredPresetIDs.subtracting(currentIDs) {
            unregister(presetID: staleID)
        }

        for preset in presets {
            let name = KeyboardShortcuts.Name.forPreset(preset.id)
            KeyboardShortcuts.onKeyUp(for: name) { [weak self] in
                self?.onReformulate(preset.id)
            }
        }

        registeredPresetIDs = currentIDs
    }

    /// Clears the persisted shortcut and handler for a single deleted preset immediately,
    /// without waiting for the next full `registerShortcuts` call.
    func unregister(presetID: UUID) {
        let name = KeyboardShortcuts.Name.forPreset(presetID)
        KeyboardShortcuts.removeHandler(for: name)
        KeyboardShortcuts.reset(name)
        registeredPresetIDs.remove(presetID)
    }
}
