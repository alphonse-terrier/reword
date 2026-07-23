import AppKit
import Carbon.HIToolbox

/// Reads the current text selection and replaces it, by driving the pasteboard and synthesizing
/// Cmd+C / Cmd+V key events to the frontmost application. This works everywhere (native apps,
/// Electron, browsers) because it goes through the same path a human keystroke would.
enum TextReplacer {
    enum ReplacerError: LocalizedError {
        case noSelection
        case accessibilityNotTrusted

        var errorDescription: String? {
            switch self {
            case .noSelection:
                return "Aucun texte sélectionné."
            case .accessibilityNotTrusted:
                return "Reword n'a pas la permission Accessibilité. Autorise-la dans Réglages Système."
            }
        }
    }

    /// Captures the current selection, then restores the pasteboard as it was.
    static func captureSelectedText() async throws -> String {
        guard AccessibilityPermission.isTrusted else { throw ReplacerError.accessibilityNotTrusted }

        let pasteboard = NSPasteboard.general
        let savedChangeCount = pasteboard.changeCount
        let savedItems = snapshotItems(of: pasteboard)

        pasteboard.clearContents()
        postCopy()
        try await Task.sleep(nanoseconds: 150_000_000)

        let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)

        // Restore whatever was on the pasteboard before we touched it.
        restore(savedItems, to: pasteboard)
        _ = savedChangeCount

        guard let text, !text.isEmpty else { throw ReplacerError.noSelection }
        return text
    }

    /// Puts `replacement` on the pasteboard, pastes it over the (still active) selection, then
    /// restores the original pasteboard contents after a short delay so the user's clipboard
    /// history isn't polluted.
    static func replaceSelection(with replacement: String, restoreOriginal: Bool) async throws {
        guard AccessibilityPermission.isTrusted else { throw ReplacerError.accessibilityNotTrusted }

        let pasteboard = NSPasteboard.general
        let savedItems = restoreOriginal ? snapshotItems(of: pasteboard) : nil

        pasteboard.clearContents()
        pasteboard.setString(replacement, forType: .string)

        // Give the pasteboard a beat to settle before the paste keystroke reads it.
        try await Task.sleep(nanoseconds: 50_000_000)
        postPaste()
        try await Task.sleep(nanoseconds: 150_000_000)

        if let savedItems {
            restore(savedItems, to: pasteboard)
        }
    }

    // MARK: - Pasteboard snapshot/restore

    private struct SavedItem {
        var data: [NSPasteboard.PasteboardType: Data]
    }

    private static func snapshotItems(of pasteboard: NSPasteboard) -> [SavedItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            var data: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let value = item.data(forType: type) {
                    data[type] = value
                }
            }
            return SavedItem(data: data)
        }
    }

    private static func restore(_ items: [SavedItem], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let newItems = items.map { saved -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in saved.data {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(newItems)
    }

    // MARK: - Synthetic key events

    private static func postCopy() {
        postKeystroke(keyCode: CGKeyCode(kVK_ANSI_C))
    }

    private static func postPaste() {
        postKeystroke(keyCode: CGKeyCode(kVK_ANSI_V))
    }

    private static func postKeystroke(keyCode: CGKeyCode) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
