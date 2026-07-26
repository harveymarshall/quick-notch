import AppKit
import QuartzCore
import SwiftUI

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

final class NotchHostingView<Content: View>: NSHostingView<Content> {
    override var safeAreaInsets: NSEdgeInsets { NSEdgeInsets() }
}

@MainActor
final class NotchPanelController {
    private let appState: AppState
    private var panel: KeyablePanel?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var keyMonitor: Any?
    private var collapseWorkItem: DispatchWorkItem?
    private var focusWorkItem: DispatchWorkItem?
    private var resizeTimer: Timer?

    private var collapsedSize: NSSize
    private let expandedSize = NSSize(width: 560, height: 320)

    init(appState: AppState) {
        self.appState = appState
        let screen = NotchGeometry.screenForNotch()
        self.collapsedSize = NotchGeometry.physicalNotchSize(on: screen)
        createPanel()
        collapse(animated: false)
        startMouseMonitoring()
    }

    func stopMouseMonitoring() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        removeKeyMonitor()
        resizeTimer?.invalidate()
        resizeTimer = nil
    }

    func expand() {
        guard let panel else { return }
        cancelCollapse()
        resizeTimer?.invalidate()

        // Grow the window first (top edge locked), then reveal the editor.
        // Showing CaptureView while still collapsed was clipping the Save button
        // and stealing/breaking text focus.
        panel.alphaValue = 1
        panel.hasShadow = false
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        animateTopPinned(panel: panel, to: expandedSize) { [weak self] in
            guard let self, let panel = self.panel else { return }
            self.appState.isCaptureVisible = true
            panel.hasShadow = true
            self.installKeyMonitor()
            self.focusEditor(after: 0.05)
        }
    }

    func collapse(animated: Bool = true) {
        guard let panel else { return }
        cancelCollapse()
        focusWorkItem?.cancel()
        resizeTimer?.invalidate()
        removeKeyMonitor()

        appState.isCaptureVisible = false
        appState.draftText = ""
        appState.statusMessage = nil
        panel.hasShadow = false

        let finish = { [weak self] in
            guard let self, let panel = self.panel else { return }
            self.position(panel: panel, size: self.collapsedSize)
            if panel.isKeyWindow {
                panel.resignKey()
            }
        }

        if animated {
            animateTopPinned(panel: panel, to: collapsedSize, completion: finish)
        } else {
            finish()
        }
        panel.orderFrontRegardless()
    }

    private func createPanel() {
        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: collapsedSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = false

        let root = NotchRootView()
            .environmentObject(appState)
        let hosting = NotchHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: collapsedSize)
        panel.contentView = hosting

        self.panel = panel
    }

    private func startMouseMonitoring() {
        let handler: (NSEvent) -> Void = { [weak self] _ in
            Task { @MainActor in
                self?.handleMouseLocation(NSEvent.mouseLocation)
            }
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged]
        ) { event in
            handler(event)
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged]
        ) { event in
            handler(event)
            return event
        }
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .command,
               event.charactersIgnoringModifiers?.lowercased() == "s" {
                _ = self.appState.saveDraft()
                return nil
            }
            if event.keyCode == 53 { // escape
                self.appState.hideCapture()
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func focusEditor(after delay: TimeInterval) {
        focusWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let panel = self.panel else { return }
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            self.appState.focusCaptureField += 1
        }
        focusWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func handleMouseLocation(_ location: NSPoint) {
        let screen = NotchGeometry.screenForNotch()
        let hoverZone = NotchGeometry.hoverZone(on: screen)
        let inHoverZone = hoverZone.contains(location)

        if appState.isCaptureVisible {
            let overPanel = panel?.frame.contains(location) == true
            if inHoverZone || overPanel || !appState.draftText.isEmpty {
                cancelCollapse()
            } else {
                scheduleCollapse()
            }
        } else if inHoverZone {
            guard appState.hasValidNotesFolder else { return }
            // Don't restart expand mid-animation.
            guard panel?.frame.size != expandedSize || !appState.isCaptureVisible else { return }
            guard resizeTimer == nil else { return }
            appState.lastError = nil
            appState.statusMessage = nil
            expand()
        }
    }

    private func scheduleCollapse() {
        guard collapseWorkItem == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.collapseWorkItem = nil
            if self.appState.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.appState.hideCapture()
            }
        }
        collapseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }

    private func cancelCollapse() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
    }

    private func position(panel: NSPanel, size: NSSize) {
        let screen = NotchGeometry.screenForNotch()
        var target = size == collapsedSize
            ? NotchGeometry.physicalNotchRect(on: screen)
            : NotchGeometry.frame(for: size, on: screen)
        target.origin.y = screen.frame.maxY - target.height
        panel.setFrame(target, display: true)
    }

    /// Resize while keeping the top edge glued to `screen.frame.maxY` on every frame.
    private func animateTopPinned(panel: NSPanel, to size: NSSize, completion: (() -> Void)? = nil) {
        let screen = NotchGeometry.screenForNotch()
        let topY = screen.frame.maxY
        let start = panel.frame
        var end = size == collapsedSize
            ? NotchGeometry.physicalNotchRect(on: screen)
            : NotchGeometry.frame(for: size, on: screen)
        end.origin.y = topY - end.height

        let duration = 0.30
        let startTime = CACurrentMediaTime()
        resizeTimer?.invalidate()

        resizeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            let progress = min(1, (CACurrentMediaTime() - startTime) / duration)
            let e = Self.easeInOut(progress)
            let width = start.width + (end.width - start.width) * e
            let height = start.height + (end.height - start.height) * e
            let midX = start.midX + (end.midX - start.midX) * e
            let frame = NSRect(
                x: midX - width / 2,
                y: topY - height,
                width: width,
                height: height
            )
            panel.setFrame(frame, display: true)

            if progress >= 1 {
                timer.invalidate()
                Task { @MainActor in
                    self?.resizeTimer = nil
                    panel.setFrame(end, display: true)
                    completion?()
                }
            }
        }
        if let resizeTimer {
            RunLoop.main.add(resizeTimer, forMode: .common)
        }
    }

    private static func easeInOut(_ t: CGFloat) -> CGFloat {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}
