import AppKit
import MurmurKit

let arguments = CommandLine.arguments

if let flag = arguments.firstIndex(of: "--snapshot"), flag + 1 < arguments.count {
    MainActor.assumeIsolated {
        do {
            try SnapshotRenderer.render(to: URL(fileURLWithPath: arguments[flag + 1]))
        } catch {
            FileHandle.standardError.write(Data("Snapshot failed: \(error)\n".utf8))
            exit(1)
        }
    }
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate(allowCapture: arguments.contains("--allow-capture"),
                               openEditorOnLaunch: arguments.contains("--open-editor"))
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
}
