import ApplicationServices

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

    /// The result of reading the current selection via AX: either it's writable in place, or AX
    /// explicitly confirms it isn't (e.g. read-only web content, a received chat message).
    enum CaptureOutcome {
        case editable(text: String, element: AXUIElement)
        case readOnly(text: String)
    }

    /// Captures the current selection. Throws `AXStrategyError.unsupported` (not a hard error —
    /// callers should fall back to the pasteboard strategy) only when AX gives no signal at all
    /// (the focused element or its selected text can't be read). When the text CAN be read but
    /// `AXUIElementIsAttributeSettable` says it can't be written, that's a confirmed read-only
    /// selection — returned as `.readOnly`, not thrown, so callers can show the result instead of
    /// attempting a write-back.
    static func capture() throws -> CaptureOutcome {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef)
        guard focusedResult == .success, let focusedRef else {
            throw AXStrategyError.unsupported
        }
        // AX always returns an AXUIElement for this attribute on `.success`.
        let element = focusedRef as! AXUIElement // swiftlint:disable:this force_cast

        var selectedTextRef: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedTextRef)
        guard textResult == .success, let text = selectedTextRef as? String else {
            throw AXStrategyError.unsupported
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TextReplacer.ReplacerError.noSelection
        }

        var settable: DarwinBoolean = false
        let settableResult = AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable)
        guard settableResult == .success, settable.boolValue else {
            // AX read the text just fine but explicitly says it can't be written — a confirmed
            // read-only selection (e.g. a received chat message, static web content), not an
            // unsupported app.
            return .readOnly(text: trimmed)
        }

        return .editable(text: trimmed, element: element)
    }

    /// Writes `replacement` back into the element captured by `capture()`.
    static func replace(element: AXUIElement, with replacement: String) throws {
        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, replacement as CFTypeRef)
        guard result == .success else {
            throw AXStrategyError.unsupported
        }
    }

    // MARK: - Editability heuristic (used only when AX gives no signal at all)

    /// Roles that represent typed-input controls. Used as a fallback heuristic only when
    /// `kAXSelectedTextAttribute` isn't exposed at all (so AX can't answer the editability
    /// question directly) — see `focusedElementLikelyEditable()`.
    private static let editableRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]

    /// Pure and testable independently of any real AX call.
    static func isEditableRole(_ role: String?) -> Bool {
        guard let role else { return false }
        return editableRoles.contains(role)
    }

    /// Best-effort guess at whether the currently focused element accepts typed input, used only
    /// when `kAXSelectedTextAttribute` isn't available at all. Defaults to "not editable" when
    /// uncertain — callers should prefer showing a read-only result over risking a paste into the
    /// wrong place.
    static func focusedElementLikelyEditable() -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
            let focusedRef
        else { return false }
        let element = focusedRef as! AXUIElement // swiftlint:disable:this force_cast

        var roleRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
            let role = roleRef as? String
        else { return false }

        return isEditableRole(role)
    }
}
