import AppKit
import Observation

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = PrompterSettings()
    private lazy var prompter = Prompter(settings: settings)
    private let allowCapture: Bool
    private let openEditorOnLaunch: Bool

    private var prompterWindow: PrompterWindowController!
    private var editor: EditorWindowController!
    private var voice: VoiceController!
    private var statusItem: NSStatusItem!

    private let playItem = NSMenuItem(title: "Play", action: #selector(togglePlay), keyEquivalent: "p")
    private let voiceItem = NSMenuItem(title: "Scroll Only While I Speak", action: #selector(toggleVoice), keyEquivalent: "")
    private let hideCaptureItem = NSMenuItem(title: "Hide from Screen Sharing", action: #selector(toggleHideCapture), keyEquivalent: "")
    private let visibilityItem = NSMenuItem(title: "Hide Prompter", action: #selector(toggleVisibility), keyEquivalent: "h")

    /// `allowCapture` keeps the prompter visible to screenshots, for testing only.
    public init(allowCapture: Bool = false, openEditorOnLaunch: Bool = false) {
        self.allowCapture = allowCapture
        self.openEditorOnLaunch = openEditorOnLaunch
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        prompterWindow = PrompterWindowController(prompter: prompter, allowCapture: allowCapture)
        editor = EditorWindowController(prompter: prompter)
        voice = VoiceController(prompter: prompter)
        NSApp.mainMenu = Self.makeMainMenu()
        setUpStatusItem()

        track({ _ = (self.settings.width, self.settings.height) }) { self.prompterWindow.relayout() }
        track({ _ = self.settings.hideFromCapture }) { self.prompterWindow.applyCapturePolicy() }
        track({ _ = self.settings.voiceEnabled }) { self.voice.update(enabled: self.settings.voiceEnabled) }

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.prompterWindow.relayout() }
        }

        prompterWindow.show()
        voice.update(enabled: settings.voiceEnabled)

        if openEditorOnLaunch || !UserDefaults.standard.bool(forKey: "hasLaunched") {
            UserDefaults.standard.set(true, forKey: "hasLaunched")
            editor.show()
        }
    }

    /// Runs `onChange` every time something read inside `read` changes.
    private func track(_ read: @escaping () -> Void, onChange: @escaping () -> Void) {
        withObservationTracking(read) {
            Task { @MainActor [weak self] in
                onChange()
                self?.track(read, onChange: onChange)
            }
        }
    }

    // MARK: Menu bar

    /// A menu-bar-only app has no menu bar of its own, so ⌘V, ⌘C and friends do nothing
    /// in text fields unless these menus exist. They're never shown; they only route shortcuts.
    static func makeMainMenu() -> NSMenu {
        let appMenu = NSMenu(title: "Murmur")
        appMenu.addItem(withTitle: "Quit Murmur", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
            .keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")

        let mainMenu = NSMenu()
        for submenu in [appMenu, editMenu, windowMenu] {
            mainMenu.addItem(withTitle: submenu.title, action: nil, keyEquivalent: "").submenu = submenu
        }
        return mainMenu
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Murmur")
        image?.isTemplate = true
        statusItem.button?.image = image

        let menu = NSMenu()
        menu.delegate = self
        let restartItem = NSMenuItem(title: "Back to Top", action: #selector(restart), keyEquivalent: "r")
        let editItem = NSMenuItem(title: "Edit Script…", action: #selector(openEditor), keyEquivalent: ",")
        let quitItem = NSMenuItem(title: "Quit Murmur", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in [playItem, restartItem, voiceItem, hideCaptureItem, visibilityItem, editItem] {
            item.target = self
        }
        menu.items = [
            playItem, restartItem, .separator(),
            voiceItem, hideCaptureItem, .separator(),
            visibilityItem, editItem, .separator(),
            quitItem,
        ]
        statusItem.menu = menu
    }

    public func menuNeedsUpdate(_ menu: NSMenu) {
        playItem.title = prompter.isPlaying ? "Pause" : "Play"
        voiceItem.state = settings.voiceEnabled ? .on : .off
        hideCaptureItem.state = settings.hideFromCapture ? .on : .off
        visibilityItem.title = prompterWindow.isVisible ? "Hide Prompter" : "Show Prompter"
    }

    @objc private func togglePlay() { prompter.togglePlay() }
    @objc private func restart() { prompter.restart() }
    @objc private func toggleVoice() { settings.voiceEnabled.toggle() }
    @objc private func toggleHideCapture() { settings.hideFromCapture.toggle() }
    @objc private func openEditor() { editor.show() }

    @objc private func toggleVisibility() {
        prompterWindow.isVisible ? prompterWindow.hide() : prompterWindow.show()
    }
}
