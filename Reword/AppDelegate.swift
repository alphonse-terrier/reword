import AppKit
import UserNotifications

/// Owns the app's lifecycle: menu bar item, hotkey wiring, and the reformulation pipeline
/// (capture selection → call LLM → replace selection).
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    private var menuBarController: MenuBarController!
    private var hotkeyManager: HotkeyManager!
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsStore.load(into: settings)

        hotkeyManager = HotkeyManager { [weak self] presetID in
            self?.runReformulation(presetID: presetID)
        }
        hotkeyManager.registerShortcuts(for: settings.presets)

        menuBarController = MenuBarController(
            settings: settings,
            onReformulate: { [weak self] presetID in self?.runReformulation(presetID: presetID) },
            onOpenSettings: { [weak self] in self?.showSettings() },
            onRequestAccessibility: {
                if AccessibilityPermission.isTrusted {
                    AccessibilityPermission.openSystemSettings()
                } else {
                    AccessibilityPermission.requestIfNeeded()
                }
            }
        )

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }

        if !AccessibilityPermission.isTrusted {
            AccessibilityPermission.requestIfNeeded()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        SettingsStore.save(settings)
    }

    private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(settings: settings) { [weak self] in
                guard let self else { return }
                SettingsStore.save(self.settings)
                self.hotkeyManager.registerShortcuts(for: self.settings.presets)
                self.menuBarController.rebuildMenu()
            }
        }
        settingsWindowController?.show()
    }

    private func runReformulation(presetID: UUID?) {
        guard let preset = (presetID.flatMap { id in settings.presets.first { $0.id == id } }) ?? settings.activePreset else {
            notify(title: "Reword", body: String(localized: "No preset configured. Open settings."))
            return
        }

        menuBarController.setBusy(true)

        Task {
            defer { menuBarController.setBusy(false) }
            do {
                let selected = try await TextReplacer.captureSelectedText()
                let apiKey = SettingsStore.loadAPIKey()
                let provider = settings.makeProvider(apiKey: apiKey)
                let languageInstruction = settings.languageInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
                let systemPrompt = languageInstruction.isEmpty
                    ? preset.systemPrompt
                    : languageInstruction + "\n\n" + preset.systemPrompt
                let result = try await provider.reformulate(text: selected, systemPrompt: systemPrompt)
                try await TextReplacer.replaceSelection(with: result, restoreOriginal: settings.restorePasteboard)
            } catch {
                notify(title: String(localized: "Rephrasing failed"), body: error.localizedDescription)
            }
        }
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
