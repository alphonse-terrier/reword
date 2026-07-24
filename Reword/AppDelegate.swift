import AppKit
import UserNotifications

/// Owns the app's lifecycle: menu bar item, hotkey wiring, and the reformulation pipeline
/// (capture selection → call LLM → replace selection). Confined to the main actor: settings are
/// read into a `Sendable` `ReformulationRequest` snapshot before any background work starts, and
/// only one reformulation runs at a time.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    private var menuBarController: MenuBarController!
    private var hotkeyManager: HotkeyManager!
    private var settingsWindowController: SettingsWindowController?
    private let overlay = StatusOverlayController()

    /// The in-flight reformulation, if any — guards against a second trigger interleaving
    /// pasteboard/AX writes with the first, and gives "Cancel" something to cancel.
    private var currentTask: Task<Void, Never>?
    private var notificationsAuthorized = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsStore.load(into: settings)

        hotkeyManager = HotkeyManager { [weak self] presetID in
            self?.runReformulation(presetID: presetID)
        }
        hotkeyManager.registerShortcuts(for: settings.presets)

        menuBarController = MenuBarController(
            settings: settings,
            onSetActivePreset: { [weak self] id in self?.settings.activePresetID = id },
            onReformulate: { [weak self] presetID in self?.runReformulation(presetID: presetID) },
            onCancel: { [weak self] in self?.cancelCurrentReformulation() },
            onOpenSettings: { [weak self] in self?.showSettings() },
            onRequestAccessibility: {
                if AccessibilityPermission.isTrusted {
                    AccessibilityPermission.openSystemSettings()
                } else {
                    AccessibilityPermission.requestIfNeeded()
                }
            }
        )

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { [weak self] granted, error in
            if let error {
                Log.pipeline.error("Notification authorization error: \(error.localizedDescription, privacy: .public)")
            }
            Task { @MainActor in self?.notificationsAuthorized = granted }
        }

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
            report(title: "Reword", body: String(localized: "No preset configured. Open settings."))
            return
        }

        guard currentTask == nil else {
            Log.pipeline.notice("Ignoring reformulation trigger — one is already in flight.")
            return
        }

        let languageInstruction = settings.languageInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        let systemPrompt = languageInstruction.isEmpty
            ? preset.systemPrompt
            : languageInstruction + "\n\n" + preset.systemPrompt

        let request = ReformulationRequest(
            providerType: settings.providerType,
            baseURL: settings.baseURL,
            model: settings.model,
            apiKey: SettingsStore.loadAPIKey(for: settings.providerType),
            commandExecutable: settings.commandExecutable,
            commandArgumentsLine: settings.commandArgumentsLine,
            systemPrompt: systemPrompt,
            restorePasteboard: settings.restorePasteboard
        )

        menuBarController.setBusy(true)
        overlay.show(.working)

        currentTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.menuBarController.setBusy(false)
                self.currentTask = nil
            }
            do {
                let (selected, session) = try await TextReplacer.captureSelectedText()
                let provider = request.makeProvider()
                let result = try await withTimeout(seconds: 45) {
                    try await provider.reformulate(text: selected, systemPrompt: request.systemPrompt)
                }
                if session.isReadOnly {
                    Log.pipeline.debug("Selection is read-only — showing result popup instead of writing back.")
                    self.overlay.show(.result(result))
                } else {
                    try await TextReplacer.replaceSelection(session, with: result, restoreOriginal: request.restorePasteboard)
                    self.overlay.show(.success)
                }
            } catch is CancellationError {
                Log.pipeline.notice("Reformulation cancelled.")
                self.overlay.hide()
            } catch {
                Log.pipeline.error("Reformulation failed: \(error.localizedDescription, privacy: .public)")
                self.overlay.show(.failure(error.localizedDescription))
                self.report(title: String(localized: "Rephrasing failed"), body: error.localizedDescription)
            }
        }
    }

    /// Cancels the in-flight reformulation, if any — wired to the menu's "Cancel" item.
    private func cancelCurrentReformulation() {
        currentTask?.cancel()
    }

    /// Surfaces an error/status message. The floating overlay is the primary channel; this adds
    /// a system notification only when the user has actually granted permission for it, so a
    /// denied/ignored authorization request doesn't silently swallow every error.
    private func report(title: String, body: String) {
        guard notificationsAuthorized else {
            Log.pipeline.notice("\(title, privacy: .public): \(body, privacy: .public) (notifications not authorized, overlay-only)")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Log.pipeline.error("Failed to post notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
