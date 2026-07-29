import AppKit
import SwiftUI

/// Presents Settings in a real `NSWindow`.
/// SwiftUI's `Settings` scene / `showSettingsWindow:` silently fail for
/// `LSUIElement` / `.accessory` menu-bar apps when opened from `MenuBarExtra`.
///
/// Intentionally keeps `.accessory` activation policy — flipping to `.regular`
/// makes AppKit shove the notch panel below the menu bar.
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
        NSApp.activate(ignoringOtherApps: true)

        if let window {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            repinNotch()
            return
        }

        let rootView = SettingsView()
            .environmentObject(AppState.shared)
        let hosting = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Quick Notch Settings"
        window.styleMask = [.titled, .closable]
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.setContentSize(NSSize(width: 480, height: 360))
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        self.window = window
        repinNotch()
    }

    nonisolated func windowDidBecomeKey(_ notification: Notification) {
        Task { @MainActor in
            repinNotch()
        }
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            // Next run-loop beat: AppKit may still be adjusting sibling windows.
            DispatchQueue.main.async { [weak self] in
                self?.repinNotch()
            }
        }
    }

    private func repinNotch() {
        AppState.shared.notchController?.repinToScreenTop()
    }
}
