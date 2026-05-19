# Contributing

Thanks for helping improve Dictation.

## Good First Contributions

- Bug reports with clear reproduction steps.
- Fixes for macOS permission edge cases.
- Improvements to installation and release packaging.
- Focused UI polish for the status-bar popover or recording overlay.
- Tests for hotkeys, transcription text handling, logging, or packaging behavior.

## Development Setup

Requirements:

- macOS 14 or newer.
- Xcode Command Line Tools.
- Swift 6 toolchain.

Run the tests:

```sh
swift run DictationTestsRunner
```

Build a local installer:

```sh
Scripts/build-dmg.sh
```

The installer artifacts are written to `build/`.

## Pull Request Checklist

Before opening a pull request:

- Run `swift run DictationTestsRunner`.
- Do not commit real API keys, logs containing secrets, or local permission screenshots.
- Keep changes focused.
- Update `README.md`, `PRIVACY.md`, or `REQUIREMENTS.md` when behavior changes.
- Mention any manual macOS permission testing you performed.

## Coding Notes

- Keep the app native to macOS and lightweight.
- Prefer AppKit and standard macOS APIs over adding dependencies.
- Do not log recognized transcript text.
- Preserve clipboard contents after paste insertion.
- Keep distribution build artifacts out of Launchpad and Spotlight indexing.
