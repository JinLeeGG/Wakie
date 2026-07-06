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

## How it works

<div align="center">
  <video src="https://github.com/user-attachments/assets/1e53bf83-62b1-465a-8b42-5d5fb23c60d8" width="100%" autoplay loop muted playsinline></video>
</div>

<br>

## Why I built this

> **TL;DR** — Wakie games Claude's 5-hour reset window for you automatically, and tracks how hard you're hammering every AI subscription you pay for. 100% local. No account, no server, no telemetry.

Claude Code has a usage limit. Not a daily one — a rolling 5-hour window. The clock starts on your first message and resets five hours later. Sounds harmless. It isn't, once you actually lean on the thing all day.

Here's the trap. Say I sit down to really grind at 10am. My first message anchors the window to 10:00, so it resets at 3pm — dead center of my afternoon. I hit the ceiling at 2:40, halfway through untangling something, and now I'm just... waiting. Watching a clock. My whole train of thought evaporating while I refresh a timer.

So I started cheating. I'd wake up and, before coffee, type `good morning` into the terminal. One throwaway message. That anchors the window early — to 7am instead of 10am — so it's already fresh by the time I'm actually working, and the resets land in the gaps instead of on top of me. Do it right and you can chain the windows so you're never the sucker waiting on the clock. The people who min-max this stuff on Reddit have fancier words for it. I just called it waking the session up.

Problem is, typing "good morning" to a robot at 6:45am every single day is exactly the kind of dumb manual ritual I learned to code to get away from. So I wrote a bot to do it. It wakes the Mac from sleep on a schedule, says hi, resets the window, goes back to sleep. That's where the name comes from. Wakie.

Then it kind of got away from me. I'm running Claude, Codex, and Antigravity at the same time — north of $200 a month across all of it — and I had no real idea how much of any of them I was actually burning. No dashboard. Just vibes, and the occasional "you've hit your limit" slap in the face at the worst possible moment. So I bolted usage tracking onto the wake bot. Then reset timers. Then a little menu-bar readout so I could stop guessing. And here we are.

That's the whole story. No roadmap deck, no mission statement, no "reimagining developer productivity." I was annoyed, I had a weekend, this exists now.

<br>

## Your data never leaves your Mac

I'll be straight with you: I wouldn't install this app if I hadn't written it.

Look at what it does. It reads your local AI logs — prompt counts, reset timestamps, which accounts you're signed into. That's *exactly* the kind of stuff a sketchy closed-source menu-bar app would quietly vacuum up and ship off to some analytics endpoint. If a random binary asked to do that, you'd say no. You should.

So here's the deal. Wakie has no backend. There is no server. No telemetry, no analytics, no "anonymous usage stats," nothing phoning home except the signed check for app updates. It reads files on your disk, does the math on your machine, and draws a number in your menu bar. That's the entire loop. Kill your network and the tracking keeps working exactly the same.

One honest exception, because I'd rather tell you than have you find it: the wake bot *does* fire a single throwaway prompt through your own CLI on schedule — waking the session is the whole point, and yeah, it nibbles a few tokens. That's the one network call Wakie ever *causes*, and it runs from your machine to your provider, on your account. Never to me. There's no "me" for it to reach.

And don't take my word for it — that's the whole reason it's open source under AGPL. Don't trust `grep` either; trust `lsof`. Point Little Snitch (or `nettop -p wakie`) at the app and watch it sit there with zero outbound connections of its own — the only traffic you'll ever see is the CLIs *you* already run. The code's right here if you'd rather read it. And if you ever catch this thing opening a socket it has no business opening, open an issue with my name on it.

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

Yes, I know, `curl | bash`. If that makes you twitch — good instinct. [Read the script first](deploy/install.sh); it's about 30 lines and all it does is pull the notarized DMG and drop the app into `/Applications`.

**The paranoid way:** grab the DMG from [Releases](https://github.com/JinLeeGG/Wakie/releases), open it, drag Wakie to Applications. It's signed and notarized, so no right-click-open dance.

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
