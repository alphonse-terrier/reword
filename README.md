# Reword

A tiny macOS menu bar app that rephrases whatever text you have selected, anywhere on your Mac —
native apps, Electron, browsers — using the LLM provider of your choice.

Select some text, press a global shortcut, and it's replaced in place with the rephrased version.

## How it works

1. You select text in any app and press a global shortcut.
2. Reword copies the selection (via a synthetic ⌘C), sends it to your configured LLM with the
   active preset's instructions, and pastes the result back (via a synthetic ⌘V).
3. Your clipboard is restored to what it was before, so your copy history isn't polluted.

Reword lives entirely in the menu bar — no dock icon, no windows except Settings.

## Features

- **Global shortcut** to rephrase with the active preset, plus an optional dedicated shortcut per
  preset.
- **Presets** — editable system prompts (e.g. "Fix Spelling", "Rephrase Professionally",
  "Shorten", "Translate to English"). Add, remove, and reorder your own.
- **Multiple providers**, switchable in Settings:
  - Any OpenAI-compatible API (OpenAI, LM Studio, vLLM, OpenRouter, …)
  - Anthropic's native API, with a model picker (Opus 4.8 / Sonnet 5 / Haiku 4.5)
  - Ollama's native API
  - **Claude CLI** (`claude -p`) — reuses your existing local Claude Code login instead of a
    separate API key
- **Language instruction** — a global pre-prompt (editable in Settings → General) that tells the
  model to keep the reply in the input's original language unless a preset explicitly asks for a
  translation.
- **Localized** — English by default, French included (follows your per-app macOS language
  setting).
- API keys are stored in the macOS Keychain, never on disk in plain text.

## Requirements

- macOS 14 (Sonoma) or later
- To build: Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- To use the Claude CLI provider: the `claude` CLI installed and logged in

## Building from source

```sh
brew install xcodegen   # if you don't have it
xcodegen generate
open Reword.xcodeproj
```

Or build from the command line:

```sh
xcodegen generate
xcodebuild -project Reword.xcodeproj -scheme Reword -configuration Release build
```

The app isn't signed with a Developer ID, so on first launch macOS will refuse to open it —
right-click the app → **Open** once to bypass Gatekeeper.

## First launch

Reword needs the **Accessibility** permission to send the synthetic ⌘C/⌘V that capture and
replace your selection. It will prompt for this on first launch; you can also grant it manually
in **System Settings → Privacy & Security → Accessibility**.

## Configuring a provider

Open Settings (from the menu bar icon, or the global shortcut's Settings entry) → **Provider**:

| Provider | Needs | Notes |
|---|---|---|
| OpenAI-compatible API | Base URL, API key, model | Works with any `/chat/completions`-shaped endpoint |
| Anthropic (Claude) | API key, model (picker) | Talks directly to `api.anthropic.com` |
| Ollama (native) | Host, model | No API key needed |
| Claude CLI (`claude -p`) | Model (optional) | No API key — uses your local `claude` login |

Use **Test Connection** to verify before relying on it.

## License

No license file yet — all rights reserved by default until one is added.
