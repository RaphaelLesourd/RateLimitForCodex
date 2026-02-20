# Rate Limit Monitor 📊

![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
![Platform](https://img.shields.io/badge/Platform-macOS%20only-blue.svg)
![Deployment](https://img.shields.io/badge/macOS-14.0%2B-0A84FF.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

A lightweight macOS menu bar app that checks rate-limit usage at a glance.

## Important Legal/Brand Notes

- This app is **not affiliated with OpenAI**.
- This app does **not** use OpenAI logos.
- App naming is neutral (no Codex/GPT/model name in the app title).

Suggested store listing line:
- `Not affiliated with OpenAI. Uses the OpenAI API in official mode.`

## Data Modes

This app provides two modes:

1. `Official API (Recommended)`
- Uses OpenAI API key authentication.
- Calls `POST /v1/responses` and reads rate-limit headers.
- Best mode for publishing/compliance.

2. `Experimental Local`
- Reads local session files from `~/.codex/sessions`.
- Intended for advanced/internal workflows.
- Not an official OpenAI API integration path.

Default mode is `Official API`.

## What It Does

- Runs as a macOS menu bar app (`MenuBarExtra`).
- Stores API key in Keychain.
- Supports auto-refresh (`60s`, `120s`, `300s`) and manual refresh.
- Shows request/token remaining limits (official mode).
- Shows primary/secondary window usage (experimental mode).
- Includes an About & Support popup with version/build/contact.

## Agent-Built Project 🤖

This app is **100% built with Codex** and intentionally created with no manual coding.

Purpose of this project:
- Learn practical collaboration with coding agents.
- Demonstrate iterative agent workflow from prompt to shipped app.

## Run Locally

1. Open `/Users/birkyboy/Development/Codex rate limit/Codex rate limit.xcodeproj` in Xcode.
2. Select scheme `Codex rate limit`.
3. Build/run for macOS.
4. Choose data mode and provide API key for official mode.

## What Is Not Shared

This repo intentionally does not include:
- `AGENTS.md` (local/private instruction file)
- Internal planning artifacts from agent sessions

## License

MIT. See `/Users/birkyboy/Development/Codex rate limit/LICENSE`.
