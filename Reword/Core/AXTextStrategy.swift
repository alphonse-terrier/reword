import ApplicationServices
import AppKit

/// Reads/writes the selected text directly on the focused UI element via the Accessibility API
/// (`kAXSelectedTextAttribute`). No pasteboard involved, so the user's clipboard is never
/// touched, and the exact `AXUIElement` is kept so the write-back lands in the right place even
/// if the user switches focus elsewhere while the (multi-second) LLM call is in flight.
enum AXTextStrategy {
    enum AXStrategyError: LocalizedError {
        case unsupported

        var errorDescription: String? {
            String(localized: "The focused element doesn't support direct text access.")
        }
    }

    /// The result of reading the current selection via AX.
    enum CaptureOutcome {
        /// `kAXSelectedTextAttribute` is directly settable — write back via AX, no clipboard.
        case editableAX(text: String, element: AXUIElement)
        /// AX confirms the text is readable, but `kAXSelectedTextAttribute` itself isn't
        /// settable — however a corroborating signal (role, or `kAXValue` settable) says the
        /// element IS editable. Chromium/Gecko (Electron, Firefox) commonly answer "not
        /// settable" for `kAXSelectedTextAttribute` even on genuinely editable content, so this
        /// signal alone can't be trusted — write back via the pasteboard (⌘V) instead.
        case editableViaPasteboard(text: String)
        /// No corroborating editable signal found at all — treat as read-only.
        case readOnly(text: String)
    }

    /// Captures the current selection. Throws `AXStrategyError.unsupported` (not a hard error —
    /// callers should fall back to the pasteboard strategy) only when AX gives no signal at all
    /// (the focused element or its selected text can't be read).
    static func capture() async throws -> CaptureOutcome {
        guard let element = await resolveFocusedElement() else {
            throw AXStrategyError.unsupported
        }

        let elementRole = role(of: element)

        var selectedTextRef: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedTextRef)
        guard textResult == .success, let text = selectedTextRef as? String else {
            Log.textReplace.notice("kAXSelectedTextAttribute unreadable (role: \(elementRole ?? "nil", privacy: .public), AXError: \(textResult.rawValue)) — falling back to pasteboard capture.")
            throw AXStrategyError.unsupported
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TextReplacer.ReplacerError.noSelection
        }

