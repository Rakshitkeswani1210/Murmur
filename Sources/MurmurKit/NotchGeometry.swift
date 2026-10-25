import AppKit
import SwiftUI

/// Size of the camera notch, or of a stand-in notch on screens without one.
public struct NotchMetrics: Equatable {
    public var notchWidth: CGFloat
    public var notchHeight: CGFloat
    public var isHardware: Bool

    public init(notchWidth: CGFloat, notchHeight: CGFloat, isHardware: Bool) {
        self.notchWidth = notchWidth
        self.notchHeight = notchHeight
        self.isHardware = isHardware
    }

    public static func of(_ screen: NSScreen) -> NotchMetrics {
        let top = screen.safeAreaInsets.top
        if top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let width = screen.frame.width - left.width - right.width
            return NotchMetrics(notchWidth: width, notchHeight: top, isHardware: true)
        }
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        return NotchMetrics(notchWidth: 190, notchHeight: menuBar > 0 ? menuBar : 24, isHardware: false)
    }
}

public enum PanelLayout {
    /// Radius of the concave "shoulders" where the panel meets the top of the screen.
    public static let shoulder: CGFloat = 14
    public static let bottomRadius: CGFloat = 24

    /// Panel frame in screen coordinates: flush with the top edge, centred on the notch.
    /// Always leaves room beside the notch for the hover buttons.
    public static func frame(in screenFrame: CGRect, metrics: NotchMetrics, width: CGFloat, height: CGFloat) -> CGRect {
        let w = max(width, metrics.notchWidth + 2 * shoulder + 80).rounded()
        let h = max(height, metrics.notchHeight + 60).rounded()
        return CGRect(x: (screenFrame.midX - w / 2).rounded(), y: screenFrame.maxY - h, width: w, height: h)
    }
}

/// The notch silhouette: concave shoulders at the top that melt into the menu bar,
/// straight sides, and rounded bottom corners.
public struct NotchShape: Shape {
    public var shoulder: CGFloat
    public var bottomRadius: CGFloat

    public init(shoulder: CGFloat = PanelLayout.shoulder, bottomRadius: CGFloat = PanelLayout.bottomRadius) {
        self.shoulder = shoulder
        self.bottomRadius = bottomRadius
    }

    public func path(in rect: CGRect) -> Path {
        let s = min(shoulder, rect.width / 4, rect.height / 2)
        let r = max(0, min(bottomRadius, (rect.width - 2 * s) / 2, rect.height - s))
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addArc(tangent1End: CGPoint(x: rect.minX + s, y: rect.minY),
                 tangent2End: CGPoint(x: rect.minX + s, y: rect.maxY), radius: s)
        p.addArc(tangent1End: CGPoint(x: rect.minX + s, y: rect.maxY),
                 tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: r)
        p.addArc(tangent1End: CGPoint(x: rect.maxX - s, y: rect.maxY),
                 tangent2End: CGPoint(x: rect.maxX - s, y: rect.minY), radius: r)
        p.addArc(tangent1End: CGPoint(x: rect.maxX - s, y: rect.minY),
                 tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: s)
        p.closeSubpath()
        return p
    }
}
