import AppKit
import Carbon.HIToolbox

/// Fallback text-access strategy for apps that don't expose Accessibility text editing (some
/// Electron apps). Drives the pasteboard via synthesized ⌘C/⌘V, hardened against the two ways
/// this used to fail silently: fixed sleeps racing the target app, and pasting into whatever
/// app happens to be frontmost after a focus change.
enum PasteboardTextStrategy {
    struct SavedItem {
        var data: [NSPasteboard.PasteboardType: Data]
    }

    /// Captures the current selection by synthesizing ⌘C and polling the pasteboard's
    /// `changeCount` (rather than a fixed sleep) so we know the copy actually landed before
    /// reading it back.
    static func capture() async throws -> (text: String, savedItems: [SavedItem]) {
        let pasteboard = NSPasteboard.general
        let savedItems = snapshotItems(of: pasteboard)
        let changeCountBeforeCopy = pasteboard.changeCount

        do {
            try postKeystroke(keyCode: CGKeyCode(kVK_ANSI_C))
        } catch {
            restore(savedItems, to: pasteboard)
            throw error
        }

        let changed = await waitForChangeCount(above: changeCountBeforeCopy, on: pasteboard, timeout: 1.0)
        guard changed else {
            restore(savedItems, to: pasteboard)
            throw TextReplacer.ReplacerError.noSelection
        }

        let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
        restore(savedItems, to: pasteboard)

        guard let text, !text.isEmpty else { throw TextReplacer.ReplacerError.noSelection }
        return (text, savedItems)
    }

    /// Puts `replacement` on the pasteboard and pastes it via synthetic ⌘V. If
    /// `expectedFrontmostApp` no longer matches the actual frontmost app, the user switched away
    /// during the LLM call — this throws instead of pasting into the wrong place.
    static func replace(
        with replacement: String,
        savedItems: [SavedItem],
        restoreOriginal: Bool,
        expectedFrontmostApp: pid_t?
    ) async throws {
        if let expectedFrontmostApp, NSWorkspace.shared.frontmostApplication?.processIdentifier != expectedFrontmostApp {
            throw TextReplacer.ReplacerError.focusChanged
        }

        let pasteboard = NSPasteboard.general
        let itemsToRestore = restoreOriginal ? snapshotItems(of: pasteboard) : nil

        pasteboard.clearContents()
        pasteboard.setString(replacement, forType: .string)

        // Give the pasteboard a moment to settle before the paste keystroke reads it — this one
        // stays a short fixed delay since there's no "write completed" signal to poll for.
        try await Task.sleep(nanoseconds: 30_000_000)
        try postKeystroke(keyCode: CGKeyCode(kVK_ANSI_V))
        try await Task.sleep(nanoseconds: 150_000_000)

        if let itemsToRestore {
            restore(itemsToRestore, to: pasteboard)
        }
    }

    // MARK: - Helpers

    private static func waitForChangeCount(above baseline: Int, on pasteboard: NSPasteboard, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if pasteboard.changeCount != baseline { return true }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return pasteboard.changeCount != baseline
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

    private static func postKeystroke(keyCode: CGKeyCode) throws {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw TextReplacer.ReplacerError.synthesizedInputFailed
        }
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            throw TextReplacer.ReplacerError.synthesizedInputFailed
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
