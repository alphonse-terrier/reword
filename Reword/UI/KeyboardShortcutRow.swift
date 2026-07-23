import SwiftUI
import KeyboardShortcuts

/// Thin label + recorder row, built on `KeyboardShortcuts.Recorder` which already persists
/// the binding itself — no plumbing back into `AppSettings` needed.
struct KeyboardShortcutRow: View {
    let name: KeyboardShortcuts.Name
    let label: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            KeyboardShortcuts.Recorder(for: name)
        }
    }
}
