<div align="center">

# Reword ✨

**Select text. Hit a shortcut. Watch your AI rewrite it — right where it was.**

*No clipboard hassle. No app switching. No context lost.*

[![CI](https://github.com/alphonse-terrier/reword/actions/workflows/ci.yml/badge.svg)](https://github.com/alphonse-terrier/reword/actions/workflows/ci.yml)
[![Download](https://img.shields.io/badge/download-latest%20release-blue)](https://github.com/alphonse-terrier/reword/releases/latest)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey?logo=apple)](#getting-started)
[![Swift](https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white)](https://swift.org)

[**Download**](https://github.com/alphonse-terrier/reword/releases/latest) · [Features](#-why-youll-like-it) · [Getting started](#-getting-started) · [Providers](#-bring-your-own-ai) · [Build from source](#-building-it-yourself)

</div>

---

Ever written something a little too fast — typos, awkward phrasing, a tone that's not quite
right — and wished you could just *fix it* without breaking your flow? That's Reword.

It sits quietly in your Mac's menu bar. Select any text, anywhere — an email, a Slack message, a
comment in your code editor, a form on a website — press a shortcut, and it's rewritten **in
place**. Your own text assistant, and you're fully in control of which AI powers it.

```mermaid
flowchart LR
    A["✍️ Select text<br/>in any app"] --> B["⌨️ Press your<br/>shortcut"]
    B --> C["🧠 Your AI<br/>rewrites it"]
    C --> D["✅ Replaced<br/>in place"]

    style A fill:#4C6EF5,color:#fff,stroke:none
    style B fill:#7048E8,color:#fff,stroke:none
    style C fill:#AE3EC9,color:#fff,stroke:none
    style D fill:#37B24D,color:#fff,stroke:none
```

## 💡 Why you'll like it

| | |
|---|---|
| 🌍 **Works everywhere** | Native Mac apps, Electron apps, browsers — if you can select text, Reword can rewrite it. |
| 🔑 **Bring your own AI** | OpenAI, Anthropic, Ollama, your local Claude CLI login, or *any* other LLM CLI. |
| 🎛️ **You define "reword"** | Fix spelling, sound more professional, shorten a wall of text, translate — built-in presets, or write your own. |
| 📋 **Barely touches your clipboard** | Reads/writes your selection directly via macOS Accessibility — no clipboard involved in most apps. |
| 🔒 **Your keys stay yours** | Stored in the macOS Keychain, never on disk in plain text, one slot per provider. |
| 🌐 **Speaks your language** | English by default, French included — follows your Mac's per-app language setting. |
| 👀 **Never leaves you guessing** | A small overlay near your cursor shows progress and success/failure, live. |

## 🚀 Getting started

1. **Grab the app.** Download the latest DMG from
   [**Releases**](https://github.com/alphonse-terrier/reword/releases/latest), or build it from
   [source](#-building-it-yourself).
2. **Open it once.** Not notarized by Apple yet, so macOS will refuse to open it the first time —
   right-click the app → **Open** to tell macOS you trust it. Only needed once.
3. **Say yes to Accessibility.** Reword asks for this on first launch — it needs it to read your
   selection and write the result back. Grant it any time in **System Settings → Privacy &
   Security → Accessibility**.
4. **Pick your AI.** Menu bar icon → **Settings…** → **Provider**, choose one, hit
   **Test Connection**.
5. **Try it.** Select some text anywhere, press your shortcut (⌘⌥← by default, fully changeable),
   and watch it get rewritten.

No accounts to create with Reword itself, no onboarding wizard. Just you, your AI, and your text.

## 🧠 What it can do

- **A global shortcut** to rewrite text using whichever preset is active, plus an optional
  dedicated shortcut per preset.
- **Presets you can shape to your liking** — *Fix Spelling*, *Rephrase Professionally*,
  *Shorten*, *Translate to English* come built in; edit, remove, or add your own.
- **A language instruction** (Settings → General) so the AI keeps replies in whatever language
  you wrote in, unless you're specifically asking it to translate.
- **Rephrase Now / Cancel** in the menu — trigger a rewrite without memorizing the shortcut, or
  stop one that's taking too long (there's also a 45-second automatic timeout).

## 🔌 Bring your own AI

Open **Settings** → **Provider** tab:

| Provider | What you'll need | Good to know |
|---|---|---|
| 🌐 OpenAI-compatible API | Base URL, API key, model name | OpenAI, LM Studio, vLLM, OpenRouter, and more |
| 🟣 Anthropic (Claude) | API key, model (pick from a list) | Talks straight to Anthropic, no middleman |
| 🦙 Ollama | Just the host address | No API key — great for running models locally |
| ⌨️ Claude CLI (`claude -p`) | Claude Code installed and logged in | Reuses your existing login, no API key |
| 🛠️ Custom Command | A command + arguments (`{system}`/`{model}` placeholders, text on stdin) | Drives *any* local LLM CLI — Gemini CLI, `llm`, your own script |

Whichever you pick, hit **Test Connection** — it sends a tiny test message so you know it's wired
up correctly before you rely on it.

> 💡 **Tip:** for Ollama, `gemma4:e2b` is a great default — it's light and works really well for
> quick rewrites.

## 🛠 Building it yourself

You'll need Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen   # skip if you already have it
xcodegen generate
open Reword.xcodeproj
```

Then hit **Run** in Xcode. Prefer the terminal?

```sh
xcodegen generate
xcodebuild -project Reword.xcodeproj -scheme Reword -configuration Release build
```

Requires macOS 14 (Sonoma) or later. For the Claude CLI provider, you'll also need the `claude`
CLI installed and logged in.

To build a distributable `.app` + `.dmg` in one step:

```sh
scripts/build-dmg.sh
```

<details>
<summary><strong>Keeping macOS permissions across rebuilds</strong></summary>

Without a paid Developer ID, local builds are signed ad-hoc by default — and ad-hoc signatures
are derived from the binary's own hash, so **every rebuild looks like a different app to macOS**,
silently revoking the Accessibility permission each time. If you're iterating on the source and
don't want to re-grant Accessibility after every build, create a stable local signing identity
once:

```sh
scripts/create-local-signing-identity.sh
```

`scripts/build-dmg.sh` automatically detects and uses it afterwards. It's a self-signed
certificate stored in your login keychain — nothing is uploaded anywhere, and it doesn't need to
be trusted by anyone else's Mac, only consistent on yours.

</details>

<details>
<summary><strong>Running the tests</strong></summary>

```sh
xcodegen generate
xcodebuild -project Reword.xcodeproj -scheme Reword -destination "platform=macOS" test
```

</details>

<details>
<summary><strong>Cutting a release</strong></summary>

Bump `MARKETING_VERSION`/`CFBundleShortVersionString` in `project.yml` if needed, then push a
matching tag:

```sh
git tag v0.1.0
git push origin v0.1.0
```

`.github/workflows/release.yml` builds the DMG and publishes it to
[Releases](https://github.com/alphonse-terrier/reword/releases) automatically.

</details>

## 🔍 Under the hood

A few things worth knowing if you're reading the code or hitting an edge case:

- **Text access**: Reword tries the Accessibility API first (no clipboard involved), and only
  falls back to synthesized ⌘C/⌘V for apps that don't support it. The pasteboard fallback checks
  that the frontmost app hasn't changed mid-request before pasting, so switching away while the
  AI is thinking can't send your rewritten text to the wrong window.
- **One request at a time**: triggering the shortcut while a reformulation is already running is
  ignored rather than queued or interleaved, so two requests can never race over the same
  selection. Every request has a 45-second timeout and can be cancelled from the menu.
- **Custom Command safety**: external processes run with concurrent stdout/stderr draining (no
  deadlock on large output), a hard timeout, and cancellation support — a stuck or misbehaving
  CLI can't hang the app.

## 📄 License

No license file yet — all rights reserved by default until one is added.

---

<div align="center">

If Reword saves you a re-type or two, consider ⭐️ starring the repo.

</div>
