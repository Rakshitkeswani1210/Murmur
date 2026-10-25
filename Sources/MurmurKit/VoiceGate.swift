import Foundation

/// Decides from mic level whether you are speaking.
///
/// It opens after a short burst above the threshold, ignores gaps between words, and
/// closes after `hold` seconds of quiet. Once open it uses a lower threshold
/// (hysteresis) so a trailing-off sentence doesn't stutter.
public struct VoiceGate {
    public var openThresholdDB: Float = -40
    public var hysteresisDB: Float = 6
    public var attack: TimeInterval = 0.06
    public var hold: TimeInterval = 0.7

    public private(set) var isOpen = false
    private var loudFor: TimeInterval = 0
    private var quietFor: TimeInterval = 0

    public init() {}

    @discardableResult
    public mutating func update(levelDB: Float, dt: TimeInterval) -> Bool {
        let threshold = isOpen ? openThresholdDB - hysteresisDB : openThresholdDB
        if levelDB >= threshold {
            loudFor += dt
            quietFor = 0
            if !isOpen && loudFor >= attack { isOpen = true }
        } else {
            quietFor += dt
            loudFor = 0
            if isOpen && quietFor >= hold { isOpen = false }
        }
        return isOpen
    }

    public mutating func reset() {
        isOpen = false
        loudFor = 0
        quietFor = 0
    }

    /// Maps dBFS onto 0...1 for the beam and the level meter.
    public static func normalized(_ db: Float) -> Double {
        Double((db + 60) / 45).clamped(to: 0...1)
    }
}
