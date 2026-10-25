import AVFoundation
import Accelerate

/// Reads the default microphone and reports its level in dBFS. Not main-actor bound:
/// the tap runs on the audio thread and hops to main itself.
final class MicLevelMonitor {
    enum Failure: Error { case noInput }

    var onLevel: ((Float, TimeInterval) -> Void)?
    private var engine: AVAudioEngine?

    func start() throws {
        stop()
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else { throw Failure.noInput }

        let sampleRate = format.sampleRate
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let samples = buffer.floatChannelData?[0] else { return }
            var rms: Float = 0
            vDSP_rmsqv(samples, 1, &rms, vDSP_Length(buffer.frameLength))
            let db = 20 * log10(max(rms, 0.000_01))
            let dt = Double(buffer.frameLength) / sampleRate
            DispatchQueue.main.async { self?.onLevel?(db, dt) }
        }
        try engine.start()
        self.engine = engine
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
    }
}

/// Connects the mic to the prompter: opens the gate while you speak and feeds the beam.
@MainActor
final class VoiceController {
    private let prompter: Prompter
    private let monitor = MicLevelMonitor()
    private var gate = VoiceGate()
    private var level: Double = 0
    private var running = false

    init(prompter: Prompter) {
        self.prompter = prompter
        monitor.onLevel = { [weak self] db, dt in
            MainActor.assumeIsolated { self?.handle(db: db, dt: dt) }
        }
    }

    func update(enabled: Bool) {
        enabled ? start() : stop()
    }

    private func start() {
        guard !running else { return }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            begin()
        case .notDetermined:
            Task { @MainActor in
                let granted = await AVCaptureDevice.requestAccess(for: .audio)
                guard self.prompter.settings.voiceEnabled else { return }
                granted ? self.begin() : self.refuse("Allow the microphone in System Settings")
            }
        default:
            refuse("Allow the microphone in System Settings")
        }
    }

    private func begin() {
        do {
            try monitor.start()
            running = true
            prompter.isPlaying = true
        } catch {
            refuse("No microphone found")
        }
    }

    private func refuse(_ message: String) {
        prompter.settings.voiceEnabled = false
        prompter.showToast(message)
    }

    private func stop() {
        monitor.stop()
        running = false
        gate.reset()
        level = 0
        prompter.voiceGateOpen = false
        prompter.voiceLevel = 0
    }

    private func handle(db: Float, dt: TimeInterval) {
        guard running else { return }
        gate.openThresholdDB = prompter.settings.thresholdDB
        let open = gate.update(levelDB: db, dt: dt)
        if prompter.voiceGateOpen != open { prompter.voiceGateOpen = open }

        let target = VoiceGate.normalized(db)
        level += (target - level) * (target > level ? 0.55 : 0.12)
        prompter.voiceLevel = level
    }
}
