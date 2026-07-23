import AppKit

/// Builds and maintains the `NSStatusItem` menu: one entry per preset, plus settings/accessibility/quit.
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let settings: AppSettings
    private let onReformulate: (UUID?) -> Void
    private let onOpenSettings: () -> Void
    private let onRequestAccessibility: () -> Void

    private static let idleSymbol = "wand.and.stars"
    private static let busySymbol = "hourglass"

    init(
        settings: AppSettings,
        onReformulate: @escaping (UUID?) -> Void,
        onOpenSettings: @escaping () -> Void,
        onRequestAccessibility: @escaping () -> Void
    ) {
        self.settings = settings
        self.onReformulate = onReformulate
        self.onOpenSettings = onOpenSettings
        self.onRequestAccessibility = onRequestAccessibility
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: Self.idleSymbol, accessibilityDescription: "Reword")
        rebuildMenu()
    }

    func setBusy(_ busy: Bool) {
        let symbol = busy ? Self.busySymbol : Self.idleSymbol
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Reword")
    }

    func rebuildMenu() {
        let menu = NSMenu()

        if settings.presets.isEmpty {
            let empty = NSMenuItem(title: String(localized: "No presets — open settings"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for preset in settings.presets {
                let item = NSMenuItem(title: preset.name, action: #selector(presetSelected(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = preset.id
                item.state = preset.id == settings.activePresetID ? .on : .off
                menu.addItem(item)
            }
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
        settings.activePresetID = id
        onReformulate(id)
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
