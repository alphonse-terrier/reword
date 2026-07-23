import XCTest
@testable import Reword

@MainActor
final class SettingsStoreTests: XCTestCase {
    private let suiteName = "com.polyconseil.alphonse.Reword.tests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testSaveThenLoadRoundTrips() {
        let settings = AppSettings()
        settings.providerType = .anthropic
        settings.model = "claude-sonnet-5"
        settings.commandExecutable = "claude"

        SettingsStore.save(settings, defaults: defaults)

        let loaded = AppSettings()
        SettingsStore.load(into: loaded, defaults: defaults)

        XCTAssertEqual(loaded.providerType, .anthropic)
        XCTAssertEqual(loaded.model, "claude-sonnet-5")
        XCTAssertEqual(loaded.commandExecutable, "claude")
    }

    /// Simulates a settings blob saved by an older version of the app, before
    /// `languageInstruction`/`commandExecutable`/`commandArgumentsLine` existed — the newer
    /// optional fields should fall back to sane defaults instead of failing to decode.
    func testLoadWithMissingNewerFieldsFallsBackToDefaults() {
        let legacyJSON = """
        {
            "providerType": "openAICompatible",
            "baseURL": "https://api.openai.com/v1",
            "model": "gpt-4o-mini",
            "presets": [],
            "restorePasteboard": true
        }
        """
        defaults.set(Data(legacyJSON.utf8), forKey: "com.polyconseil.alphonse.Reword.settings")

        let loaded = AppSettings()
        SettingsStore.load(into: loaded, defaults: defaults)

        XCTAssertEqual(loaded.providerType, .openAICompatible)
        XCTAssertEqual(loaded.languageInstruction, AppSettings.defaultLanguageInstruction)
        XCTAssertEqual(loaded.commandExecutable, "")
        XCTAssertFalse(loaded.presets.isEmpty) // an empty saved array falls back to Preset.defaults
    }

    func testLoadWithCorruptDataKeepsInMemoryDefaults() {
        defaults.set(Data("not json".utf8), forKey: "com.polyconseil.alphonse.Reword.settings")

        let loaded = AppSettings()
        let originalProviderType = loaded.providerType
        SettingsStore.load(into: loaded, defaults: defaults)

        XCTAssertEqual(loaded.providerType, originalProviderType)
    }
}
