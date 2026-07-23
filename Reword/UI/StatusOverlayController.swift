import AppKit
import SwiftUI

/// A small, non-activating floating panel that shows reformulation progress/result near the
/// mouse cursor — the primary user-visible feedback channel, since system notifications require
/// a permission the user might not have granted, and this is a window-less menu-bar app
/// otherwise offering zero feedback on success or failure.
@MainActor
final class StatusOverlayController {
    enum State: Equatable {
        case working
        case success
        case failure(String)
    }

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func show(_ state: State) {
        dismissTask?.cancel()
        dismissTask = nil

        let panel = self.panel ?? makePanel()
        self.panel = panel

        let hostingView = NSHostingView(rootView: OverlayView(state: state))
        panel.contentView = hostingView
        let fittingSize = hostingView.fittingSize
        panel.setContentSize(fittingSize)
        positionNearCursor(panel)
        panel.orderFrontRegardless()

        switch state {
        case .working:
            break
        case .success:
            scheduleDismiss(after: 0.9)
        case .failure:
            scheduleDismiss(after: 5.0)
        }
    }

    func hide() {
        dismissTask?.cancel()
        dismissTask = nil
        panel?.orderOut(nil)
    }

    private func scheduleDismiss(after seconds: TimeInterval) {
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.panel?.orderOut(nil)
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hasShadow = false // OverlayView draws its own shadow.
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        return panel
    }

    private func positionNearCursor(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let size = panel.frame.size
        var origin = NSPoint(x: mouseLocation.x + 16, y: mouseLocation.y - size.height - 16)

        // Keep the overlay on-screen if the cursor is near an edge.
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main {
            let frame = screen.visibleFrame
            origin.x = min(max(origin.x, frame.minX), frame.maxX - size.width)
            origin.y = min(max(origin.y, frame.minY), frame.maxY - size.height)
        }

        panel.setFrameOrigin(origin)
    }
}
