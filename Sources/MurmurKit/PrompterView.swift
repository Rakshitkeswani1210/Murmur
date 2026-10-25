import SwiftUI

/// Everything drawn inside the notch panel.
public struct PrompterRootView: View {
    let prompter: Prompter
    let metrics: NotchMetrics
    var forceControls = false

    public init(prompter: Prompter, metrics: NotchMetrics, forceControls: Bool = false) {
        self.prompter = prompter
        self.metrics = metrics
        self.forceControls = forceControls
    }

    public var body: some View {
        ZStack {
            Color.black
            PrompterBody(prompter: prompter, cameraHeight: metrics.notchHeight, forceControls: forceControls)
                .padding(.horizontal, PanelLayout.shoulder)
        }
        .clipShape(NotchShape())
    }
}

struct PrompterBody: View {
    let prompter: Prompter
    let cameraHeight: CGFloat
    let forceControls: Bool

    var body: some View {
        ZStack {
            if prompter.settings.voiceEnabled {
                VoiceBeam(level: prompter.voiceLevel)
            }
            ScriptViewport(prompter: prompter)
                .padding(.top, cameraHeight - 2)
                .padding(.bottom, 6)
            if forceControls || prompter.isHovering {
                HoverControls(prompter: prompter, stripHeight: cameraHeight)
                    .transition(.opacity)
            }
            if let toast = prompter.toast {
                ToastLabel(text: toast)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 14)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: prompter.isHovering)
        .animation(.easeOut(duration: 0.18), value: prompter.toast)
    }
}

/// The visible window onto the script, faded at the top and bottom.
struct ScriptViewport: View {
    let prompter: Prompter

    var body: some View {
        GeometryReader { geo in
            ScrollingScript(prompter: prompter, width: geo.size.width)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                .mask(FadeMask(height: geo.size.height))
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { prompter.viewportHeight = $0 }
    }
}

/// Kept separate so only this view re-renders on every frame of scrolling.
struct ScrollingScript: View {
    let prompter: Prompter
    let width: CGFloat

    var body: some View {
        ScriptText(script: prompter.settings.script, fontSize: prompter.settings.fontSize)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(width: width)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { prompter.contentHeight = $0 }
            .offset(y: -prompter.offset)
    }
}

struct ScriptText: View, Equatable {
    let script: String
    let fontSize: Double

    var body: some View {
        Text(Self.styled(script, fontSize: fontSize))
            .multilineTextAlignment(.center)
            .lineSpacing(fontSize * 0.45)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    /// Script text in white; [stage directions] dimmed and italic.
    static func styled(_ script: String, fontSize: Double) -> AttributedString {
        var text = AttributedString(script)
        text.font = .system(size: fontSize, weight: .medium, design: .monospaced)
        text.foregroundColor = .white.opacity(0.93)

        var searchStart = text.startIndex
        while let open = text[searchStart...].range(of: "["),
              let close = text[open.upperBound...].range(of: "]") {
            let range = open.lowerBound..<close.upperBound
            text[range].font = .system(size: fontSize, weight: .regular, design: .monospaced).italic()
            text[range].foregroundColor = .white.opacity(0.38)
            searchStart = close.upperBound
        }
        return text
    }
}

struct FadeMask: View {
    let height: CGFloat

    var body: some View {
        let h = max(height, 1)
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: min(16 / h, 0.3)),
                .init(color: .black, location: 1 - min(28 / h, 0.35)),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// The blue glow that rises from the bottom edge while you speak.
struct VoiceBeam: View {
    static let blue = Color(red: 0.25, green: 0.38, blue: 1.0)
    static let rim = Color(red: 0.62, green: 0.70, blue: 1.0)

    let level: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * (0.5 + 0.2 * level)
            let h = w * 0.5
            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [Self.blue.opacity(0.8), Self.blue.opacity(0.25), Self.blue.opacity(0)],
                                         center: .center, startRadius: 0, endRadius: w * 0.55))
                Ellipse()
                    .stroke(Self.blue, lineWidth: 10)
                    .blur(radius: 9)
                Ellipse()
                    .stroke(Self.rim, lineWidth: 2)
                    .blur(radius: 1.5)
            }
            .frame(width: w, height: h)
            .position(x: geo.size.width / 2, y: geo.size.height + h * 0.16)
            .opacity(0.16 + 0.84 * level)
        }
        .allowsHitTesting(false)
    }
}

/// Pause and back-to-top, in the black strip either side of the camera so they never
/// cover the script.
struct HoverControls: View {
    let prompter: Prompter
    let stripHeight: CGFloat

    var body: some View {
        let size = min(24, stripHeight - 4)
        HStack {
            RoundIconButton(symbol: prompter.isPlaying ? "pause.fill" : "play.fill",
                            help: prompter.isPlaying ? "Pause" : "Play", size: size) {
                prompter.togglePlay()
            }
            Spacer()
            RoundIconButton(symbol: "arrow.counterclockwise", help: "Back to the top", size: size) {
                prompter.restart()
            }
        }
        .padding(.horizontal, 8)
        .frame(height: stripHeight)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct RoundIconButton: View {
    let symbol: String
    let help: String
    let size: CGFloat
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: size, height: size)
                .background(Circle().fill(Color.white.opacity(hovering ? 0.24 : 0.14)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering = $0 }
    }
}

struct ToastLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color(white: 0.2)))
    }
}
