import Foundation
import Security

/// Persists non-sensitive settings to `UserDefaults` (as JSON) and API keys to the macOS Keychain.
/// Never writes secrets to disk in plain text.
enum SettingsStore {
    private static let defaultsKey = "com.polyconseil.alphonse.Reword.settings"
    private static let keychainService = "com.polyconseil.alphonse.Reword"
    /// Pre-2.0 versions stored a single API key shared by every provider; kept around only so
    /// `loadAPIKey(for:)` can migrate it into the new per-provider slot on first read.
    private static let legacyKeychainAccount = "llm-api-key"
    private static let currentSchemaVersion = 2

    // MARK: - Non-sensitive settings (UserDefaults)

    private struct Snapshot: Codable {
        var schemaVersion: Int?
        var providerType: ProviderType
        var baseURL: String
        var model: String
        var presets: [Preset]
        var activePresetID: UUID?
        var restorePasteboard: Bool
        var languageInstruction: String?
        var commandExecutable: String?
        var commandArgumentsLine: String?
    }

    @MainActor
    static func load(into settings: AppSettings, defaults: UserDefaults = .standard) {
        guard let data = defaults.data(forKey: defaultsKey) else { return }

        guard let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            Log.settings.error("Failed to decode saved settings (schema mismatch?) — keeping in-memory defaults instead of overwriting the save.")
            return
        }

        settings.providerType = snapshot.providerType
        settings.baseURL = snapshot.baseURL
        settings.model = snapshot.model
        settings.presets = snapshot.presets.isEmpty ? Preset.defaults : snapshot.presets
        settings.activePresetID = snapshot.activePresetID ?? settings.presets.first?.id
        settings.restorePasteboard = snapshot.restorePasteboard
        settings.languageInstruction = snapshot.languageInstruction ?? AppSettings.defaultLanguageInstruction
        settings.commandExecutable = snapshot.commandExecutable ?? ""
        settings.commandArgumentsLine = snapshot.commandArgumentsLine ?? ""
    }

    @MainActor
    static func save(_ settings: AppSettings, defaults: UserDefaults = .standard) {
        let snapshot = Snapshot(
            schemaVersion: currentSchemaVersion,
            providerType: settings.providerType,
            baseURL: settings.baseURL,
            model: settings.model,
            presets: settings.presets,
            activePresetID: settings.activePresetID,
            restorePasteboard: settings.restorePasteboard,
            languageInstruction: settings.languageInstruction,
            commandExecutable: settings.commandExecutable,
            commandArgumentsLine: settings.commandArgumentsLine
        )
        guard let data = try? JSONEncoder().encode(snapshot) else {
            Log.settings.error("Failed to encode settings for saving — changes were NOT persisted.")
            return
        }
        defaults.set(data, forKey: defaultsKey)
    }

    // MARK: - API key (Keychain, one slot per provider)

    /// Loads the API key for `provider`. If none is set yet but a pre-2.0 shared key exists,
    /// migrates it into this provider's slot (one-time) so upgrading doesn't silently drop a
    /// working configuration.
    static func loadAPIKey(for provider: ProviderType) -> String {
        let account = keychainAccount(for: provider)
        if let key = keychainRead(account: account) {
            return key
        }
        if let legacy = keychainRead(account: legacyKeychainAccount), !legacy.isEmpty {
            keychainWrite(legacy, account: account)
            return legacy
        }
        return ""
    }

    static func saveAPIKey(_ key: String, for provider: ProviderType) {
        keychainWrite(key, account: keychainAccount(for: provider))
    }

    private static func keychainAccount(for provider: ProviderType) -> String {
        "llm-api-key-\(provider.rawValue)"
    }

    private static func keychainRead(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        return key
    }

    private static func keychainWrite(_ key: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
        ]

        if key.isEmpty {
            SecItemDelete(query as CFDictionary)
            return
        }

        let attributes: [String: Any] = [
            kSecValueData as String: Data(key.utf8)
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        } else {
            var addQuery = query
            addQuery[kSecValueData as String] = Data(key.utf8)
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }
}
