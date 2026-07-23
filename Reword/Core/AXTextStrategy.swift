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

    /// Captures the current selection. Throws `AXStrategyError.unsupported` (not a hard error —
    /// callers should fall back to the pasteboard strategy) if the focused element doesn't
    /// expose a settable `kAXSelectedTextAttribute`.
    static func capture() throws -> (text: String, element: AXUIElement) {
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

        // Confirm the attribute is actually settable before committing to this strategy — some
        // elements report selected text but reject writes (e.g. read-only web content).
        var settable: DarwinBoolean = false
        let settableResult = AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable)
        guard settableResult == .success, settable.boolValue else {
            throw AXStrategyError.unsupported
        }

        return (trimmed, element)
    }

    /// Writes `replacement` back into the element captured by `capture()`.
    static func replace(element: AXUIElement, with replacement: String) throws {
        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, replacement as CFTypeRef)
        guard result == .success else {
            throw AXStrategyError.unsupported
        }
    }
}
