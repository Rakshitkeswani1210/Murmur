import AppKit
import Testing
@testable import MurmurKit

@MainActor
private func makePrompter(voice: Bool = false) -> Prompter {
    let settings = PrompterSettings(defaults: UserDefaults(suiteName: "murmur.tests.\(UUID().uuidString)")!)
    settings.voiceEnabled = voice
    let prompter = Prompter(settings: settings)
    prompter.contentHeight = 2000
    prompter.viewportHeight = 120
    return prompter
}

/// Ticks the prompter at 60 fps and returns the clock time it ended on.
@MainActor
@discardableResult
private func run(_ prompter: Prompter, seconds: Double, from start: Double = 0) -> Double {
    let dt = 1.0 / 60
    var t = start
    for _ in 0..<Int(seconds * 60) {
        t += dt
        prompter.tick(now: t, dt: dt)
    }
    return t
}

@Suite @MainActor struct AutoScrollTests {
    @Test func scrollsAtRoughlyTheSetSpeed() {
        let p = makePrompter()
        p.settings.speed = 20
        p.isPlaying = true
        run(p, seconds: 3)
        // Easing in costs about a quarter second of travel.
        #expect(p.offset > 20 * 2.6 && p.offset < 20 * 3)
    }

    @Test func pausedStaysPut() {
        let p = makePrompter()
        run(p, seconds: 2)
        #expect(p.offset == 0)
    }

    @Test func hoverHoldsThenResumesFromTheSamePlace() {
        let p = makePrompter()
        p.isPlaying = true
        var t = run(p, seconds: 2)
        p.isHovering = true
        t = run(p, seconds: 1, from: t)
        let held = p.offset
        t = run(p, seconds: 2, from: t)
        #expect(p.offset == held)
        p.isHovering = false
        run(p, seconds: 1, from: t)
        #expect(p.offset > held)
    }

    @Test func stopsAtTheEndOfTheScript() {
        let p = makePrompter()
        p.contentHeight = 300
        p.isPlaying = true
        run(p, seconds: 30)
        #expect(p.offset == p.maxOffset)
        #expect(!p.isPlaying)
    }
}

@Suite @MainActor struct VoiceScrollTests {
    @Test func movesOnlyWhileSpeakingAndWaitsWhereYouStopped() {
        let p = makePrompter(voice: true)
        #expect(p.isPlaying, "voice mode starts armed")
        var t = run(p, seconds: 1)
        #expect(p.offset == 0)

        p.voiceGateOpen = true
        t = run(p, seconds: 1, from: t)
        let afterSpeaking = p.offset
        #expect(afterSpeaking > 0)

        p.voiceGateOpen = false
        t = run(p, seconds: 1, from: t)
        let stopped = p.offset
        run(p, seconds: 3, from: t)
        #expect(p.offset == stopped)
        #expect(stopped - afterSpeaking < 8, "eases to a stop instead of sliding on")
    }
}

@Suite struct VoiceGateTests {
    private func feed(_ gate: inout VoiceGate, db: Float, seconds: Double) {
        let dt = 0.02
        for _ in 0..<Int((seconds / dt).rounded()) { gate.update(levelDB: db, dt: dt) }
    }

    private func openGate() -> VoiceGate {
        var gate = VoiceGate()
        feed(&gate, db: -25, seconds: 0.2)
        return gate
    }

    @Test func opensWhenYouSpeak() {
        #expect(openGate().isOpen)
    }

    @Test func ignoresASingleClick() {
        var gate = VoiceGate()
        feed(&gate, db: -15, seconds: 0.02)
        feed(&gate, db: -70, seconds: 0.3)
        #expect(!gate.isOpen)
    }

    @Test func staysOpenThroughGapsBetweenWords() {
        var gate = openGate()
        feed(&gate, db: -70, seconds: 0.4)
        #expect(gate.isOpen)
    }

    @Test func closesAfterAPause() {
        var gate = openGate()
        feed(&gate, db: -70, seconds: 0.8)
        #expect(!gate.isOpen)
    }

    @Test func trailingOffSentenceKeepsItOpen() {
        var gate = openGate()
        feed(&gate, db: -43, seconds: 2)
        #expect(gate.isOpen)
    }

    @Test func roomNoiseNeverOpensIt() {
        var gate = VoiceGate()
        feed(&gate, db: -50, seconds: 3)
        #expect(!gate.isOpen)
    }
}

