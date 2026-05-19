# Privacy

Dictation is designed as a local macOS utility. It does not run a backend owned by this project, but it does send audio to OpenAI when you ask it to transcribe speech.

## What Leaves Your Mac

When you hold the dictation hotkey, Dictation records audio locally. When you release the hotkey, that audio file is uploaded to OpenAI's transcription API using the API key you configured.

The app also calls OpenAI's Models API to load the list of transcription-capable models for your account.

## What Stays Local

- Your OpenAI API key is stored in the macOS Keychain.
- Hotkey and selected model settings are stored in user defaults.
- Temporary audio files are stored under the app's Application Support directory while the current transcription attempt is running.
- Temporary audio and metadata are deleted after successful insertion or after a failed current attempt.
- Logs are stored locally and keep only the last 10 entries.

## What Is Not Logged

Dictation does not write recognized transcript text to logs. Logs may include operational metadata such as duration, file size, request attempts, target app names, and error messages.

## Clipboard Behavior

Dictation inserts text by temporarily writing the transcript to the macOS clipboard and sending `Cmd+V`. It then restores the previous clipboard contents after a short delay.

## Permissions

Dictation asks macOS for:

- Microphone access, to record while the hotkey is held.
- Accessibility access, to paste recognized text into the active app.
- Input Monitoring access may be required by macOS for some global hotkey setups.

## Third-Party Services

OpenAI receives the audio submitted for transcription and handles it according to the OpenAI API terms and policies that apply to your account.
