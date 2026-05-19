# Dictation Requirements Checklist

## Implemented

- Status bar app without Dock icon (`LSUIElement`).
- Popover UI from the menu-bar icon.
- OpenAI API key entry with secure field.
- Token validation request before saving to Keychain.
- Online transcription model loading via OpenAI Models API.
- Model dropdown with transcription model filtering and badges.
- Push-to-talk hotkey recorder.
- Default `Fn / Globe` hotkey plus fallback keys: `Right Option`, `Right Control`, `Right Command`, `F13-F20`.
- Local audio file is written before upload.
- Pending audio queue in `~/Library/Application Support/Dictation/Pending`.
- Retry of preserved pending recordings while the app is running.
- SHA-256, duration, byte size, and retry count stored per recording.
- Chunk plan for audio above the OpenAI upload size target with one-second overlap.
- Transcript merge that removes duplicated overlap words.
- Paste insertion into the active field using temporary clipboard + `Cmd+V`.
- Clipboard restoration after insertion.
- Bottom-right overlay, `150 x 50`, microphone left, square-cell equalizer right.
- Menu item to open logs.
- Last 10 log lines stored at `~/Library/Logs/Dictation/Dictation.log`.
- Launch-at-login toggle.
- Generated laptop + microphone `.icns` app icon.
- `.app` bundle build script.
- Idempotent `.pkg` installer that replaces duplicate `/Applications/Dictation*.app` copies.
- `.dmg` build script that packages the installer.
- Single-instance runtime guard; launching the app twice activates the existing instance and exits the duplicate.
- Unit-style Swift test runner.

## Manual Verification Required

- Real OpenAI token validation.
- Live microphone permission prompt.
- Accessibility permission prompt and paste behavior in target apps.
- Input Monitoring behavior on the target macOS version.
- Real `Fn / Globe` behavior with the user's keyboard settings.
- Launch-at-login behavior after installing into `/Applications`.
- Developer ID signing and notarization, if distributing to other Macs.

## Intentional Constraints

- Tests do not call OpenAI and do not require a network connection.
- Text of successful dictations is not written to logs.
- Failed audio remains local until a later successful transcription.
