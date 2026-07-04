import 'package:test/test.dart';
import 'package:wakieai_core/wakieai_core.dart';

void main() {
  final t0 = DateTime.utc(2026, 7, 1, 9);
  final t1 = DateTime.utc(2026, 7, 2, 14);
  final t2 = DateTime.utc(2026, 7, 3, 20);

  test('sample appends only on change (case-insensitively)', () {
    final ledger = LoginLedger();
    expect(ledger.sample(Provider.claude, 'A@b.com', t0), isTrue);
    expect(ledger.sample(Provider.claude, 'a@b.com', t1), isFalse); // same
    expect(ledger.sample(Provider.claude, 'x@b.com', t2), isTrue);
  });

  test('ownerAt: within history, gaps go to the login seen entering them', () {
    final ledger = LoginLedger()
      ..sample(Provider.claude, 'a@b.com', t0)
      ..sample(Provider.claude, 'x@b.com', t1);
    // Mid first segment.
    expect(ledger.ownerAt(Provider.claude, t0.add(const Duration(hours: 5))),
        'a@b.com');
    // Exactly at a change → the new login.
    expect(ledger.ownerAt(Provider.claude, t1), 'x@b.com');
    // After the last observation → last login.
    expect(ledger.ownerAt(Provider.claude, t2), 'x@b.com');
  });

  test('ownerAt: pre-tracking history has no owner — accounts start at zero',
      () {
    final ledger = LoginLedger()..sample(Provider.claude, 'a@b.com', t1);
    expect(ledger.ownerAt(Provider.claude, t0), isNull);
    expect(ledger.ownerAt(Provider.claude, t1), 'a@b.com');
  });

  test('ownerAt: empty ledger and unrelated provider are unknown', () {
    final ledger = LoginLedger()..sample(Provider.claude, 'a@b.com', t0);
    expect(ledger.ownerAt(Provider.codex, t1), isNull);
    expect(LoginLedger().ownerAt(Provider.claude, t1), isNull);
  });

  test('signed-out samples are recorded as null owners', () {
    final ledger = LoginLedger()
      ..sample(Provider.claude, 'a@b.com', t0)
      ..sample(Provider.claude, null, t1);
    expect(ledger.ownerAt(Provider.claude, t2), isNull);
    expect(ledger.ownerAt(Provider.claude, t0), 'a@b.com');
  });

  test('prune keeps the change that defines ownership at the cutoff', () {
    final ledger = LoginLedger()
      ..sample(Provider.claude, 'a@b.com', t0)
      ..sample(Provider.claude, 'x@b.com', t1)
      ..sample(Provider.claude, 'y@b.com', t2);
    // Cutoff between t1 and t2: t0's entry is obsolete, t1's still defines
    // ownership at the cutoff instant.
    final cutoff = t1.add(const Duration(hours: 1));
    ledger.prune(cutoff);
    expect(ledger.ownerAt(Provider.claude, cutoff), 'x@b.com');
    expect(ledger.ownerAt(Provider.claude, t1), 'x@b.com');
    expect(ledger.ownerAt(Provider.claude, t2), 'y@b.com');
  });

  test('round-trips through JSON; corrupt JSON degrades to empty', () {
    final ledger = LoginLedger()
      ..sample(Provider.claude, 'a@b.com', t0)
      ..sample(Provider.codex, 'c@d.com', t1);
    final revived = LoginLedger.fromJson(ledger.toJson());
    expect(revived.ownerAt(Provider.claude, t2), 'a@b.com');
    expect(revived.ownerAt(Provider.codex, t2), 'c@d.com');

    final corrupt = LoginLedger.fromJson({'claude': 'not-a-list'});
    expect(corrupt.ownerAt(Provider.claude, t0), isNull);
  });
}
