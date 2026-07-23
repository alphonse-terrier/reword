import Foundation
import Security

/// Persists non-sensitive settings to `UserDefaults` (as JSON) and API keys to the macOS Keychain.
/// Never writes secrets to disk in plain text.
enum SettingsStore {
    private static let defaultsKey = "com.polyconseil.alphonse.Reword.settings"
    private static let keychainService = "com.polyconseil.alphonse.Reword"
    private static let keychainAccount = "llm-api-key"

    // MARK: - Non-sensitive settings (UserDefaults)

    private struct Snapshot: Codable {
        var providerType: ProviderType
        var baseURL: String
        var model: String
        var presets: [Preset]
        var activePresetID: UUID?
        var restorePasteboard: Bool
    }

    static func load(into settings: AppSettings) {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return }

        settings.providerType = snapshot.providerType
        settings.baseURL = snapshot.baseURL
        settings.model = snapshot.model
        settings.presets = snapshot.presets.isEmpty ? Preset.defaults : snapshot.presets
        settings.activePresetID = snapshot.activePresetID ?? settings.presets.first?.id
        settings.restorePasteboard = snapshot.restorePasteboard
    }

    static func save(_ settings: AppSettings) {
        let snapshot = Snapshot(
            providerType: settings.providerType,
            baseURL: settings.baseURL,
            model: settings.model,
            presets: settings.presets,
            activePresetID: settings.activePresetID,
            restorePasteboard: settings.restorePasteboard
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    // MARK: - API key (Keychain)

    static func loadAPIKey() -> String {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            return ""
        }
        _ = query // silence unused-mutation warning on some toolchains
        return key
    }

    static func saveAPIKey(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
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
