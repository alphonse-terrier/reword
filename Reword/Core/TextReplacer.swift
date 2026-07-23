import AppKit

/// Captures and replaces the user's current text selection. Prefers direct Accessibility (AX)
/// access — reading/writing `kAXSelectedTextAttribute` on the focused element — which doesn't
/// touch the pasteboard and survives focus changes during the (multi-second) LLM call. Falls
/// back to synthesized ⌘C/⌘V for apps that don't expose AX text editing (some Electron apps).
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
    /// captured from, regardless of which strategy succeeded.
    struct Session {
        fileprivate enum Strategy {
            case ax(element: AXUIElement)
            case pasteboard(savedItems: [PasteboardTextStrategy.SavedItem], frontmostApp: pid_t?)
        }
        fileprivate let strategy: Strategy
    }

    /// Captures the current selection. Tries Accessibility first; if the focused element
    /// doesn't support it, falls back to the pasteboard strategy.
    static func captureSelectedText() async throws -> (text: String, session: Session) {
        guard AccessibilityPermission.isTrusted else { throw ReplacerError.accessibilityNotTrusted }

        do {
            let (text, element) = try AXTextStrategy.capture()
            Log.textReplace.debug("Captured selection via Accessibility.")
            return (text, Session(strategy: .ax(element: element)))
        } catch is AXTextStrategy.AXStrategyError {
            Log.textReplace.notice("Focused element doesn't support direct AX text access; falling back to pasteboard.")
        } catch let error as ReplacerError {
            throw error
        } catch {
            Log.textReplace.notice("AX capture failed unexpectedly (\(error.localizedDescription, privacy: .public)); falling back to pasteboard.")
        }

        let (text, saved) = try await PasteboardTextStrategy.capture()
        let frontmostApp = NSWorkspace.shared.frontmostApplication?.processIdentifier
        return (text, Session(strategy: .pasteboard(savedItems: saved, frontmostApp: frontmostApp)))
    }

    /// Writes `replacement` back using whichever strategy succeeded at capture time.
    static func replaceSelection(_ session: Session, with replacement: String, restoreOriginal: Bool) async throws {
        switch session.strategy {
        case .ax(let element):
            try AXTextStrategy.replace(element: element, with: replacement)
            Log.textReplace.debug("Replaced selection via Accessibility.")
        case .pasteboard(let savedItems, let frontmostApp):
            try await PasteboardTextStrategy.replace(
                with: replacement,
                savedItems: savedItems,
                restoreOriginal: restoreOriginal,
                expectedFrontmostApp: frontmostApp
            )
            Log.textReplace.debug("Replaced selection via pasteboard.")
        }
    }
}
