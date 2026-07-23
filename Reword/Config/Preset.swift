import Foundation
import KeyboardShortcuts

/// A single reformulation preset: a display name, the system prompt sent to the LLM,
/// and an optional dedicated global shortcut (in addition to the app's default shortcut).
struct Preset: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var systemPrompt: String

    /// Presets shipped by default on first launch.
    static let defaults: [Preset] = [
        Preset(
            name: "Fix Spelling",
            systemPrompt: "Correct only spelling, grammar, and punctuation mistakes in the following text. Don't change the style, don't rephrase, don't shorten it. Reply only with the corrected text, without comments or quotes."
        ),
        Preset(
            name: "Rephrase Professionally",
            systemPrompt: "Rephrase the following text in a clear, professional register, keeping the original meaning. Reply only with the rephrased text, without comments or quotes."
        ),
        Preset(
            name: "Shorten",
            systemPrompt: "Shorten the following text while keeping the essential information and original meaning. Reply only with the shortened text, without comments or quotes."
        ),
        Preset(
            name: "Translate to English",
            systemPrompt: "Translate the following text into English, in a natural and faithful style. Reply only with the translation, without comments or quotes."
        ),
    ]
}

extension KeyboardShortcuts.Name {
    /// Default global shortcut: reformulate using the currently selected preset.
    static let reformulateDefault = Self("reformulateDefault", default: .init(.leftArrow, modifiers: [.command, .option]))

    /// Builds a per-preset shortcut name so each preset can have its own binding.
    static func forPreset(_ id: UUID) -> Self {
        Self("reformulatePreset_\(id.uuidString)")
    }
}
