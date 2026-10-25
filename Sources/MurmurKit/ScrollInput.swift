import CoreGraphics

/// Turns raw scroll-wheel numbers into prompter movement.
///
/// The Magic Mouse and trackpads send precise deltas already in points, with momentum
/// after you lift your finger. A classic wheel sends whole lines, so those are scaled up.
public enum ScrollInput {
    public static func contentDelta(deltaY: CGFloat, precise: Bool, lineHeight: CGFloat, sensitivity: Double) -> CGFloat {
        (precise ? deltaY : deltaY * lineHeight) * CGFloat(sensitivity)
    }

    /// Speed change for an Option-scroll. Up or away from you is faster, whatever the
    /// natural-scrolling setting.
    public static func speedNudge(deltaY: CGFloat, invertedFromDevice: Bool, precise: Bool) -> Double {
        let physical = Double(invertedFromDevice ? -deltaY : deltaY)
        return precise ? physical * 0.12 : physical
    }
}
