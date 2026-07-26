import SwiftUI

struct NotchRootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isCaptureVisible {
                CaptureView()
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            } else {
                CollapsedNotchView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: appState.isCaptureVisible)
    }
}

struct CollapsedNotchView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Button {
            appState.showCapture()
        } label: {
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.9))
                .overlay(
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Capture")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                )
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .help("Open quick capture")
    }
}

struct CaptureView: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Quick capture")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(shortcutHint)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            ZStack(alignment: .topLeading) {
                if appState.draftText.isEmpty {
                    Text("Type a note… first line becomes the title")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $appState.draftText)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .frame(minHeight: 110)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )

            HStack(spacing: 8) {
                if let error = appState.lastError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.orange)
                        .lineLimit(2)
                } else if let status = appState.statusMessage {
                    Text(status)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.green.opacity(0.9))
                } else {
                    Text(folderHint)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button("Cancel") {
                    appState.hideCapture()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.7))

                Button("Save") {
                    _ = appState.saveDraft()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(6)
        .onAppear {
            isFocused = true
        }
        .onExitCommand {
            appState.hideCapture()
        }
    }

    private var shortcutHint: String {
        "⌘⇧N · ⌘↵ save · esc"
    }

    private var folderHint: String {
        let path = appState.notesFolderPath
        return path.isEmpty ? "No folder set" : path
    }
}
