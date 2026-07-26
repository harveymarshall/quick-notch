import AppKit
import SwiftUI

struct NotchRootView: View {
    @EnvironmentObject private var appState: AppState

    private var topRadius: CGFloat { appState.isCaptureVisible ? 18 : 5 }
    private var bottomRadius: CGFloat { appState.isCaptureVisible ? 22 : 10 }

    var body: some View {
        ZStack(alignment: .top) {
            NotchShape(topCornerRadius: topRadius, bottomCornerRadius: bottomRadius)
                .fill(Color.black)

            if appState.isCaptureVisible {
                CaptureView()
                    .transition(.opacity)
            }
        }
        .clipShape(NotchShape(topCornerRadius: topRadius, bottomCornerRadius: bottomRadius))
        .animation(.easeInOut(duration: 0.22), value: appState.isCaptureVisible)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
    }
}

struct CaptureView: View {
    @EnvironmentObject private var appState: AppState

    private let sideMargin: CGFloat = 44
    private let topBand: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Quick capture")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text("⌘S save · esc")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            CaptureTextView(
                text: $appState.draftText,
                focusToken: appState.focusCaptureField,
                onSave: { _ = appState.saveDraft() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )

            // Footer pinned at the bottom so Save never gets clipped away.
            HStack(spacing: 10) {
                Group {
                    if let error = appState.lastError {
                        Text(error)
                            .foregroundStyle(Color.orange)
                    } else if let status = appState.statusMessage {
                        Text(status)
                            .foregroundStyle(Color.green.opacity(0.9))
                    } else {
                        Text(folderHint)
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .font(.system(size: 11))
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("Cancel") {
                    appState.hideCapture()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.75))

                Button("Save") {
                    _ = appState.saveDraft()
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .keyboardShortcut("s", modifiers: .command)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, sideMargin)
        .padding(.top, topBand)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onExitCommand {
            appState.hideCapture()
        }
    }

    private var folderHint: String {
        let path = appState.notesFolderPath
        return path.isEmpty ? "No folder set" : path
    }
}

struct CaptureTextView: NSViewRepresentable {
    @Binding var text: String
    var focusToken: Int
    var onSave: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSave: onSave)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false

        let textView = CaptureNSTextView()
        textView.delegate = context.coordinator
        textView.onSave = onSave
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = NSColor.white
        textView.insertionPointColor = NSColor.white
        textView.selectedTextAttributes = [
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.white.withAlphaComponent(0.25),
        ]
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: scroll.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.string = text

        scroll.documentView = textView
        context.coordinator.textView = textView
        return scroll
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.onSave = onSave
        guard let textView = scrollView.documentView as? CaptureNSTextView else { return }
        textView.onSave = onSave
        if textView.string != text {
            textView.string = text
        }

        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async {
                guard let window = scrollView.window else { return }
                window.makeKeyAndOrderFront(nil)
                window.makeFirstResponder(textView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var onSave: () -> Void
        weak var textView: NSTextView?
        var lastFocusToken: Int = -1

        init(text: Binding<String>, onSave: @escaping () -> Void) {
            self.text = text
            self.onSave = onSave
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            text.wrappedValue = textView.string
        }
    }
}

private final class CaptureNSTextView: NSTextView {
    var onSave: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command,
           event.charactersIgnoringModifiers?.lowercased() == "s" {
            onSave?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
