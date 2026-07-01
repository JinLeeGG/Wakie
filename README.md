<div align="center">

<img src="docs/design/app-icon.svg" width="96" height="96" alt="WakieAI logo">

# WakieAI

**One tier's price. Every subscription, at full usage.**

A Mac menu-bar app that keeps your logged-in AI subscriptions (Claude, Codex, Antigravity) warm, tracks each account's usage and reset windows in one dashboard, and wakes your Mac on schedule to refresh sessions — so the right account is always ready when you are.

`Status: design & spec` · PRD + interactive UI mockups complete · implementation next

</div>

---

## Why

Power users get more out of AI by running **several cheaper subscriptions/accounts** instead of one $200 top tier. The catch is that juggling them is tedious — which account has budget left, when each rolling window resets, and when to switch. You end up opening every CLI or web app to check.

WakieAI is a **multi-account AI usage orchestrator**: a background app on your Mac cycles through your logged-in AI CLIs, reads each account's session/weekly usage, and shows it in one glass dashboard — then wakes the machine on a schedule to keep sessions fresh and nudges you when it's time to act.

## What it does

- **Unified dashboard** — every account's session % + weekly % and reset times in one place, with live status pills.
- **Warm on schedule** — the Mac wakes from sleep (`pmset` + a LaunchAgent helper) to start/refresh sessions, then goes back to sleep.
- **Right-account nudges** — notifications for "running low", "just reset", "reconnect needed" — each with a one-tap fix.
- **Per-account actions** — **Update** (start a session + refresh that account) and global **Refresh all** (read status only).
- **Multi-account by design** — several accounts per provider, isolated via each CLI's config-home (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `HOME`).

## What it does *not* do

- ❌ Reset or bypass quotas — it only **starts** the rolling window; usage is still spent.
- ❌ Proxy your credentials — it rides on each CLI's **official login**, nothing more.
- ❌ Store or transmit prompts/responses — credentials and content stay **local to your Mac**.

## How it works

```
Phase 0–1   [ Mac menu-bar app ] ── cycles local CLIs ──▶ [ claude / codex / agy × accounts ]
              engine + dashboard                            credentials · prompts = local only

Phase 2     [ iPhone app ] ◀── Supabase relay ──▶ [ Mac app ]     (commands + status metadata only)
```

The Mac app is both the **engine** (detect → wake → scrape usage → start session → notify) and the **dashboard**. Credentials, prompts and responses never leave the machine. In Phase 2 a phone becomes a remote control over a Supabase relay that carries only commands and status metadata — never secrets.

## Supported providers

| Provider (CLI) | Start session | Usage / reset | Multi-account |
| --- | --- | --- | --- |
| **Claude** (`claude`) | `-p` | `/usage` + `/stats` | `CLAUDE_CONFIG_DIR` |
| **Codex** (`codex`) | `exec` | `/status` + `/usage daily` | `CODEX_HOME` / `--profile` |
| **Antigravity** (`agy`) | `-p` | `/usage` (weekly · 5h) | `HOME` sandbox |

> Grok is intentionally out of scope (shared weekly pool, no 5h window, usage not exposed via CLI).

## Design

The visual language is **dark frosted glass** — translucent floating panels, hairline borders, tabular-mono numbers, a single amber accent plus semantic colors (green / amber / red). The mark is an "orbit": a white ring around an amber core (an awakened star).

Interactive mockups live in [`docs/design/`](docs/design/) — open any `.html` in a browser. The onboarding → dashboard flow is wired click-through:

| Screen | File |
| --- | --- |
| Onboarding · sign in | [onboarding-step1.html](docs/design/onboarding-step1.html) |
| Onboarding · detect accounts | [onboarding-step2.html](docs/design/onboarding-step2.html) |
| Onboarding · schedule | [onboarding-step3.html](docs/design/onboarding-step3.html) |
| Add account | [add-account.html](docs/design/add-account.html) |
| Dashboard · healthy | [dashboard-mockup.html](docs/design/dashboard-mockup.html) |
| Dashboard · needs attention | [dashboard-error.html](docs/design/dashboard-error.html) |
| Dashboard · empty state | [dashboard-empty.html](docs/design/dashboard-empty.html) |
| Menu-bar icon states | [menubar-icon.html](docs/design/menubar-icon.html) |
| Notifications | [notifications.html](docs/design/notifications.html) |

## Roadmap

| Phase | Deliverable |
| --- | --- |
| **0** | Mac core — auto-detect accounts, scrape `/usage`, menu-bar dashboard, on-demand session start |
| **1** | Sleep-wake (`pmset` + LaunchAgent dark wake), schedules, macOS notifications, add-account UX |
| **2** | Supabase relay + iPhone app (remote dashboard/control) + push notifications |
| **3** | Hardening, multi-account scale, auto-login guidance, Windows/Android exploration |

## Tech stack (planned)

- **Mac app** — Flutter (macOS menu bar) + a bundled LaunchAgent helper
- **Shared core** — Dart package (account models, provider adapters, status logic)
- **Phone app** (Phase 2) — Flutter (iOS/Android)
- **Relay** (Phase 2) — Supabase (Postgres + Realtime + Auth + RLS)

## Repository

```
WakeyAI/
├── CLAUDE.md            # engineering behavior guidelines
├── docs/
│   ├── PRD.md           # product requirements (source of truth)
│   └── design/          # interactive UI mockups + logo
└── README.md
```

## Privacy

Credentials (CLI OAuth tokens) and all prompt/response content are **local-only**, held in each CLI's own config home and the macOS keychain. The Phase-2 relay stores only usage metadata, commands (a fixed enum — no arbitrary execution), and pairing info, protected by row-level security and TLS.

---

<div align="center"><sub>Owner: John · wakieDemo1@gmail.com · see <a href="docs/PRD.md">PRD</a> for full detail</sub></div>
