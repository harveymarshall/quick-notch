import AppKit

enum NotchGeometry {
    private static let fallbackNotchWidth: CGFloat = 184
    private static let fallbackNotchHeight: CGFloat = 32
    private static let hoverPaddingX: CGFloat = 36
    private static let hoverDepth: CGFloat = 48

    static func screenForNotch() -> NSScreen {
        NSScreen.screens.first(where: \.hasNotch)
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    /// Hardware camera-notch rectangle, always pinned to `screen.frame.maxY`
    /// (absolute top of the display — not `visibleFrame`, which sits under the menu bar).
    static func physicalNotchRect(on screen: NSScreen) -> NSRect {
        let frame = screen.frame
        var width = fallbackNotchWidth
        var height = fallbackNotchHeight

        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let gap = right.minX - left.maxX
            if gap > 40 {
                width = gap
                // Use the menu-bar band height, but keep the TOP on screen.frame.maxY.
                height = max(left.height, screen.safeAreaInsets.top, fallbackNotchHeight)
            }
        } else if screen.safeAreaInsets.top > 0 {
            height = screen.safeAreaInsets.top
            let insetDerived = screen.safeAreaInsets.left + screen.safeAreaInsets.right
            if insetDerived > 40 {
                width = max(fallbackNotchWidth, insetDerived)
            }
        }

        return NSRect(
            x: frame.midX - width / 2,
            y: frame.maxY - height,
            width: width,
            height: height
        )
    }

    static func physicalNotchSize(on screen: NSScreen) -> NSSize {
        physicalNotchRect(on: screen).size
    }

    static func hoverZone(on screen: NSScreen) -> NSRect {
        let notch = physicalNotchRect(on: screen)
        return NSRect(
            x: notch.minX - hoverPaddingX,
            y: notch.minY - hoverDepth,
            width: notch.width + hoverPaddingX * 2,
            height: notch.height + hoverDepth
        )
    }

    /// Expanded/collapsed window frame — top edge always equals `screen.frame.maxY`.
    static func frame(for size: NSSize, on screen: NSScreen) -> NSRect {
        let notch = physicalNotchRect(on: screen)
        return NSRect(
            x: notch.midX - size.width / 2,
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}

private extension NSScreen {
    var hasNotch: Bool {
        if let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea {
            return right.minX - left.maxX > 40
        }
        return safeAreaInsets.top > 0
    }
}
