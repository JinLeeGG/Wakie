import 'theme.dart';
import 'package:flutter/widgets.dart';

enum Provider { claude, codex, anti }

extension ProviderAsset on Provider {
  // Each provider's real desktop app icon, extracted from the installed
  // app's .icns — shown as-is (full-bleed in badges, circle-cropped as the
  // empty-state planets) rather than re-drawn.
  String get icon => switch (this) {
    Provider.claude => 'assets/icons/claude_app.png',
    Provider.codex => 'assets/icons/codex_app.png',
    Provider.anti => 'assets/icons/antigravity_app.png',
  };

  // Fill behind the icon, matching its own background — covers the icon's
  // transparent margins (and the Codex cloud, which floats with no square).
  Color get badgeBg => switch (this) {
    Provider.claude => const Color(0xFFD97757), // terracotta squircle
    Provider.codex => const Color(0xFFEDF1F7), // cloud floats on light
    Provider.anti => const Color(0xFF1B1C21), // dark squircle
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

/// Friendly "time until [at]" for reset tooltips: "5h 12m", "3d 4h", "12m",
/// or "under a minute" (also the fallback for an instant already past).
String untilLabel(DateTime at, {DateTime? now}) {
  final d = at.difference(now ?? DateTime.now());
  if (d.inMinutes < 1) return 'under a minute';
  final days = d.inDays;
  final hours = d.inHours % 24;
  final mins = d.inMinutes % 60;
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${mins}m';
  return '${mins}m';
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

  /// This week's API-equivalent value in dollars — what the account's local
  /// token logs would have cost at API list price. Null when the provider
  /// keeps no readable token log (Antigravity) or the scan hasn't landed;
  /// the Saved card renders that as "–".
  final double? apiValue;

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
    this.apiValue,
  });
}

/// "$1,435" — dollars at a glance for the Saved card. Whole dollars with
/// thousands grouping; one decimal only under $10 (where a whole dollar
/// would round tiny real values to noise).
String usdLabel(double v) {
  if (v < 10) {
    final s = v.toStringAsFixed(1);
    return '\$${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}';
  }
  final digits = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
    b.write(digits[i]);
  }
  return '\$$b';
}

/// The exact 7 rows from dashboard-mockup.html.
const mockAccounts = <Account>[
  Account(
    provider: Provider.claude,
    name: 'Claude · Personal',
    plan: 'wakieDemo1@gmail.com · Pro',
    session: Meter(12, Tone.crit, '4:30am'),
    weekly: Meter(34, Tone.warn, 'Jul 7 (5:00pm)'),
    status: RunStatus.low,
    apiValue: 132.4,
    autoStart: true,
  ),
  Account(
    provider: Provider.claude,
    name: 'Claude · Work',
    plan: 'wakieDemo2@gmail.com · Max',
    session: Meter(88, Tone.ok, '9:15am'),
    weekly: Meter(92, Tone.ok, 'Jul 7 (9:15am)'),
    status: RunStatus.ok,
    apiValue: 486.0,
    autoStart: true,
  ),
  Account(
    provider: Provider.codex,
    name: 'Codex · main',
    plan: 'wakieDemo3@gmail.com · Plus',
    session: Meter(100, Tone.ok, '1:20pm'),
    weekly: Meter(59, Tone.ok, 'Jul 6 (2:00pm)'),
    status: RunStatus.fresh,
    apiValue: 21.7,
  ),
  Account(
    provider: Provider.anti,
    name: 'Antigravity · main',
    plan: 'wakieDemo4@gmail.com',
    session: Meter(45, Tone.warn, '11:55am'),
    weekly: Meter(38, Tone.warn, 'Jul 7 (11:00am)'),
    status: RunStatus.ok,
  ),
  Account(
    provider: Provider.codex,
    name: 'Codex · work',
    plan: 'wakieDemo5@gmail.com · Pro',
    session: Meter(76, Tone.ok, '2:05pm'),
    weekly: Meter(64, Tone.ok, 'Jul 6 (6:30pm)'),
    status: RunStatus.fresh,
    apiValue: 8.3,
  ),
  Account(
    provider: Provider.claude,
    name: 'Claude · side',
    plan: 'wakieDemo6@gmail.com · Pro',
    session: Meter(41, Tone.warn, '3:40pm'),
    weekly: Meter(70, Tone.ok, 'Jul 8 (8:00am)'),
    status: RunStatus.ok,
    apiValue: 64.9,
    autoStart: true,
  ),
  Account(
    provider: Provider.anti,
    name: 'Antigravity · test',
    plan: 'wakieDemo7@gmail.com',
    session: Meter(82, Tone.ok, '5:10pm'),
    weekly: Meter(55, Tone.ok, 'Jul 7 (3:00pm)'),
    status: RunStatus.ok,
  ),
];

const taglines = <String>[
  "Let's Token Maxxing.",
  "Your Claude has been refreshed. Let's grind.",
  "Dedicate your Tokens!!",
  "Do you need more usage?",
  "Touch grass. We'll touch tokens.",
  "Please don't sue us for this.",
  "Squeeze every last token",
  "I mean, make your money worth.",
];
