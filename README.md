
# Rate Limit Monitor 📊

![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
![Platform](https://img.shields.io/badge/Platform-macOS%20only-blue.svg)
![Deployment](https://img.shields.io/badge/macOS-14.0%2B-0A84FF.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

![Screenshot 2026-02-20 at 15 10 29](https://github.com/user-attachments/assets/ea38370c-cdf4-4155-abf5-c10ea682f772)


A lightweight macOS menu bar app that checks rate-limit usage at a glance.

## Download

<img width="128" height="128" alt="icon-iOS-Default-256x256@1x" src="https://github.com/user-attachments/assets/7cea829e-88a3-48ac-ab49-855556c3b63c" />

[Download app here (macOS ZIP)](https://github.com/RaphaelLesourd/RateLimitForCodex/releases/latest/download/Rate%20Limit%20Monitor-macOS.zip)  
If the direct asset URL changes, download from [Releases](https://github.com/RaphaelLesourd/RateLimitForCodex/releases).

The app runs immediately after download, but data modes require setup:
- API Key mode: add your own OpenAI API key (if you have one)
OR
- Codex Session mode: works if you have used Codex on this machine and local session files exist at `~/.codex/sessions` (for example after running Codex in terminal/app).

Gatekeeper note:
- If macOS blocks the app on first launch, open **System Settings > Privacy & Security**, then allow/open it once from there.

## Important Legal/Brand Notes

- This app is **not affiliated with OpenAI**.
- This app does **not** use OpenAI logos.
- App naming is neutral (no Codex/GPT/model name in the app title).

Suggested store listing line:
- `Not affiliated with OpenAI. Uses the OpenAI API in API Key mode.`

## Data Modes

This app provides two modes:

1. `API Key (Recommended)`
- Uses OpenAI API key authentication.
- Calls `POST /v1/responses` and reads rate-limit headers.
- Best mode for publishing/compliance.

2. `Codex Session`
- Reads local session files from `~/.codex/sessions`.
- Intended for advanced/internal workflows.
- Not an official OpenAI API integration path.

Default mode is `API Key`.

## What It Does

- Runs as a macOS menu bar app (`MenuBarExtra`).
- Stores API key in Keychain.
- Supports auto-refresh (`60s`, `120s`, `300s`) and manual refresh.
- Shows request/token remaining limits (API Key mode).
- Shows primary/secondary window usage (Codex Session mode).
- Includes an About & Support popup with version/build/contact.

## Agent-Built Project 🤖

This app is **100% built with Codex** and intentionally created with no manual coding.

Purpose of this project:
- Learn practical collaboration with coding agents.
- Demonstrate iterative agent workflow from prompt to shipped app.

## Run Locally

1. Open `Codex rate limit.xcodeproj` in Xcode.
2. Select scheme `Codex rate limit`.
3. Build/run for macOS.
4. Choose data mode and provide API key for API Key mode.

## What Is Not Shared

This repo intentionally does not include:
- `AGENTS.md` (local/private instruction file)
- Internal planning artifacts from agent sessions

## License

MIT. See `/Users/birkyboy/Development/Codex rate limit/LICENSE`.
