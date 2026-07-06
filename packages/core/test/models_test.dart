import 'package:test/test.dart';
import 'package:wakie_core/wakie_core.dart';

void main() {
  group('UsageWindow', () {
    test('unknown has no pct', () {
      expect(UsageWindow.unknown.isKnown, isFalse);
      expect(UsageWindow.unknown.usedPct, isNull);
    });

    test('known reports pct', () {
      const w = UsageWindow(usedPct: 42);
      expect(w.isKnown, isTrue);
      expect(w.usedPct, 42);
    });
  });

  group('Status.copyWith', () {
    final base = Status(accountId: 'a1', lastCheckedAt: DateTime(2026, 7, 1));

    test('overrides only provided fields', () {
      final next = base.copyWith(
        session: const UsageWindow(usedPct: 12),
        lastOutcome: Outcome.ok,
      );
      expect(next.accountId, 'a1');
      expect(next.session.usedPct, 12);
      expect(next.lastOutcome, Outcome.ok);
      expect(next.lastCheckedAt, base.lastCheckedAt);
    });
  });

  test('Preflight.isOk', () {
    expect(const Preflight(PreflightState.ok).isOk, isTrue);
    expect(const Preflight(PreflightState.notLoggedIn).isOk, isFalse);
  });
}
