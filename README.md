# Dictation

Native macOS menu-bar dictation utility.

## What It Does

- Runs near the clock as a status bar app without a Dock icon.
- Stores the OpenAI API key in Keychain.
- Validates the token with OpenAI and loads transcription-capable models online from `GET /v1/models`.
- Lets you choose the push-to-talk key with a hotkey recorder.
- Records while the selected key is held, then transcribes and pastes into the active field.
- Shows a bottom-right `150 x 50` overlay with a microphone on the left and square-cell equalizer columns on the right.
- Preserves audio locally before upload so failed network requests can be retried.
- Keeps the last 10 log entries at `~/Library/Logs/Dictation/Dictation.log`.
- Builds as a drag-to-Applications `.dmg`.

## Build

```sh
chmod +x Scripts/build-app.sh Scripts/build-dmg.sh
Scripts/build-app.sh
open build/Dictation.app
```

To build the installer image:

```sh
Scripts/build-dmg.sh
open build/Dictation.dmg
```

The DMG contains `Install Dictation.pkg`. The package installer is idempotent: it quits a running Dictation instance, removes previous `Dictation.app` duplicates in `/Applications`, installs one fresh `/Applications/Dictation.app`, and launches it.

## Test

This repository uses a lightweight Swift test runner so tests work with the installed Command Line Tools environment:

```sh
swift run DictationTestsRunner
```

The runner covers hotkey capture, model filtering, transcript merging, chunk planning, reliable audio queue persistence, and log rotation.

## Install

Open `build/Dictation.dmg`, then drag `Dictation.app` into `Applications`.

The first run may need these macOS permissions:

- Microphone, for recording.
- Accessibility, for pasting recognized text into the active app.
- Input Monitoring may be needed for global key monitoring on some macOS configurations.

## Notes

The `Fn` / Globe key can be claimed by macOS keyboard settings. If it does not trigger recording, use the in-app hotkey recorder and choose `Right Option`, `Right Control`, `Right Command`, or `F13-F20`.

This build is ad-hoc signed for local use. Distribution to other Macs without warnings requires Developer ID signing and notarization.
