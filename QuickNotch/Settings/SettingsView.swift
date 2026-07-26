import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes folder")
                        .font(.headline)

                    Text("Markdown files from the notch capture UI are written here. Point this at an Obsidian vault folder (or any local directory).")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Text(displayPath)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )

                        Button("Choose…") {
                            chooseFolder()
                        }
                    }

                    if !appState.notesFolderPath.isEmpty && !appState.hasValidNotesFolder {
                        Text("That folder no longer exists. Choose it again.")
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to capture")
                        .font(.headline)
                    labeled("Menu bar", "Click the Quick Notch icon → Capture Note")
                    labeled("Hotkey", "⌘⇧N opens the notch capture panel")
                    labeled("Save", "⌘↵ or the Save button writes a .md file")
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 360)
        .navigationTitle("Quick Notch")
    }

    private var displayPath: String {
        let path = appState.notesFolderPath
        return path.isEmpty ? "No folder selected" : path
    }

    private func labeled(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .frame(width: 90, alignment: .leading)
                .foregroundStyle(.secondary)
            Text(detail)
            Spacer()
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Choose the folder where Quick Notch should save .md notes"

        if !appState.notesFolderPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: appState.notesFolderPath)
        }

        if panel.runModal() == .OK, let url = panel.url {
            appState.notesFolderPath = url.path
        }
    }
}
