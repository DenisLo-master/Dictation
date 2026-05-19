# Dictation Requirements Checklist

## Implemented

- Status-bar app without a Dock icon.
- Popover UI from the menu-bar icon.
- OpenAI API key entry with a secure field.
- Token validation request before saving to Keychain.
- Online transcription model loading through the OpenAI Models API.
- Model dropdown with transcription model filtering and badges.
- Push-to-talk hotkey recorder.
- Default `Fn / Globe` hotkey plus fallback keys: `Right Option`, `Right Control`, `Right Command`, and `F13-F20`.
- Local audio file written before upload.
- Temporary pending storage while the current transcription attempt is running.
- SHA-256, duration, byte size, and attempt count recorded for the current audio job.
- Chunk plan for audio above the upload size target with one-second overlap.
- Transcript merge that removes duplicated overlap words.
- One leading space added before transcript insertion.
- Paste insertion into the active app using temporary clipboard plus `Cmd+V`.
- Clipboard restoration after insertion.
- Bottom-right overlay, `150 x 50`, microphone left, square-cell equalizer right.
- Real microphone-level-driven equalizer during recording.
- Spinner while audio is being uploaded and transcribed.
- Menu item to open logs.
- Last 10 log lines stored locally.
- Launch-at-login toggle.
- Generated laptop and microphone `.icns` app icon.
- `.app` bundle build script.
- Idempotent `.pkg` installer that replaces duplicate `/Applications/Dictation*.app` copies.
- `.dmg` build script that packages the installer.
- Build staging that avoids leaving indexed app bundles in the repository.
- Single-instance runtime guard; launching the app twice activates the existing instance and exits the duplicate.
- Unit-style Swift test runner.
- Public repository docs, MIT license, privacy notes, security policy, contribution guide, and release artifacts in `dist/`.

## Manual Verification Required

- Real OpenAI token validation.
- Live microphone permission prompt.
- Accessibility permission prompt and paste behavior in target apps.
- Input Monitoring behavior on the target macOS version.
- Real `Fn / Globe` behavior with the user's keyboard settings.
- Launch-at-login behavior after installing into `/Applications`.
- Developer ID signing and notarization, if distributing outside local/testing use.

## Intentional Constraints

- Tests do not call OpenAI and do not require a network connection.
- Text of successful dictations is not written to logs.
- Failed recordings are deleted after the current processing attempt instead of being retried later.
- Distribution builds are currently ad-hoc signed and not notarized.
