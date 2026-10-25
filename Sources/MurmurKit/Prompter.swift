import Foundation
import Observation
import QuartzCore

/// Scroll position and playback state. `tick` is called once per display frame.
@MainActor
@Observable
public final class Prompter {
    /// How long auto-scroll waits after the last mouse scroll before it moves again.
    static let scrollHold: TimeInterval = 0.45
    /// How quickly auto-scroll eases in and out, so voice pauses don't jerk the text.
    static let easing: TimeInterval = 0.22

    public let settings: PrompterSettings

    public var offset: CGFloat = 0
    public var isPlaying: Bool
    public var isHovering = false
    public var voiceGateOpen = false
    /// 0...1, drives the blue beam.
    public var voiceLevel: Double = 0
    public var toast: String?

    @ObservationIgnored public var contentHeight: CGFloat = 0
    @ObservationIgnored public var viewportHeight: CGFloat = 0
    @ObservationIgnored private(set) var velocity: CGFloat = 0
    @ObservationIgnored private var lastUserScroll: TimeInterval = -.infinity
    @ObservationIgnored private var toastExpiry: TimeInterval = 0
    @ObservationIgnored private var now: TimeInterval = 0

    public init(settings: PrompterSettings) {
        self.settings = settings
        isPlaying = settings.voiceEnabled
    }

    /// The script ends once its last lines reach the upper part of the window.
    public var maxOffset: CGFloat { max(0, contentHeight - viewportHeight * 0.4) }

    var isHeldByHover: Bool { settings.pauseOnHover && isHovering }

    var isAdvancing: Bool {
        isPlaying
            && !isHeldByHover
            && now - lastUserScroll >= Self.scrollHold
            && (!settings.voiceEnabled || voiceGateOpen)
    }

    public func tick(now: TimeInterval, dt: TimeInterval) {
        self.now = now
        let target: CGFloat = isAdvancing ? CGFloat(settings.speed) : 0
        velocity += (target - velocity) * CGFloat(1 - exp(-dt / Self.easing))
        if target == 0 && velocity < 0.5 { velocity = 0 }

        if velocity > 0 {
            let next = min(offset + velocity * CGFloat(dt), maxOffset)
            if next != offset { offset = next }
            if maxOffset > 0 && next >= maxOffset {
                isPlaying = false
                velocity = 0
                showToast("End of script", now: now)
            }
        }

        if toast != nil && now >= toastExpiry { toast = nil }
    }

    /// Moves the script by a scroll-event delta. Negative deltas move further into the script,
    /// matching how AppKit scroll views treat `scrollingDeltaY`.
    public func userScroll(by delta: CGFloat, now: TimeInterval = CACurrentMediaTime()) {
        lastUserScroll = now
        velocity = 0
        offset = (offset - delta).clamped(to: 0...maxOffset)
    }

    public func nudgeSpeed(by amount: Double, now: TimeInterval = CACurrentMediaTime()) {
        settings.speed = (settings.speed + amount).clamped(to: PrompterSettings.speedRange)
        showToast("Speed \(Int(settings.speed.rounded()))", now: now)
    }

    public func togglePlay() {
        if !isPlaying && maxOffset > 0 && offset >= maxOffset { offset = 0 }
        isPlaying.toggle()
    }

    public func restart() {
        offset = 0
        velocity = 0
    }

    public func showToast(_ text: String, now: TimeInterval = CACurrentMediaTime()) {
        toast = text
        toastExpiry = now + 1.2
    }
}
