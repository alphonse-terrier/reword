import Foundation
import KeyboardShortcuts

/// Wires global keyboard shortcuts (default + per-preset) to a reformulation callback.
/// Built on `KeyboardShortcuts`, which handles OS-level registration and persists bindings
/// itself, so `AppSettings`/`SettingsStore` don't need to store the key combos.
final class HotkeyManager {
    private var onReformulate: (UUID?) -> Void

    init(onReformulate: @escaping (UUID?) -> Void) {
        self.onReformulate = onReformulate
    }

    /// Registers the default shortcut plus one shortcut per preset. Call again (e.g. after the
    /// preset list changes) to pick up newly added presets — existing bindings are untouched.
    func registerShortcuts(for presets: [Preset]) {
        KeyboardShortcuts.onKeyUp(for: .reformulateDefault) { [weak self] in
            self?.onReformulate(nil)
        }

        for preset in presets {
            let name = KeyboardShortcuts.Name.forPreset(preset.id)
            KeyboardShortcuts.onKeyUp(for: name) { [weak self] in
                self?.onReformulate(preset.id)
            }
        }
    }
}
