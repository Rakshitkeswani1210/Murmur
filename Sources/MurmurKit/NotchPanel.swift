import AppKit
import SwiftUI

/// Borderless panel that sits over the menu bar, on every Space, without taking focus.
final class NotchPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // Above the menu bar. (Don't set isFloatingPanel: it resets this to .floating.)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // AppKit would otherwise push the window below the menu bar.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// Hosts the SwiftUI prompter and handles the mouse: hover to pause, Magic Mouse to scroll,
/// Option + scroll to change speed.
final class PrompterHostingView: NSHostingView<PrompterRootView> {
    weak var prompter: Prompter?
    private var hoverArea: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if event.trackingArea === hoverArea { prompter?.isHovering = true }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if event.trackingArea === hoverArea { prompter?.isHovering = false }
    }

    override func scrollWheel(with event: NSEvent) {
        guard let prompter else { return super.scrollWheel(with: event) }
        // Magic Mouse sideways swipes shouldn't move the script.
        guard abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX) else { return }

        if event.modifierFlags.contains(.option) {
            // Ignore the momentum tail so speed stops changing when your finger lifts.
            guard event.momentumPhase.isEmpty, event.scrollingDeltaY != 0 else { return }
            prompter.nudgeSpeed(by: ScrollInput.speedNudge(deltaY: event.scrollingDeltaY,
                                                           invertedFromDevice: event.isDirectionInvertedFromDevice,
                                                           precise: event.hasPreciseScrollingDeltas))
        } else {
            let settings = prompter.settings
            prompter.userScroll(by: ScrollInput.contentDelta(deltaY: event.scrollingDeltaY,
                                                             precise: event.hasPreciseScrollingDeltas,
                                                             lineHeight: settings.lineHeight,
                                                             sensitivity: settings.scrollSensitivity))
        }
    }
}

/// Owns the notch panel: placement, frame clock, and screen-capture visibility.
@MainActor
final class PrompterWindowController: NSObject {
    let panel = NotchPanel()
    private let prompter: Prompter
    private let hosting: PrompterHostingView
    private let allowCapture: Bool
    private var metrics = NotchMetrics(notchWidth: 190, notchHeight: 24, isHardware: false)
    private var link: CADisplayLink?
    private var lastFrame: CFTimeInterval?

    init(prompter: Prompter, allowCapture: Bool) {
        self.prompter = prompter
        self.allowCapture = allowCapture
        hosting = PrompterHostingView(rootView: PrompterRootView(prompter: prompter, metrics: metrics))
        super.init()
        hosting.prompter = prompter
        panel.contentView = hosting
        relayout()
        applyCapturePolicy()

        let link = panel.displayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    var isVisible: Bool { panel.isVisible }

    /// The built-in notched display if it's on, otherwise the menu bar screen.
    private var targetScreen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.screens.first
    }

    func relayout() {
        guard let screen = targetScreen else { return }
        let newMetrics = NotchMetrics.of(screen)
        if newMetrics != metrics {
            metrics = newMetrics
            hosting.rootView = PrompterRootView(prompter: prompter, metrics: metrics)
        }
        let settings = prompter.settings
        panel.setFrame(PanelLayout.frame(in: screen.frame, metrics: metrics,
                                         width: settings.width, height: settings.height),
                       display: true)
    }

    func applyCapturePolicy() {
        panel.sharingType = prompter.settings.hideFromCapture && !allowCapture ? .none : .readOnly
    }

    func show() {
        relayout()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { [panel] in
            panel.orderOut(nil)
        })
    }

    @objc private func step(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt = lastFrame.map { min(now - $0, 1.0 / 20) } ?? 0
        lastFrame = now
        prompter.tick(now: now, dt: dt)
    }
}
