import SwiftUI

/// MacBook-notch silhouette (Boring Notch / MacNotch style).
///
/// The top edge stays flush with the top of the screen so the camera notch
/// itself appears to grow. Top corners curve inward; bottom corners flare out.
///
/// Typical radii:
/// - Collapsed: top = 6, bottom = 14
/// - Expanded:  top = 19, bottom = 24
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    init(topCornerRadius: CGFloat = 6, bottomCornerRadius: CGFloat = 14) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topR = max(0, topCornerRadius)
        let botR = max(0, bottomCornerRadius)

        // Flat top edge — glued to the top of the screen / physical notch.
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Top-left: curve inward under the menu bar.
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topR, y: rect.minY + topR),
            control: CGPoint(x: rect.minX + topR, y: rect.minY)
        )

        // Left side down to the tray.
        path.addLine(to: CGPoint(x: rect.minX + topR, y: rect.maxY - botR))

        // Bottom-left outward corner.
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topR + botR, y: rect.maxY),
            control: CGPoint(x: rect.minX + topR, y: rect.maxY)
        )

        // Bottom edge.
        path.addLine(to: CGPoint(x: rect.maxX - topR - botR, y: rect.maxY))

        // Bottom-right outward corner.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topR, y: rect.maxY - botR),
            control: CGPoint(x: rect.maxX - topR, y: rect.maxY)
        )

        // Right side up.
        path.addLine(to: CGPoint(x: rect.maxX - topR, y: rect.minY + topR))

        // Top-right: curve inward to the flat top edge.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topR, y: rect.minY)
        )

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
