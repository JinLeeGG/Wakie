import 'reset_time.dart';
import 'status.dart';

enum AlertType { nearLimit, resetSoon, failure }

class Alert {
  final String accountId;
  final AlertType type;
  final String message;
  const Alert(this.accountId, this.type, this.message);
}

/// Confirmed thresholds (PRD §7.4 FR-NT-03, O2 — 2026-07-02): "almost out" at
/// 80% used, "reset imminent" within 10 minutes of the session window's end.
const nearLimitThresholdPct = 80;
const resetSoonThreshold = Duration(minutes: 10);

/// Edge-triggered: compares the previously cached [Status] to the [current]
/// one about to be saved, and returns alerts only for conditions that just
/// became true — never re-fires every pass while a condition merely persists
/// (FR-NT-04's spam concern, solved structurally instead of by grouping).
/// Pure function, no I/O — shared by the headless runner and the GUI so both
/// drive real notifications from the same decisions.
List<Alert> evaluateAlerts(String accountId, Status? previous, Status current,
    {DateTime? now}) {
  final at = now ?? DateTime.now();
  final alerts = <Alert>[];

  final usedPct = current.session.usedPct;
  if (usedPct != null && usedPct >= nearLimitThresholdPct) {
    final prevPct = previous?.session.usedPct;
    if (prevPct == null || prevPct < nearLimitThresholdPct) {
      alerts.add(Alert(accountId, AlertType.nearLimit,
          '$accountId is at $usedPct% usage — almost out.'));
    }
  }

  final resetAt = resolveResetAt(current.session);
  if (resetAt != null && _within(at, resetAt)) {
    final prevResetAt =
        previous == null ? null : resolveResetAt(previous.session);
    final wasSoonBefore = previous?.lastCheckedAt != null &&
        prevResetAt != null &&
        _within(previous!.lastCheckedAt!, prevResetAt);
    if (!wasSoonBefore) {
      alerts.add(Alert(accountId, AlertType.resetSoon,
          '$accountId resets in less than 10 minutes.'));
    }
  }

  if (current.lastOutcome == Outcome.failed &&
      previous?.lastOutcome != Outcome.failed) {
    alerts.add(
        Alert(accountId, AlertType.failure, '$accountId: session start failed.'));
  }

  return alerts;
}

bool _within(DateTime at, DateTime resetAt) =>
    !at.isBefore(resetAt.subtract(resetSoonThreshold)) && at.isBefore(resetAt);
