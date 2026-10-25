import AppKit
import SwiftUI

@MainActor
final class EditorWindowController {
    private let prompter: Prompter
    private var window: NSWindow?

    init(prompter: Prompter) {
        self.prompter = prompter
    }

    func show() {
        if window == nil {
            let controller = NSHostingController(rootView: EditorView(settings: prompter.settings, prompter: prompter))
            controller.sizingOptions = []
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 880, height: 600),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "Murmur"
            window.contentViewController = controller
            window.setContentSize(NSSize(width: 880, height: 600))
            window.contentMinSize = NSSize(width: 700, height: 460)
            window.isReleasedWhenClosed = false
            window.center()
            window.setFrameAutosaveName("MurmurEditor")
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct EditorView: View {
    @Bindable var settings: PrompterSettings
    let prompter: Prompter

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Script")
                    .font(.headline)
                TextEditor(text: $settings.script)
                    .font(.system(size: 14, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor)))
                Text("Put stage directions in [brackets]. They show dimmed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)

            Divider()

            Form {
                Section("Playback") {
                    HStack {
                        Button(prompter.isPlaying ? "Pause" : "Play") { prompter.togglePlay() }
                        Button("Back to Top") { prompter.restart() }
                    }
                    SliderRow(title: "Speed", value: $settings.speed, range: PrompterSettings.speedRange) {
                        "\(Int($0))"
                    }
                    Toggle("Pause while the pointer is over it", isOn: $settings.pauseOnHover)
                }

                Section {
                    SliderRow(title: "Scroll distance", value: $settings.scrollSensitivity,
                              range: PrompterSettings.scrollSensitivityRange) {
                        String(format: "%.1f×", $0)
                    }
                } header: {
                    Text("Mouse")
                } footer: {
                    Text("Scroll over the prompter to move the script. Hold Option while scrolling to change speed.")
                }

                Section("Voice") {
                    Toggle("Scroll only while I speak", isOn: $settings.voiceEnabled)
                    SliderRow(title: "Sensitivity", value: $settings.micSensitivity, range: 0...1) {
                        "\(Int($0 * 100))%"
                    }
                    .disabled(!settings.voiceEnabled)
                    if settings.voiceEnabled {
                        LabeledContent("Level") {
                            LevelMeter(prompter: prompter)
                                .frame(width: 150)
                        }
                    }
                }

                Section("Look") {
                    SliderRow(title: "Text size", value: $settings.fontSize, range: PrompterSettings.fontSizeRange) {
                        "\(Int($0))"
                    }
                    SliderRow(title: "Width", value: $settings.width, range: PrompterSettings.widthRange) {
                        "\(Int($0))"
                    }
                    SliderRow(title: "Height", value: $settings.height, range: PrompterSettings.heightRange) {
                        "\(Int($0))"
                    }
                }

                Section {
                    Toggle("Hide from screen sharing and recordings", isOn: $settings.hideFromCapture)
                } header: {
                    Text("Privacy")
                }
            }
            .formStyle(.grouped)
            .frame(width: 360)
        }
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                Slider(value: $value, in: range)
                    .labelsHidden()
                Text(format(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }
}

/// Live mic level with a tick at the speech threshold. Blue while the gate is open.
struct LevelMeter: View {
    let prompter: Prompter

    var body: some View {
        GeometryReader { geo in
            let threshold = VoiceGate.normalized(prompter.settings.thresholdDB)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule()
                    .fill(prompter.voiceGateOpen ? VoiceBeam.blue : Color.secondary)
                    .frame(width: geo.size.width * prompter.voiceLevel)
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: 2, height: 10)
                    .offset(x: geo.size.width * threshold - 1)
            }
            .frame(height: 6)
            .frame(maxHeight: .infinity)
        }
        .frame(height: 12)
    }
}
