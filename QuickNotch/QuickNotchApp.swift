import SwiftUI

@main
struct QuickNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appState)
        }

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
