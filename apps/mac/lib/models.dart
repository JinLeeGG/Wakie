import 'theme.dart';
import 'package:flutter/widgets.dart';

enum Provider { claude, codex, anti }

extension ProviderAsset on Provider {
  String get icon => switch (this) {
    Provider.claude => 'assets/icons/anthropic.svg',
    Provider.codex => 'assets/icons/codex.svg',
    Provider.anti => 'assets/icons/gemini.svg',
  };

  // Badge background tint, from .badge.claude/.codex/.anti
  Color get badgeBg => switch (this) {
    Provider.claude => const Color(0x29D97757), // rgba(217,119,87,.16)
    Provider.codex => T.white(.08),
    Provider.anti => const Color(0x267896F0), // rgba(120,150,240,.15)
  };
}

/// ok / warn / crit tone for meters, matching the pct + fill classes.
enum Tone { ok, warn, crit }

extension ToneColors on Tone {
  Color get text => switch (this) {
    Tone.ok => T.ok,
    Tone.warn => T.warn,
    Tone.crit => T.crit,
  };
}

/// [signin]: a user-added account whose provider login isn't finished yet —
/// shown as an actionable pill instead of being hidden (FR-ER).
enum RunStatus { fresh, ok, low, signin }

class Meter {
  final int pct;
  final Tone tone;
  final String reset;

  /// False when the provider reported no data for this window (e.g. free
  /// plans expose no 5h session window, only a weekly quota). Rendered as
  /// "—" — an unknown must never masquerade as an exhausted 0%.
  final bool known;
  const Meter(this.pct, this.tone, this.reset, {this.known = true});
}

class Account {
  /// Core account id (e.g. "claude-default"), used to refresh this one row.
  /// Empty for the static [mockAccounts].
  final String id;
  final Provider provider;
  final String name;
  final String plan; // subtitle, e.g. "name@gmail.com · Pro"
  final Meter session;
  final Meter weekly;
  final RunStatus status;

  /// Session-chaining toggle (D1 "token maxxing"): when on, the engine
  /// starts a fresh session the moment this account's window resets.
  final bool autoStart;

  /// False when the account has no usable current-session reset window, so
  /// the auto-start toggle is visible but disabled instead of promising work
  /// the engine cannot do.
  final bool autoStartAvailable;

  /// Absolute instant the session window resets, when known — drives the
  /// summary bar's "next reset". Null for mock rows and unknown windows.
  final DateTime? sessionResetAt;

  const Account({
    this.id = '',
    required this.provider,
    required this.name,
    required this.plan,
    required this.session,
    required this.weekly,
    required this.status,
    this.autoStart = false,
    this.autoStartAvailable = true,
    this.sessionResetAt,
  });
}

/// The exact 7 rows from dashboard-mockup.html.
const mockAccounts = <Account>[
  Account(
    provider: Provider.claude,
    name: 'Claude · Personal',
    plan: 'korus.exe@gmail.com · Pro',
    session: Meter(12, Tone.crit, '4:30am'),
    weekly: Meter(34, Tone.warn, 'Jul 7 (5:00pm)'),
    status: RunStatus.low,
    autoStart: true,
  ),
  Account(
    provider: Provider.claude,
    name: 'Claude · Work',
    plan: 'korus.work@gmail.com · Max',
    session: Meter(88, Tone.ok, '9:15am'),
    weekly: Meter(92, Tone.ok, 'Jul 7 (9:15am)'),
    status: RunStatus.ok,
    autoStart: true,
  ),
  Account(
    provider: Provider.codex,
    name: 'Codex · main',
    plan: 'korus.exe@gmail.com · Plus',
    session: Meter(100, Tone.ok, '1:20pm'),
    weekly: Meter(59, Tone.ok, 'Jul 6 (2:00pm)'),
    status: RunStatus.fresh,
  ),
  Account(
    provider: Provider.anti,
    name: 'Antigravity · main',
    plan: 'korus.exe@gmail.com',
    session: Meter(45, Tone.warn, '11:55am'),
    weekly: Meter(38, Tone.warn, 'Jul 7 (11:00am)'),
    status: RunStatus.ok,
  ),
  Account(
    provider: Provider.codex,
    name: 'Codex · work',
    plan: 'korus.work@gmail.com · Pro',
    session: Meter(76, Tone.ok, '2:05pm'),
    weekly: Meter(64, Tone.ok, 'Jul 6 (6:30pm)'),
    status: RunStatus.fresh,
  ),
  Account(
    provider: Provider.claude,
    name: 'Claude · side',
    plan: 'korus.side@gmail.com · Pro',
    session: Meter(41, Tone.warn, '3:40pm'),
    weekly: Meter(70, Tone.ok, 'Jul 8 (8:00am)'),
    status: RunStatus.ok,
    autoStart: true,
  ),
  Account(
    provider: Provider.anti,
    name: 'Antigravity · test',
    plan: 'korus.test@gmail.com',
    session: Meter(82, Tone.ok, '5:10pm'),
    weekly: Meter(55, Tone.ok, 'Jul 7 (3:00pm)'),
    status: RunStatus.ok,
  ),
];

const taglines = <String>[
  "Let's Token Maxxing.",
  'Say good morning to AI agents.',
  'Rise and grind, AI edition.',
  'Your Mac woke up. Did you?',
  "We hit snooze. Your AI doesn't.",
  'While you dream, we refresh.',
  'Set it. Sleep. Repeat.',
  'Claude is up. Are you?',
  'Your AI does the night shift.',
  "Tokens don't refresh themselves.",
  'Keeping your context warm.',
  'AI: on. Coffee: optional.',
];
