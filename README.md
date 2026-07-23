# Reword 👋

Ever written something a little too fast — typos, awkward phrasing, or a tone that's not quite
right — and wished you could just fix it without breaking your flow? That's what Reword is for.

Reword sits quietly in your Mac's menu bar. Select any text, anywhere — an email, a Slack
message, a comment in your code editor, a form on a website — press a shortcut, and it's rewritten
in place. No copy-pasting into a chat window, no switching apps, no losing your train of thought.

It's your own text assistant, and you're fully in control of which AI powers it.

## Why you might like it

- **It just works, everywhere.** Native Mac apps, Electron apps, browsers — if you can select text
  and copy it, Reword can rewrite it.
- **You choose the AI.** Bring your own OpenAI, Anthropic, or Ollama key, or plug in your local
  Claude CLI login — whatever you already use or trust.
- **You choose what "reword" means.** Fix spelling, sound more professional, shorten a wall of
  text, translate it — pick from the built-in presets or write your own.
- **Nothing leaves your clipboard history.** Reword puts the copied text through the AI and
  restores your clipboard right after, so it's like it was never touched.
- **Your keys stay yours.** API keys live in the macOS Keychain, never written to disk in plain
  text.
- **Speaks your language.** English by default, with French included — it follows your Mac's
  per-app language setting.

## Getting started

1. **Grab the app.** Build it from source (see below) — there's no packaged download yet.
2. **Open it once.** Since it isn't notarized by Apple yet, macOS will politely refuse to open it
   the first time. Right-click the app → **Open** to tell macOS you trust it. You'll only need to
   do this once.
3. **Say yes to Accessibility.** Reword asks for the Accessibility permission on first launch —
   it needs this to read your selected text and paste the result back. You can also grant it any
   time in **System Settings → Privacy & Security → Accessibility**.
4. **Pick your AI.** Click the menu bar icon → **Settings…** → **Provider**, choose one, and hit
   **Test Connection** to make sure it's talking to your AI correctly.
5. **Try it out.** Select some text anywhere, press your shortcut (⌘⌥← by default, and fully
   changeable in Settings), and watch it get rewritten.

That's it — no accounts to create with Reword itself, no onboarding wizard. Just you, your AI, and
your text.

## What it can do

- **A global shortcut** to rewrite text using whichever preset is active, plus an optional
  dedicated shortcut for each individual preset.
- **Presets you can shape to your liking** — "Fix Spelling," "Rephrase Professionally,"
  "Shorten," "Translate to English" come built in, and you can edit, remove, or add your own with
  whatever instructions you want.
- **Any of these AI providers**, switchable any time in Settings:
  - Any OpenAI-compatible API — OpenAI itself, LM Studio, vLLM, OpenRouter, and more
  - Anthropic's API directly, with a simple model picker (Opus, Sonnet, Haiku)
  - Ollama, if you'd rather run models locally
  - Your local **Claude CLI** login (`claude -p`) — no separate API key needed if you already use
    Claude Code
- **A language instruction** you can tweak in Settings → General, so the AI keeps replies in
  whatever language you wrote in, unless you're specifically asking it to translate.

## Configuring your AI provider

Open **Settings** from the menu bar icon → **Provider** tab:

| Provider | What you'll need | Good to know |
|---|---|---|
| OpenAI-compatible API | Base URL, API key, model name | Works with pretty much anything speaking the OpenAI chat format |
| Anthropic (Claude) | API key, model (pick from a list) | Talks straight to Anthropic, no middleman |
| Ollama | Just the host address | No API key — great for running models locally |
| Claude CLI (`claude -p`) | Nothing but Claude Code installed and logged in | Reuses your existing login |

Whichever you pick, hit **Test Connection** afterwards — it sends a tiny test message so you know
everything's wired up correctly before you rely on it.

## Building it yourself

You'll need Xcode 15 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen   # skip if you already have it
xcodegen generate
open Reword.xcodeproj
```

Then just hit **Run** in Xcode. Prefer the terminal?

```sh
xcodegen generate
xcodebuild -project Reword.xcodeproj -scheme Reword -configuration Release build
```

Requires macOS 14 (Sonoma) or later. If you want to use the Claude CLI provider, you'll also need
the `claude` CLI installed and logged in.

## License

No license file yet — all rights reserved by default until one is added.
