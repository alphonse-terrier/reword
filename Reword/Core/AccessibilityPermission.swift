import ApplicationServices
import AppKit

/// Wraps the macOS Accessibility permission check/prompt. Reword needs this permission to post
/// synthetic Cmd+C / Cmd+V events to the frontmost application.
enum AccessibilityPermission {
    /// Returns whether the app is currently trusted, without prompting the user.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the system Accessibility dialog if the app isn't trusted yet.
    @discardableResult
    static func requestIfNeeded() -> Bool {
        let options: [String: Bool] = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Opens the Accessibility pane in System Settings so the user can grant the permission manually.
    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
