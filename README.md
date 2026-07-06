<div align="center">

<img src="docs/design/app-icon.svg" width="96" height="96" alt="Wakie">

# Wakie

**Local usage tracking for people who pay for too many AI subscriptions.**
Plus a bot that games the 5-hour reset window while you sleep.

<br>

🇺🇸 English &nbsp;·&nbsp; [🇰🇷 한국어](README.ko.md)

<br>

[![Website](https://img.shields.io/badge/website-wakie-0B1120?style=flat-square)](https://your-website.com)
[![License](https://img.shields.io/badge/license-AGPL--3.0-5FD39A?style=flat-square)](LICENSE)
![Platform](https://img.shields.io/badge/macOS-0B1120?style=flat-square&logo=apple&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-0B1120?style=flat-square&logo=flutter&logoColor=white)
![Price](https://img.shields.io/badge/price-%240%2C%20forever-5FD39A?style=flat-square)

</div>

<br>

## 🎥 Demo

<!-- Video Demo Placeholder -->

<div align="center">
<em>(demo video going here once I stop being embarrassed by my own narration)</em>
</div>

<br>

## 📖 Why I built this

Claude Code has a usage limit. Not a daily one — a rolling 5-hour window. The clock starts on your first message and resets five hours later. Sounds harmless. It isn't, once you actually lean on the thing all day.

Here's the trap. Say I sit down to really grind at 10am. My first message anchors the window to 10:00, so it resets at 3pm — dead center of my afternoon. I hit the ceiling at 2:40, halfway through untangling something, and now I'm just... waiting. Watching a clock. My whole train of thought evaporating while I refresh a timer.

So I started cheating. I'd wake up and, before coffee, type `good morning` into the terminal. One throwaway message. That anchors the window early — to 7am instead of 10am — so it's already fresh by the time I'm actually working, and the resets land in the gaps instead of on top of me. Do it right and you can chain the windows so you're never the sucker waiting on the clock. The people who min-max this stuff on Reddit have fancier words for it. I just called it waking the session up.

Problem is, typing "good morning" to a robot at 6:45am every single day is exactly the kind of dumb manual ritual I learned to code to get away from. So I wrote a bot to do it. It wakes the Mac from sleep on a schedule, says hi, resets the window, goes back to sleep. That's where the name comes from. Wakie.

Then it kind of got away from me. I'm running Claude, Codex, and Antigravity at the same time — north of $200 a month across all of it — and I had no real idea how much of any of them I was actually burning. No dashboard. Just vibes, and the occasional "you've hit your limit" slap in the face at the worst possible moment. So I bolted usage tracking onto the wake bot. Then reset timers. Then a little menu-bar readout so I could stop guessing. And here we are.

That's the whole story. No roadmap deck, no mission statement, no "reimagining developer productivity." I was annoyed, I had a weekend, this exists now.

<br>

## 🔒 Your data never leaves your Mac

I'll be straight with you: I wouldn't install this app if I hadn't written it.

Look at what it does. It reads your local AI logs — prompt counts, reset timestamps, which accounts you're signed into. That's *exactly* the kind of stuff a sketchy closed-source menu-bar app would quietly vacuum up and ship off to some analytics endpoint. If a random binary asked to do that, you'd say no. You should.

So here's the deal. Wakie has no backend. There is no server. No telemetry, no analytics, no "anonymous usage stats," nothing phoning home except the signed check for app updates. It reads files on your disk, does the math on your machine, and draws a number in your menu bar. That's the entire loop. Turn off your wifi and it works exactly the same.

And you don't have to take my word for it — that's the whole reason it's open source under AGPL. The code is right there. `grep` the repo for a URL. You'll find the update feed and nothing else. If you ever catch this thing opening a socket it has no business opening, file an issue with my name on it.

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

PRs welcome, genuinely. The stuff I'd actually love help with:

- **Adapters for other AI tools** — the pattern's in [`packages/core/lib/src/adapters`](packages/core/lib/src/adapters). Copy one, wire it up, send it.
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
