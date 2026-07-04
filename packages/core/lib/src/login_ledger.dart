import 'provider.dart';

/// One observed change of which login owns a provider's shared default home
/// (`~/.claude`, `~/.codex`). [email] is lowercased; null means signed out.
class LoginChange {
  final String? email;
  final DateTime at;
  const LoginChange(this.email, this.at);
}

/// Change-log of default-home logins, sampled by the engine (a cheap config
/// file read, roughly once a minute while the app runs).
///
/// This exists because CLI token logs carry timestamps but no account
/// identity — everything done in a terminal lands in the provider's shared
/// default home no matter which managed account it belongs to. Cross-
/// referencing an event's timestamp against this ledger attributes it to
/// the account that was signed in at the time. The result is an **estimate**:
/// exact while the app was running to observe switches, approximate across
/// gaps (see [ownerAt]).
class LoginLedger {
  final Map<Provider, List<LoginChange>> _changes;

  LoginLedger() : _changes = {};

  LoginLedger._(this._changes);

  /// Records one observation. Appends only when the login actually changed;
  /// returns true when it did (callers persist on true).
  bool sample(Provider p, String? email, DateTime at) {
    final normalized = email?.toLowerCase();
    final list = _changes.putIfAbsent(p, () => []);
    if (list.isNotEmpty && list.last.email == normalized) return false;
    list.add(LoginChange(normalized, at.toUtc()));
    return true;
  }

  /// The login that owns [p]'s default home at [at]:
  ///
  ///  * within observed history — the most recent change at or before [at]
  ///    (a gap between observations belongs to the login seen *entering* it;
  ///    the switch can only be located at the next observation);
  ///  * before the first observation — null. Pre-tracking history has no
  ///    knowable owner, and guessing (e.g. crediting it all to whoever was
  ///    signed in at install) is exactly the misattribution this ledger
  ///    exists to fix — so every account starts at zero and the numbers
  ///    only ever show what was actually observed;
  ///  * no observations at all — null.
  String? ownerAt(Provider p, DateTime at) {
    final list = _changes[p];
    if (list == null || list.isEmpty) return null;
    final t = at.toUtc();
    if (list.first.at.isAfter(t)) return null;
    LoginChange owner = list.first;
    for (final c in list) {
      if (c.at.isAfter(t)) break;
      owner = c;
    }
    return owner.email;
  }

  /// Drops changes that no longer matter: everything strictly older than the
  /// last change at-or-before [cutoff] (that one still defines ownership at
  /// the window's edge).
  void prune(DateTime cutoff) {
    final t = cutoff.toUtc();
    for (final list in _changes.values) {
      var keepFrom = 0;
      for (var i = 0; i < list.length; i++) {
        if (list[i].at.isAfter(t)) break;
        keepFrom = i;
      }
      list.removeRange(0, keepFrom);
    }
  }

  Map<String, dynamic> toJson() => {
        for (final e in _changes.entries)
          e.key.name: [
            for (final c in e.value)
              {'email': c.email, 'at': c.at.toIso8601String()},
          ],
      };

  /// Tolerant of missing/corrupt data — an unreadable ledger starts empty
  /// (attribution restarts from the next sample) rather than throwing.
  factory LoginLedger.fromJson(Map<String, dynamic> json) {
    final changes = <Provider, List<LoginChange>>{};
    try {
      for (final e in json.entries) {
        final p = Provider.values.byName(e.key);
        changes[p] = [
          for (final c in (e.value as List))
            LoginChange(
              (c as Map)['email'] as String?,
              DateTime.parse(c['at'] as String),
            ),
        ];
      }
    } catch (_) {
      return LoginLedger();
    }
    return LoginLedger._(changes);
  }
}
