<div align="center">

<img width="1050" height="350" alt="Wakie" src="https://github.com/user-attachments/assets/3db2f5a5-e24b-4f9a-9a69-c61be22bddba" />

<br>
<br>

<h4>
  Local usage tracker for multiple AI subscriptions,<br>
  plus automation that optimizes your usage windows while you sleep.
</h4>

<br>

![macOS](https://img.shields.io/badge/macOS-1c2029?style=flat&logo=apple&logoColor=white)
&nbsp;[![License](https://img.shields.io/badge/AGPL--3.0-1c2029?style=flat&logo=gnu&logoColor=white)](LICENSE)
&nbsp;![open source](https://img.shields.io/badge/Open_source_-1c2029?style=flat)
&nbsp;![free](https://img.shields.io/badge/Free_-1c2029?style=flat)

<br>

[![Download for macOS](https://img.shields.io/badge/Download%20for%20macOS-FFC465?style=for-the-badge&logo=apple&logoColor=11131a)](https://github.com/JinLeeGG/Wakie/releases/latest)

<sub>signed &amp; notarized · no account · works offline</sub>

</div>

<br>


<div align="center">
  <video src="https://github.com/user-attachments/assets/6590d74c-603c-470f-ac9b-1dea7a5d4dec" width="100%" autoplay loop muted playsinline></video>
</div>





<br>

## Why I built this

Every AI coding subscription has the same trap: a rolling 5-hour usage window that starts on your first message. Sit down to grind at 10am, and the window anchors to 10:00 — so it resets at 3pm, dead center of your afternoon. You hit the ceiling at 2:40, halfway through something gnarly, and now you're just... waiting. Watching a clock while your train of thought evaporates.

So I started waking my sessions up early. Every morning, before coffee, I'd type `good morning` into the terminal — one throwaway message that anchors the window to 7am instead of 10, so the resets land in the gaps instead of on top of me. But typing "good morning" to a robot at 6:45am every single day is exactly the kind of dumb manual ritual I learned to code to get away from. So I wrote a bot to do it: wake the Mac, say hi, reset the window, go back to sleep. That's the name. Wakie.

And like half the people reading this, I don't run one account. Some folks stack five free ones; I run two Claude Pro and a Codex Plus — the poor man's Max plan. Same problem either way: juggling logins all day just to figure out which account has juice left. So I bolted usage tracking onto the wake bot — every account, every window, every reset timer, one glance at the menu bar. No more juggling.

I was annoyed, and this exists now.

<br>

## 🔒 Your data never leaves your Mac

Wakie is designed with absolute privacy in mind. It needs to read your local AI logs to function, but it never sends that data anywhere. 

- **100% Local:** There is no backend, no telemetry, and no "anonymous usage stats." It reads your logs locally and calculates usage right on your machine.
- **Network-Free Tracking:** You can completely kill your network, and the usage tracking will continue to work flawlessly. (The only network call Wakie makes is firing the scheduled prompt through your own CLI to your AI provider, using your own account.)
- **Verifiably Open:** Wakie is open-source under AGPL. You can review the code yourself or use tools like Little Snitch to verify that it makes zero outbound connections to us. There is no "us" for it to reach.

<br>

## Supported AI tools

| Tool | Where Wakie reads it | Status |
|------|----------------------|--------|
| **Claude Code** | local `/usage` panel + session logs | ✅ working |
| **Codex** | `codex app-server` JSON-RPC (structured, no scraping) | ✅ working |
| **Antigravity** | native pty scrape of the TUI (no structured surface exists yet) | ✅ working |

Each one is a self-contained adapter in [`packages/core/lib/src/adapters`](packages/core/lib/src/adapters). If you use a tool that isn't here, that folder is where you'd add it — copy the closest one and go. Not as scary as it looks.

<br>

## Tech stack

- **Flutter + Dart** — the app and the whole tracking engine (`packages/core`)
- **Swift** — the native macOS bits: menu-bar tray, window handling, and the scheduled wake-from-sleep
- **Sparkle** — signed auto-updates, so you're not re-downloading DMGs forever
- **Next.js 16 · React 19 · Tailwind v4 · TypeScript** — the landing site in `apps/web`
- Shipped as a **Developer ID–signed, Apple-notarized** DMG, so Gatekeeper doesn't fight you

<br>

## Getting started

**The fast way (curl):**

```bash
curl -fsSL https://raw.githubusercontent.com/JinLeeGG/Wakie/main/deploy/install.sh | bash
```

**Homebrew:**

```bash
brew install --cask jinleegg/wakie/wakie
```

**From source:**

```bash
git clone https://github.com/JinLeeGG/Wakie.git
cd Wakie/apps/mac
flutter pub get
flutter run -d macos
```

You'll need Flutter (Dart SDK 3.12+) and Xcode. macOS only, for now.

<br>

## Contributing

PRs welcome, genuinely.

**Want Wakie to track your AI tool?** An adapter is three things:

1. Implement the `ProviderAdapter` interface.
2. Add a `Provider` enum value.
3. Register it in [`packages/core/lib/src/production_adapters.dart`](packages/core/lib/src/production_adapters.dart).

That's the whole contract. Every provider ships a `*_adapter_test.dart` + `*_usage_parser_test.dart` pair — copy that pair, drop in a real capture from your tool, and TDD against it with `cd packages/core && flutter test`. No Xcode, no app build, no Mac-app knowledge needed.

Other stuff I'd love a hand with:

- **Bug reports with real repro steps.** "It's broken" makes me sad. "Here's exactly what I did" makes me fix it.
- **The Windows/Linux port** I keep meaning to start and never do.

No CLA. No bot gauntlet. No 12-field issue template. Open an issue, send a PR, we'll sort it out like humans.

<br>

---

<div align="center">

**License:** [AGPL-3.0](LICENSE) — fork it, build on it, just keep it open.
Copyright © 2026 Gyujin Lee.

Made because typing "good morning" to a robot at 6am got old.

</div>
