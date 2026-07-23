import SwiftUI

@main
struct RewordApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No windows of our own at launch — everything lives behind the menu bar item and the
        // settings window, which AppDelegate opens on demand via SettingsWindowController.
        Settings {
            EmptyView()
        }
    }
}
