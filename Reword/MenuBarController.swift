import AppKit

/// Builds and maintains the `NSStatusItem` menu: one entry per preset, a "Rephrase Now" action,
/// plus settings/accessibility/quit. Selecting a preset only changes which one is active (moves
/// the checkmark) — it does NOT itself trigger a reformulation, so browsing the menu never
/// accidentally rewrites whatever's currently selected in another app.
@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let settings: AppSettings
    private let onSetActivePreset: (UUID) -> Void
    private let onReformulate: (UUID?) -> Void
    private let onCancel: () -> Void
    private let onOpenSettings: () -> Void
    private let onRequestAccessibility: () -> Void

    private static let idleSymbol = "wand.and.stars"
    private static let busySymbol = "hourglass"

    private var isBusy = false

    init(
        settings: AppSettings,
        onSetActivePreset: @escaping (UUID) -> Void,
        onReformulate: @escaping (UUID?) -> Void,
        onCancel: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onRequestAccessibility: @escaping () -> Void
    ) {
        self.settings = settings
        self.onSetActivePreset = onSetActivePreset
        self.onReformulate = onReformulate
        self.onCancel = onCancel
        self.onOpenSettings = onOpenSettings
        self.onRequestAccessibility = onRequestAccessibility
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: Self.idleSymbol, accessibilityDescription: String(localized: "Reword — idle"))
        rebuildMenu()
    }

    func setBusy(_ busy: Bool) {
        isBusy = busy
        let symbol = busy ? Self.busySymbol : Self.idleSymbol
        let description = busy ? String(localized: "Reword — working") : String(localized: "Reword — idle")
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        if settings.presets.isEmpty {
            let empty = NSMenuItem(title: String(localized: "No presets — open settings"), action: #selector(openSettings), keyEquivalent: "")
            empty.target = self
            menu.addItem(empty)
        } else {
            for preset in settings.presets {
                let item = NSMenuItem(title: preset.name, action: #selector(presetSelected(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = preset.id
                item.state = preset.id == settings.activePresetID ? .on : .off
                menu.addItem(item)
            }

            menu.addItem(.separator())

            let runItem = NSMenuItem(title: String(localized: "Rephrase Now"), action: #selector(runNow), keyEquivalent: "")
            runItem.target = self
            runItem.isEnabled = !isBusy
            menu.addItem(runItem)
        }

        if isBusy {
            let cancelItem = NSMenuItem(title: String(localized: "Cancel"), action: #selector(cancel), keyEquivalent: "")
            cancelItem.target = self
            menu.addItem(cancelItem)
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: String(localized: "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        if !AccessibilityPermission.isTrusted {
            let accessibilityItem = NSMenuItem(
                title: String(localized: "Allow Accessibility…"),
                action: #selector(requestAccessibility),
                keyEquivalent: ""
            )
            accessibilityItem.target = self
            menu.addItem(accessibilityItem)
        }

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: String(localized: "Quit Reword"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func presetSelected(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        onSetActivePreset(id)
        rebuildMenu()
    }

    @objc private func runNow() {
        onReformulate(nil)
    }

    @objc private func cancel() {
        onCancel()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func requestAccessibility() {
        onRequestAccessibility()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
