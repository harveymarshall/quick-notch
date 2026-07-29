import AppKit
import SwiftUI

/// Presents Settings in a real `NSWindow`.
/// SwiftUI's `Settings` scene / `showSettingsWindow:` silently fail for
/// `LSUIElement` / `.accessory` menu-bar apps when opened from `MenuBarExtra`.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show() {
        // Let MenuBarExtra finish dismissing before we activate and present.
        DispatchQueue.main.async { [weak self] in
            self?.present()
        }
    }

    private func present() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let rootView = SettingsView()
            .environmentObject(AppState.shared)
        let hosting = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Quick Notch Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 480, height: 360))
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            // Return to menu-bar-only mode once Settings is dismissed.
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
