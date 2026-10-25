import AppKit
import SwiftUI

/// Renders the prompter in its main states to PNGs, so the look can be checked
/// without a notch or screen-recording access. Run `Murmur --snapshot <folder>`.
@MainActor
public enum SnapshotRenderer {
    public static func render(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = "com.rakshit.murmur.snapshot"
        UserDefaults().removePersistentDomain(forName: suite)
        let settings = PrompterSettings(defaults: UserDefaults(suiteName: suite)!)
        let prompter = Prompter(settings: settings)
        let metrics = NotchMetrics(notchWidth: 200, notchHeight: 37, isHardware: true)

        try write(SnapshotScene(prompter: prompter, metrics: metrics), to: directory, name: "1-idle")

        prompter.isHovering = true
        prompter.offset = 40
        try write(SnapshotScene(prompter: prompter, metrics: metrics, controls: true), to: directory, name: "2-hover")

        prompter.isHovering = false
        settings.voiceEnabled = true
        prompter.voiceLevel = 0.85
        prompter.offset = 120
        try write(SnapshotScene(prompter: prompter, metrics: metrics), to: directory, name: "3-speaking")

        prompter.voiceLevel = 0.05
        prompter.toast = "Speed 22"
        try write(SnapshotScene(prompter: prompter, metrics: metrics), to: directory, name: "4-quiet-toast")
    }

    private static func write(_ view: some View, to directory: URL, name: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: directory.appendingPathComponent("\(name).png"))
    }
}

/// A slice of desktop with a menu bar and camera, for context around the panel.
struct SnapshotScene: View {
    let prompter: Prompter
    let metrics: NotchMetrics
    var controls = false

    var body: some View {
        let settings = prompter.settings
        let frame = PanelLayout.frame(in: CGRect(x: 0, y: 0, width: 2000, height: 1000), metrics: metrics,
                                      width: settings.width, height: settings.height)
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(red: 0.36, green: 0.50, blue: 0.68), Color(red: 0.82, green: 0.85, blue: 0.90)],
                           startPoint: .top, endPoint: .bottom)
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(height: metrics.notchHeight)
            PrompterRootView(prompter: prompter, metrics: metrics, forceControls: controls)
                .frame(width: frame.width, height: frame.height)
            Circle()
                .fill(Color(red: 0.12, green: 0.15, blue: 0.24))
                .overlay(Circle().fill(Color(red: 0.2, green: 0.28, blue: 0.5)).padding(2.5))
                .frame(width: 9, height: 9)
                .padding(.top, 14)
        }
        .frame(width: frame.width + 260, height: frame.height + 80)
    }
}
