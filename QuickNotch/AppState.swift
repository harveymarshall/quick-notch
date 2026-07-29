import AppKit
import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var notesFolderPath: String {
        didSet { SettingsStore.shared.notesFolderPath = notesFolderPath }
    }

    @Published var draftText: String = ""
    @Published var isCaptureVisible: Bool = false
    @Published var statusMessage: String?
    @Published var lastError: String?
    /// Bumped when the capture field should take keyboard focus.
    @Published var focusCaptureField: Int = 0

    weak var notchController: NotchPanelController?

    private init() {
        notesFolderPath = SettingsStore.shared.notesFolderPath
    }

    var hasValidNotesFolder: Bool {
        guard !notesFolderPath.isEmpty else { return false }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: notesFolderPath, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    func showCapture() {
        guard hasValidNotesFolder else {
            lastError = "Set a notes folder in Settings before capturing."
            openSettings()
            return
        }
        lastError = nil
        statusMessage = nil
        // Let expand() reveal the editor after the same top-pinned animation as hover.
        notchController?.expand()
    }

    func hideCapture() {
        notchController?.collapse()
        isCaptureVisible = false
        draftText = ""
        statusMessage = nil
    }

    func toggleCapture() {
        if isCaptureVisible {
            hideCapture()
        } else {
            showCapture()
        }
    }

    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @discardableResult
    func saveDraft() -> Bool {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = "Nothing to save."
            return false
        }
        guard hasValidNotesFolder else {
            lastError = "Notes folder is missing. Pick it again in Settings."
            openSettings()
            return false
        }

        do {
            let url = try NoteWriter.save(
                text: trimmed,
                toFolder: URL(fileURLWithPath: notesFolderPath, isDirectory: true)
            )
            statusMessage = "Saved \(url.lastPathComponent)"
            lastError = nil
            draftText = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                self?.hideCapture()
            }
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}
