import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class NotchPanelController {
    private let appState: AppState
    private var panel: NSPanel?

    private let collapsedSize = NSSize(width: 172, height: 32)
    private let expandedSize = NSSize(width: 420, height: 220)

    init(appState: AppState) {
        self.appState = appState
        createPanel()
        collapse(animated: false)
    }

    func expand() {
        guard let panel else { return }
        appState.isCaptureVisible = true
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        animateFrame(panel: panel, size: expandedSize)
    }

    func collapse(animated: Bool = true) {
        guard let panel else { return }
        appState.isCaptureVisible = false
        if animated {
            animateFrame(panel: panel, size: collapsedSize)
        } else {
            position(panel: panel, size: collapsedSize)
        }
        panel.orderFrontRegardless()
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: collapsedSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false

        let root = NotchRootView()
            .environmentObject(appState)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: collapsedSize)
        panel.contentView = hosting

        self.panel = panel
    }

    private func screenForNotch() -> NSScreen {
        NSScreen.main ?? NSScreen.screens.first!
    }

    private func position(panel: NSPanel, size: NSSize) {
        let screen = screenForNotch()
        let frame = screen.frame
        let visible = screen.visibleFrame
        // Sit under the camera notch / top center of the menu bar.
        let topY = frame.maxY
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: topY - size.height - 1
        )
        // Keep within visible bounds if needed.
        let clampedY = min(origin.y, visible.maxY - size.height)
        panel.setFrame(NSRect(origin: NSPoint(x: origin.x, y: clampedY), size: size), display: true)
    }

    private func animateFrame(panel: NSPanel, size: NSSize) {
        let screen = screenForNotch()
        let frame = screen.frame
        let visible = screen.visibleFrame
        let topY = frame.maxY
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: min(topY - size.height - 1, visible.maxY - size.height)
        )
        let target = NSRect(origin: origin, size: size)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(target, display: true)
        }
    }
}
