import AppKit

/// Captures and replaces the user's current text selection. Prefers direct Accessibility (AX)
/// access — reading/writing `kAXSelectedTextAttribute` on the focused element — which doesn't
/// touch the pasteboard and survives focus changes during the (multi-second) LLM call. Falls
/// back to synthesized ⌘C/⌘V for apps that don't expose AX text editing (some Electron apps).
/// When the selection is read-only (a received chat message, static web content), no write-back
/// is attempted at all — callers should show the result instead (see `Session.isReadOnly`).
enum TextReplacer {
    enum ReplacerError: LocalizedError {
        case noSelection
        case accessibilityNotTrusted
        case focusChanged
        case synthesizedInputFailed

        var errorDescription: String? {
            switch self {
            case .noSelection:
                return String(localized: "No text selected.")
            case .accessibilityNotTrusted:
                return String(localized: "Reword doesn't have Accessibility permission. Grant it in System Settings.")
            case .focusChanged:
                return String(localized: "The focused app changed before the result was ready, so pasting was cancelled.")
            case .synthesizedInputFailed:
                return String(localized: "Couldn't synthesize the keyboard shortcut needed to copy/paste.")
            }
        }
    }

    /// Carries whatever state is needed to write the result back to the same place it was
    /// captured from, regardless of which strategy succeeded — or signals that no write-back
    /// should be attempted at all.
    struct Session {
        fileprivate enum Strategy {
            case editableAX(element: AXUIElement)
            case editablePasteboard(savedItems: [PasteboardTextStrategy.SavedItem], frontmostApp: pid_t?)
            case readOnly
        }
        fileprivate let strategy: Strategy

        /// `true` when the source selection can't be written back to — callers should present
        /// the result to the user instead of calling `replaceSelection`.
        var isReadOnly: Bool {
            if case .readOnly = strategy { return true }
            return false
        }
    }

    /// Captures the current selection. Tries Accessibility first, which can also tell us
    /// definitively that the selection is read-only. If AX gives no signal at all, falls back to
    /// the pasteboard strategy, using a role-based heuristic to guess editability.
    static func captureSelectedText() async throws -> (text: String, session: Session) {
        guard AccessibilityPermission.isTrusted else { throw ReplacerError.accessibilityNotTrusted }

        do {
            switch try AXTextStrategy.capture() {
            case .editable(let text, let element):
                Log.textReplace.debug("Captured selection via Accessibility (editable).")
                return (text, Session(strategy: .editableAX(element: element)))
            case .readOnly(let text):
                Log.textReplace.debug("Captured selection via Accessibility (confirmed read-only).")
                return (text, Session(strategy: .readOnly))
            }
        } catch is AXTextStrategy.AXStrategyError {
            Log.textReplace.notice("No AX text-selection signal at all; falling back to pasteboard.")
        } catch let error as ReplacerError {
            throw error
        } catch {
            Log.textReplace.notice("AX capture failed unexpectedly (\(error.localizedDescription, privacy: .public)); falling back to pasteboard.")
        }

        let (text, saved) = try await PasteboardTextStrategy.capture()
        let frontmostApp = NSWorkspace.shared.frontmostApplication?.processIdentifier

        // No direct AX signal, so guess from the focused element's role. Defaults to read-only
        // when uncertain — a spurious popup is far less bad than pasting into the wrong place.
        if AXTextStrategy.focusedElementLikelyEditable() {
            return (text, Session(strategy: .editablePasteboard(savedItems: saved, frontmostApp: frontmostApp)))
        } else {
            Log.textReplace.debug("Focused element's role doesn't look editable; treating selection as read-only.")
            return (text, Session(strategy: .readOnly))
        }
    }

    /// Writes `replacement` back using whichever strategy succeeded at capture time. A no-op for
    /// read-only sessions — callers shouldn't normally call this in that case (see
    /// `Session.isReadOnly`), but it's safe if they do.
    static func replaceSelection(_ session: Session, with replacement: String, restoreOriginal: Bool) async throws {
        switch session.strategy {
        case .editableAX(let element):
            try AXTextStrategy.replace(element: element, with: replacement)
            Log.textReplace.debug("Replaced selection via Accessibility.")
        case .editablePasteboard(let savedItems, let frontmostApp):
            try await PasteboardTextStrategy.replace(
                with: replacement,
                savedItems: savedItems,
                restoreOriginal: restoreOriginal,
                expectedFrontmostApp: frontmostApp
            )
            Log.textReplace.debug("Replaced selection via pasteboard.")
        case .readOnly:
            Log.textReplace.notice("replaceSelection called on a read-only session — no-op.")
        }
    }
}
