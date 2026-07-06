import 'package:test/test.dart';
import 'package:wakie_core/wakie_core.dart';

void main() {
  final now = DateTime(2026, 6, 1, 15, 0);

  Status status({
    int? usedPct,
    DateTime? resetAt,
    Outcome outcome = Outcome.ok,
    DateTime? checkedAt,
  }) =>
      Status(
        accountId: 'claude-default',
        session: UsageWindow(usedPct: usedPct, resetAt: resetAt),
        lastOutcome: outcome,
        lastCheckedAt: checkedAt,
      );

  group('nearLimit (80% used)', () {
    test('fires the first time usage crosses 80%', () {
      final alerts = evaluateAlerts(
          'claude-default', null, status(usedPct: 88), now: now);
      expect(alerts.map((a) => a.type), [AlertType.nearLimit]);
    });

    test('does not re-fire while usage stays at/above 80%', () {
      final prev = status(usedPct: 85);
      final alerts = evaluateAlerts(
          'claude-default', prev, status(usedPct: 90), now: now);
      expect(alerts, isEmpty);
    });

    test('fires again after dropping back below 80% (new window)', () {
      final prev = status(usedPct: 20); // fresh window after a reset
      final alerts = evaluateAlerts(
          'claude-default', prev, status(usedPct: 82), now: now);
      expect(alerts.map((a) => a.type), [AlertType.nearLimit]);
    });

    test('below threshold never fires', () {
      final alerts =
          evaluateAlerts('claude-default', null, status(usedPct: 50), now: now);
      expect(alerts, isEmpty);
    });
  });

  group('resetSoon (within 10 minutes)', () {
    test('fires when crossing into the 10-minute window', () {
      final current = status(
        usedPct: 40,
        resetAt: DateTime(2026, 6, 1, 15, 8), // 8 min away
        checkedAt: now,
      );
      final alerts =
          evaluateAlerts('claude-default', null, current, now: now);
      expect(alerts.map((a) => a.type), [AlertType.resetSoon]);
    });

    test('does not re-fire on a later pass still inside the same window', () {
      final prev = status(
        usedPct: 40,
        resetAt: DateTime(2026, 6, 1, 15, 8),
        checkedAt: DateTime(2026, 6, 1, 15, 1), // was already within 10 min
      );
      final current = status(
        usedPct: 40,
        resetAt: DateTime(2026, 6, 1, 15, 8),
        checkedAt: now,
      );
      final alerts =
          evaluateAlerts('claude-default', prev, current, now: now);
      expect(alerts, isEmpty);
    });

    test('more than 10 minutes away does not fire', () {
      final current = status(
          usedPct: 40, resetAt: DateTime(2026, 6, 1, 16, 0), checkedAt: now);
      final alerts =
          evaluateAlerts('claude-default', null, current, now: now);
      expect(alerts, isEmpty);
    });

    test('already past reset does not fire (that is auto-start\'s job)', () {
      // usedPct kept below the nearLimit threshold to isolate this check.
      final current = status(
          usedPct: 50, resetAt: DateTime(2026, 6, 1, 14, 0), checkedAt: now);
      final alerts =
          evaluateAlerts('claude-default', null, current, now: now);
      expect(alerts, isEmpty);
    });
  });

  group('failure', () {
    test('fires on the transition into failed', () {
      final prev = status(outcome: Outcome.ok);
      final alerts = evaluateAlerts(
          'claude-default', prev, status(outcome: Outcome.failed),
          now: now);
      expect(alerts.map((a) => a.type), [AlertType.failure]);
    });

    test('does not re-fire while still failed', () {
      final prev = status(outcome: Outcome.failed);
      final alerts = evaluateAlerts(
          'claude-default', prev, status(outcome: Outcome.failed),
          now: now);
      expect(alerts, isEmpty);
    });
  });

  test('multiple conditions can fire together', () {
    final current = status(
      usedPct: 95,
      resetAt: DateTime(2026, 6, 1, 15, 5),
      outcome: Outcome.failed,
      checkedAt: now,
    );
    final prev = status(usedPct: 50, outcome: Outcome.ok);
    final alerts = evaluateAlerts('claude-default', prev, current, now: now);
    expect(
      alerts.map((a) => a.type).toSet(),
      {AlertType.nearLimit, AlertType.resetSoon, AlertType.failure},
    );
  });
}
