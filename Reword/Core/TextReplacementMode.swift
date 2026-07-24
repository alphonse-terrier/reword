import Foundation

/// Per-preset override for how Reword decides whether a selection can be written back to.
/// Accessibility-based auto-detection works well in most apps, but some are unreliable enough
/// (or a user simply wants consistent behavior for a given preset) that an explicit override is
/// worth having.
enum TextReplacementMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Detect automatically via Accessibility (the default).
    case automatic
    /// Always attempt to write the result back, even if detection suggests read-only.
    case alwaysEditable
    /// Always show the result in the read-only popup, even if detection suggests editable.
    case alwaysReadOnly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: return String(localized: "Auto-detect")
        case .alwaysEditable: return String(localized: "Always editable")
        case .alwaysReadOnly: return String(localized: "Always read-only")
        }
    }
}
