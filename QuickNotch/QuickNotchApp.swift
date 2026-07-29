import SwiftUI

@main
struct QuickNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        // Settings are opened via SettingsWindowController (AppKit) — SwiftUI's
        // Settings scene does not open reliably from MenuBarExtra for LSUIElement apps.
        MenuBarExtra("Quick Notch", systemImage: "menubar.rectangle") {
            Button("Capture Note") {
                appState.showCapture()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button("Settings…") {
                appState.openSettings()
            }

            Divider()

            Button("Quit Quick Notch") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
