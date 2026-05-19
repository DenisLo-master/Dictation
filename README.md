# Dictation

Native macOS push-to-talk dictation for OpenAI transcription.

<img src="Resources/AppIconSource.png" alt="Dictation app icon" width="160">

Dictation runs in the macOS status bar. Hold the configured hotkey, speak, release it, and the recognized text is pasted into the app that currently has focus. It is built for people who want a small local utility rather than a full writing app.

## Features

- Status-bar app with no Dock icon.
- Push-to-talk recording with `Fn / Globe` by default.
- Hotkey recorder for `Fn / Globe`, right-side modifier keys, and `F13-F20`.
- Online OpenAI model list loaded from the Models API.
- Transcription through OpenAI's audio transcription endpoint.
- Secure OpenAI API key field with validation before saving.
- macOS Keychain storage for the API key.
- Bottom-right microphone badge with a real voice-reactive square-cell equalizer.
- Processing spinner while audio is being uploaded and transcribed.
- Temporary clipboard paste with clipboard restoration after insertion.
- Launch-at-login toggle.
- Last 10 log lines available from the menu-bar popover.
- Idempotent package installer that replaces duplicate `/Applications/Dictation*.app` copies.

## Download

The repository includes current builds in `dist/`:

- `dist/Dictation.dmg`
- `dist/Dictation.pkg`

For most users, download `Dictation.dmg`, open it, and run `Install Dictation.pkg`.

The app is currently ad-hoc signed and not notarized with an Apple Developer ID. macOS may show a warning on first launch. For broad distribution, sign and notarize your own build.

## Requirements

- macOS 14 or newer.
- An OpenAI API key with access to transcription-capable models.
- Microphone permission.
- Accessibility permission, required so the app can paste text into the active app.
- Input Monitoring permission may be required on some macOS keyboard configurations for global hotkey capture.

OpenAI API references:

- [Speech to text](https://platform.openai.com/docs/guides/speech-to-text)
- [Audio transcriptions API](https://platform.openai.com/docs/api-reference/audio/createTranscription)
- [Models API](https://platform.openai.com/docs/api-reference/models/list)

## Install

1. Download `dist/Dictation.dmg`.
2. Open the DMG.
3. Run `Install Dictation.pkg`.
4. Open Dictation from the status bar near the clock.
5. Paste your OpenAI API key and press `Save`.
6. Grant Microphone and Accessibility permissions when macOS asks.
7. Hold the configured hotkey, speak, and release to paste the transcript.

If `Fn / Globe` does not start recording, macOS keyboard settings may be using that key for system features. Open the Dictation menu and assign another hotkey.

## Privacy

Dictation is local-first, but it is not offline.

- Audio is recorded locally only while the hotkey is held.
- Audio is sent to OpenAI for transcription after the hotkey is released.
- Successful and failed recordings are deleted after the current processing attempt.
- Transcribed text is pasted through the system clipboard and the previous clipboard contents are restored shortly after.
- Transcribed text is not written to logs.
- The OpenAI API key is stored in the user's macOS Keychain.
- Logs keep only the last 10 entries and are intended for debugging status and errors.

See [PRIVACY.md](PRIVACY.md) for the full privacy notes.

## Build From Source

Install Xcode Command Line Tools, then run:

```sh
swift run DictationTestsRunner
Scripts/build-dmg.sh
```

The build output is written to `build/`:

- `build/Dictation.pkg`
- `build/Dictation.dmg`

The package build uses temporary staging directories so build-only app bundles are not indexed by Launchpad or Spotlight.

## Test

```sh
swift run DictationTestsRunner
```

The test runner covers hotkey capture, OpenAI model filtering, transcript merging, chunk planning, equalizer behavior, queue cleanup, log rotation, single-instance policy, and app metadata.

## Project Status

Dictation is a small macOS utility and is ready for local use. It is not notarized, sandboxed, or App Store distributed.

Known distribution work:

- Developer ID signing.
- Apple notarization.
- A GitHub Release workflow.
- Optional Homebrew cask.

## Contributing

Bug reports, small fixes, and focused improvements are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

Please do not open public issues for vulnerabilities or token-handling problems. See [SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).
