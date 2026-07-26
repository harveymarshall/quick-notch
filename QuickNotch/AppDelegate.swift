import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchPanelController?
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = NotchPanelController(appState: AppState.shared)
        notchController = controller
        AppState.shared.notchController = controller

        hotKey = GlobalHotKey(keyCode: 0x2D, modifiers: [.command, .shift]) { // Cmd+Shift+N
            AppState.shared.toggleCapture()
        }
        hotKey?.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKey?.unregister()
    }
}