        var settable: DarwinBoolean = false
        let settableResult = AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable)
        if settableResult == .success, settable.boolValue {
            return .editableAX(text: trimmed, element: element)
        }

        // kAXSelectedTextAttribute isn't settable — but this alone isn't a reliable read-only
        // signal (Chromium/Gecko apps often answer "not settable" here regardless of whether the
        // content is actually editable). Corroborate with kAXValue and the element's role before
        // concluding read-only.
        var valueSettable: DarwinBoolean = false
        let valueSettableResult = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &valueSettable)
        let valueIsSettable = valueSettableResult == .success && valueSettable.boolValue
        let isEditable = isEditableSignal(valueSettable: valueIsSettable, role: elementRole)

        Log.textReplace.notice("kAXSelectedTextAttribute not settable (role: \(elementRole ?? "nil", privacy: .public), kAXValue settable: \(valueIsSettable, privacy: .public)) → treating as \(isEditable ? "editable via pasteboard" : "read-only", privacy: .public).")

        if isEditable {
            return .editableViaPasteboard(text: trimmed)
        }
        return .readOnly(text: trimmed)
    }

    /// Writes `replacement` back into the element captured by `capture()`.
    static func replace(element: AXUIElement, with replacement: String) throws {
        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, replacement as CFTypeRef)
        guard result == .success else {
            throw AXStrategyError.unsupported
        }
    }

    // MARK: - Focused element lookup

    /// Resolves the currently focused AX element, retrying once after nudging the frontmost
    /// app's accessibility tree awake if the first attempt bottoms out at the window level.
    /// Chromium (Electron apps like Slack) and Firefox only build out their full accessibility
    /// tree — down to the actual focused text control — once something signals that assistive
    /// tech is present; before that, focused-element queries can report just the window itself
    /// (role `AXWindow`) instead of the control inside it.
    private static func resolveFocusedElement() async -> AXUIElement? {
        if let element = focusedElement(), role(of: element) != "AXWindow" {
            return element
        }

        guard let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            return focusedElement()
        }

        activateAccessibilityTree(pid: frontmostPID)
        try? await Task.sleep(nanoseconds: 150_000_000)

        return focusedElement()
    }

    /// Signals Chromium-based apps (Electron, Chrome) to fully build out their accessibility
    /// tree. Harmless no-op on apps that don't recognize the attribute (native Cocoa apps
    /// already expose their full tree unconditionally).
    private static func activateAccessibilityTree(pid: pid_t) {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }

    /// Tries the system-wide focused element first (the normal/documented approach); if that
    /// fails, asks the frontmost application's own AX element directly.
    private static func focusedElement() -> AXUIElement? {
        var focusedRef: CFTypeRef?
        let systemWideResult = AXUIElementCopyAttributeValue(
            AXUIElementCreateSystemWide(),
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )
        if systemWideResult == .success, let focusedRef {
            return (focusedRef as! AXUIElement) // swiftlint:disable:this force_cast
        }

        Log.textReplace.notice("System-wide kAXFocusedUIElementAttribute failed (AXError \(systemWideResult.rawValue, privacy: .public)); trying the frontmost app directly.")

        guard let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            Log.textReplace.notice("No frontmost application to query either.")
            return nil
        }

        var appFocusedRef: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(
            AXUIElementCreateApplication(frontmostPID),
            kAXFocusedUIElementAttribute as CFString,
            &appFocusedRef
        )
        guard appResult == .success, let appFocusedRef else {
            Log.textReplace.notice("Frontmost app's kAXFocusedUIElementAttribute also failed (AXError \(appResult.rawValue, privacy: .public)).")
            return nil
        }

        return (appFocusedRef as! AXUIElement) // swiftlint:disable:this force_cast
    }

    // MARK: - Editability heuristics

    /// Roles that represent typed-input controls.
    private static let editableRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]

    /// Pure and testable independently of any real AX call.
    static func isEditableRole(_ role: String?) -> Bool {
        guard let role else { return false }
        return editableRoles.contains(role)
    }

    /// Pure and testable independently of any real AX call. `valueSettable` (whether
    /// `kAXValueAttribute` is settable) is checked first since it's the more reliable signal on
    /// Chromium/Gecko content; role is a secondary corroborating signal.
    static func isEditableSignal(valueSettable: Bool, role: String?) -> Bool {
        valueSettable || isEditableRole(role)
    }

    private static func role(of element: AXUIElement) -> String? {
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success else {
            return nil
        }
        return roleRef as? String
    }

    /// Best-effort guess at whether the currently focused element accepts typed input, used only
    /// when `kAXSelectedTextAttribute` isn't available at all (so `capture()` can't even try).
    /// Defaults to "not editable" when uncertain — callers should prefer showing a read-only
    /// result over risking a paste into the wrong place.
    static func focusedElementLikelyEditable() async -> Bool {
        guard let element = await resolveFocusedElement() else { return false }

        var valueSettable: DarwinBoolean = false
        let valueSettableResult = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &valueSettable)
        let valueIsSettable = valueSettableResult == .success && valueSettable.boolValue
        let elementRole = role(of: element)
        let result = isEditableSignal(valueSettable: valueIsSettable, role: elementRole)

        Log.textReplace.notice("No AX text-selection signal at all — role heuristic (role: \(elementRole ?? "nil", privacy: .public), kAXValue settable: \(valueIsSettable, privacy: .public)) → \(result ? "editable" : "read-only", privacy: .public).")

        return result
    }
}