@Suite @MainActor struct MouseTests {
    private func makeView(_ prompter: Prompter) -> PrompterHostingView {
        _ = NSApplication.shared
        let view = PrompterHostingView(rootView: PrompterRootView(prompter: prompter, metrics: .init(notchWidth: 200, notchHeight: 37, isHardware: true)))
        view.prompter = prompter
        return view
    }

    private func scrollEvent(_ units: CGScrollEventUnit, _ amount: Int32, option: Bool = false) -> NSEvent {
        let cg = CGEvent(scrollWheelEvent2Source: nil, units: units, wheelCount: 1, wheel1: amount, wheel2: 0, wheel3: 0)!
        if option { cg.flags = .maskAlternate }
        return NSEvent(cgEvent: cg)!
    }

    @Test func magicMouseSwipeMovesTheScriptPointForPoint() {
        let p = makePrompter()
        p.offset = 100
        let swipe = scrollEvent(.pixel, -30)
        #expect(swipe.hasPreciseScrollingDeltas)
        makeView(p).scrollWheel(with: swipe)
        #expect(p.offset == 100 - swipe.scrollingDeltaY)
        #expect(p.offset > 100, "swiping toward later text moves forward")
    }

    @Test func wheelClickMovesAboutALine() {
        let p = makePrompter()
        let click = scrollEvent(.line, -1)
        #expect(!click.hasPreciseScrollingDeltas)
        makeView(p).scrollWheel(with: click)
        #expect(p.offset == -click.scrollingDeltaY * p.settings.lineHeight)
        #expect(p.offset >= p.settings.lineHeight * 0.5)
    }

    @Test func scrollingCannotGoAboveTheTop() {
        let p = makePrompter()
        p.offset = 10
        makeView(p).scrollWheel(with: scrollEvent(.pixel, 80))
        #expect(p.offset == 0)
    }

    @Test func optionScrollChangesSpeedNotPosition() {
        let p = makePrompter()
        let before = p.settings.speed
        makeView(p).scrollWheel(with: scrollEvent(.pixel, 40, option: true))
        #expect(p.settings.speed != before)
        #expect(p.offset == 0)
        #expect(p.toast?.hasPrefix("Speed") == true)
    }

    @Test func autoScrollWaitsBrieflyAfterYouScrollThenCarriesOn() {
        let p = makePrompter()
        p.isPlaying = true
        p.userScroll(by: -50, now: 1)
        var t = run(p, seconds: 0.3, from: 1)
        #expect(p.offset == 50)
        t = run(p, seconds: 1, from: t)
        #expect(p.offset > 50)
    }
}

@Suite @MainActor struct KeyboardTests {
    @Test func editShortcutsReachTheScriptEditor() {
        let menu = AppDelegate.makeMainMenu()
        let edit = menu.items.compactMap(\.submenu).first { $0.title == "Edit" }
        let shortcuts = Dictionary(uniqueKeysWithValues: (edit?.items ?? [])
            .filter { $0.keyEquivalentModifierMask == .command && !$0.keyEquivalent.isEmpty }
            .map { ($0.keyEquivalent, $0.action) })
        #expect(shortcuts["v"] == #selector(NSText.paste(_:)))
        #expect(shortcuts["c"] == #selector(NSText.copy(_:)))
        #expect(shortcuts["x"] == #selector(NSText.cut(_:)))
        #expect(shortcuts["a"] == #selector(NSText.selectAll(_:)))
    }
}

@Suite struct LayoutTests {
    @Test func panelHangsFromTheTopCentre() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let frame = PanelLayout.frame(in: screen, metrics: .init(notchWidth: 200, notchHeight: 38, isHardware: true),
                                      width: 400, height: 170)
        #expect(frame == CGRect(x: 556, y: 812, width: 400, height: 170))
    }

    @Test func panelLeavesRoomForButtonsBesideTheNotch() {
        let frame = PanelLayout.frame(in: CGRect(x: 0, y: 0, width: 1512, height: 982),
                                      metrics: .init(notchWidth: 200, notchHeight: 38, isHardware: true),
                                      width: 100, height: 170)
        #expect(frame.width >= 200 + 2 * PanelLayout.shoulder + 80)
    }

    @Test func notchShapeFillsItsFrame() {
        let rect = CGRect(x: 0, y: 0, width: 400, height: 170)
        let bounds = NotchShape().path(in: rect).boundingRect
        #expect(abs(bounds.width - rect.width) < 0.5)
        #expect(abs(bounds.height - rect.height) < 0.5)
    }
}
