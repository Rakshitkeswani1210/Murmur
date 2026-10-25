import Foundation
import Observation

/// Everything the user can change. Each value is saved to UserDefaults as soon as it changes.
@MainActor
@Observable
public final class PrompterSettings {
    public static let speedRange: ClosedRange<Double> = 4...60
    public static let fontSizeRange: ClosedRange<Double> = 12...28
    public static let widthRange: ClosedRange<Double> = 300...720
    public static let heightRange: ClosedRange<Double> = 110...340
    public static let scrollSensitivityRange: ClosedRange<Double> = 0.5...2.5

    @ObservationIgnored private let defaults: UserDefaults

    public var script: String { didSet { defaults.set(script, forKey: Key.script) } }
    /// Auto-scroll speed in points per second.
    public var speed: Double { didSet { defaults.set(speed, forKey: Key.speed) } }
    public var fontSize: Double { didSet { defaults.set(fontSize, forKey: Key.fontSize) } }
    public var width: Double { didSet { defaults.set(width, forKey: Key.width) } }
    public var height: Double { didSet { defaults.set(height, forKey: Key.height) } }
    public var voiceEnabled: Bool { didSet { defaults.set(voiceEnabled, forKey: Key.voiceEnabled) } }
    /// 0 needs a loud voice, 1 reacts to a whisper.
    public var micSensitivity: Double { didSet { defaults.set(micSensitivity, forKey: Key.micSensitivity) } }
    public var hideFromCapture: Bool { didSet { defaults.set(hideFromCapture, forKey: Key.hideFromCapture) } }
    public var pauseOnHover: Bool { didSet { defaults.set(pauseOnHover, forKey: Key.pauseOnHover) } }
    /// Multiplier on Magic Mouse and trackpad scroll distance.
    public var scrollSensitivity: Double { didSet { defaults.set(scrollSensitivity, forKey: Key.scrollSensitivity) } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        script = defaults.string(forKey: Key.script) ?? Self.sampleScript
        speed = defaults.double(Key.speed, default: 16)
        fontSize = defaults.double(Key.fontSize, default: 17)
        width = defaults.double(Key.width, default: 400)
        height = defaults.double(Key.height, default: 170)
        voiceEnabled = defaults.bool(Key.voiceEnabled, default: false)
        micSensitivity = defaults.double(Key.micSensitivity, default: 0.5)
        hideFromCapture = defaults.bool(Key.hideFromCapture, default: true)
        pauseOnHover = defaults.bool(Key.pauseOnHover, default: true)
        scrollSensitivity = defaults.double(Key.scrollSensitivity, default: 1)
    }

    /// Mic level (dBFS) that counts as speech.
    public var thresholdDB: Float { Float(-25 - 30 * micSensitivity) }

    /// Height of one line of script, used to turn mouse-wheel clicks into points.
    public var lineHeight: CGFloat { CGFloat(fontSize) * 1.45 }

    private enum Key {
        static let script = "script"
        static let speed = "speed"
        static let fontSize = "fontSize"
        static let width = "width"
        static let height = "height"
        static let voiceEnabled = "voiceEnabled"
        static let micSensitivity = "micSensitivity"
        static let hideFromCapture = "hideFromCapture"
        static let pauseOnHover = "pauseOnHover"
        static let scrollSensitivity = "scrollSensitivity"
    }

    public static let sampleScript = """
    Welcome to Murmur. This line sits right under your camera, so your eyes stay on the lens while you read.

    Hover over the prompter to pause. Scroll with your Magic Mouse to go back or skip ahead, then move the pointer away to keep going. [pause]

    Hold Option while you scroll to change the speed.

    Turn on voice from the menu bar and the text only moves while you talk. Stop for a breath and it waits for you, right where you left off. [smile]

    Click the menu bar icon and choose Edit Script to paste your own words.
    """
}

private extension UserDefaults {
    func double(_ key: String, default value: Double) -> Double {
        object(forKey: key) as? Double ?? value
    }

    func bool(_ key: String, default value: Bool) -> Bool {
        object(forKey: key) as? Bool ?? value
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
