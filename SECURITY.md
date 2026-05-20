# Security Policy

## Reporting a Vulnerability

Please do not open a public GitHub issue for security problems, token-handling bugs, or vulnerabilities that could expose private audio or API keys.

Report security issues by email:

`flo.production.studio@gmail.com`

Include:

- A short description of the issue.
- Steps to reproduce.
- The macOS version.
- The Dictation version.
- Any relevant logs with secrets removed.

## Secret Handling

Never include a real OpenAI API key in issues, pull requests, logs, screenshots, or test fixtures.

The app stores the OpenAI API key in the user's macOS Keychain. The key is used only for OpenAI API requests from the local app.

## Supported Versions

This project is currently pre-1.0. Security fixes are expected to land on the `main` branch and in the latest build under `dist/`.
