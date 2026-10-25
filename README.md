# Murmur

A teleprompter that hangs from the MacBook notch, right next to the camera, in the style of
[Moody](https://moodyteleprompter.com). Personal project, written from scratch.

## Run it

No Xcode needed for the Mac app; the Command Line Tools are enough.

```bash
scripts/run.sh          # build build/Murmur.app and launch it
scripts/test.sh         # run the tests
swift scripts/make-icon.swift   # redraw Resources/AppIcon.icns
```

Launch flags, for development:

- `--allow-capture` keeps the prompter visible to screenshots and screen sharing
- `--open-editor` opens the script window on launch
- `--snapshot <folder>` renders the prompter's states to PNGs and quits

The app is ad-hoc signed, so macOS asks for microphone access again after each rebuild.

## Using it

- **Hover** over the prompter to pause it. Move away and it carries on from the same line.
- **Scroll** over it with a Magic Mouse, trackpad or wheel to go back or skip ahead.
- **Option + scroll** changes the speed.
- **Voice**: turn on *Scroll Only While I Speak* in the menu bar. The text moves while you talk,
  eases to a stop when you pause, and waits there. The blue beam shows your mic level.
- The menu bar icon has Play/Pause, Back to Top, Show/Hide and Edit Script.
- It is hidden from screen sharing and recordings by default (`NSWindow.sharingType = .none`).

On a MacBook with a notch it sits on the built-in screen, sized to the notch. On other screens
it draws a stand-in notch at the top centre.

## Layout

- `Sources/MurmurKit/Prompter.swift`: scroll position, playback, hover and scroll holds
- `Sources/MurmurKit/VoiceGate.swift`, `VoiceController.swift`: mic level, speech detection
- `Sources/MurmurKit/NotchPanel.swift`: the window, Magic Mouse handling, frame clock
- `Sources/MurmurKit/PrompterView.swift`, `NotchGeometry.swift`: the notch look
- `Sources/MurmurKit/EditorWindow.swift`, `AppDelegate.swift`: script window, menu bar
