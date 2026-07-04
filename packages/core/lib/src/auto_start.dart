import 'account.dart';
import 'adapter.dart';
import 'preflight.dart';
import 'provider.dart';
import 'reset_time.dart';
import 'status.dart';
import 'store.dart';

/// Recommended default for the auto-start (session-chaining) toggle when the
/// user hasn't set one explicitly — on only where automation sits on
/// defensible ToS ground (PRD §17 R0 traffic light: Claude 🟢). Codex (🟡)
/// and Antigravity (🟠) default off; the user can opt in per account.
bool defaultAutoStart(Provider p) => p == Provider.claude;

/// The provider's actual quota refresh can lag the reset time it prints by a
/// few seconds. Firing the chain the instant the clock crosses that time hits a
/// still-exhausted window — Claude rejects it with "you've hit your session
/// limit" (exit 1), which then surfaces as a false "session start failed"
/// alert. Wait this out so the first attempt lands on a genuinely fresh window.
const _resetGrace = Duration(minutes: 1);

/// An idle-chain start that immediately lands back on an idle-looking window
/// (a provider that hides its reset countdown even mid-window) must not turn
/// into a start-per-tick loop — cap idle re-arms to one per this interval.
/// A real 5h window comfortably outlasts it, so normal chaining is unaffected.
const _idleRearmGap = Duration(minutes: 30);

/// "Token maxxing" (PRD §6/§15 D1): for each account whose session window has
/// already reset and whose auto-start toggle is on, starts a fresh session
/// (cheapest model, minimal prompt) so a new window opens — then re-reads and
/// caches the account's status. Accounts still mid-window, or with auto-start
/// off, are left untouched (D1 — regular refresh is read-only; only this
/// chaining path ever starts a session).
///
/// A window that never opened counts as due too: rolling-window providers
/// (Antigravity) report an untouched account as fully-remaining with *no*
/// reset instant — there's nothing to lapse, but arming a window is exactly
/// what the toggle promises. Guarded by [_idleRearmGap] so a provider that
/// keeps looking idle can't be re-armed every tick.
///
/// [read] is the status already fetched for each account this pass (from the
/// same read the caller used to update the dashboard/store) — this function
/// doesn't re-read before deciding, so it can't double-charge quota checking.
/// Pure orchestration over injected adapters/store — no Flutter dependency,
/// so the headless dark-wake runner and the Mac GUI can share it.
Future<void> chainExpiredSessions(
  Map<Provider, ProviderAdapter> adapters,
  Store store,
  List<(Account, Preflight, ProviderStatus)> read, {
  DateTime? now,
  void Function(String message)? log,
}) async {
  final at = now ?? DateTime.now();
  for (final (account, _, status) in read) {
    final enabled =
        store.autoStartPreference(account.id) ?? defaultAutoStart(account.provider);
    if (!enabled) continue;

    final resetAt = resolveResetAt(status.session);
    // Idle: usage is known, nothing consumed, and no window is running.
    final idle =
        status.session.isKnown && status.session.usedPct == 0 && resetAt == null;
    if (idle) {
      final last = store.statusFor(account.id)?.lastStartedAt;
      if (last != null && at.difference(last) < _idleRearmGap) continue;
    } else if (resetAt == null || at.isBefore(resetAt.add(_resetGrace))) {
      continue;
    }

    log?.call(idle
        ? 'wakieai: ${account.id} has no session window open — starting one'
        : 'wakieai: ${account.id} session window lapsed at $resetAt — starting a new one');
    final adapter = adapters[account.provider]!;
    final outcome = await adapter.startSession(account);
    final fresh = outcome.ok ? await adapter.readStatus(account) : status;
    store.saveStatus(Status(
      accountId: account.id,
      session: fresh.session,
      weekly: fresh.weekly,
      lastStartedAt: outcome.startedAt,
      lastOutcome: outcome.ok ? Outcome.ok : Outcome.failed,
      lastCheckedAt: DateTime.now(),
    ));
    log?.call(outcome.ok
        ? 'wakieai: ${account.id} — new session started'
        : 'wakieai: ${account.id} — session start failed: ${outcome.error}');
  }
}
