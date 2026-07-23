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
            name: "Corriger l'orthographe",
            systemPrompt: "Corrige uniquement les fautes d'orthographe, de grammaire et de ponctuation du texte suivant. Ne change pas le style, ne reformule pas, ne raccourcis pas. Réponds uniquement avec le texte corrigé, sans commentaire ni guillemets."
        ),
        Preset(
            name: "Reformuler professionnellement",
            systemPrompt: "Reformule le texte suivant dans un registre professionnel et clair, en conservant le sens original. Réponds uniquement avec le texte reformulé, sans commentaire ni guillemets."
        ),
        Preset(
            name: "Raccourcir",
            systemPrompt: "Raccourcis le texte suivant en conservant les informations essentielles et le sens original. Réponds uniquement avec le texte raccourci, sans commentaire ni guillemets."
        ),
        Preset(
            name: "Traduire en anglais",
            systemPrompt: "Traduis le texte suivant en anglais, dans un style naturel et fidèle. Réponds uniquement avec la traduction, sans commentaire ni guillemets."
        ),
    ]
}

extension KeyboardShortcuts.Name {
    /// Default global shortcut: reformulate using the currently selected preset.
    static let reformulateDefault = Self("reformulateDefault")

    /// Builds a per-preset shortcut name so each preset can have its own binding.
    static func forPreset(_ id: UUID) -> Self {
        Self("reformulatePreset_\(id.uuidString)")
    }
}
