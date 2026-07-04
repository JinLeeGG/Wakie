import 'dart:convert';
import 'dart:io';

import 'account.dart';
import 'provider.dart';
import 'status.dart';

/// A user-added account beyond a provider's single ambient default
/// (FR-UI-04) — isolated by its own [configHome], e.g. a second Claude
/// login. Persisted so discovery includes it on every future scan.
class ExtraAccount {
  final String id;
  final Provider provider;
  final String label;
  final String configHome;
  final DateTime addedAt;

  const ExtraAccount({
    required this.id,
    required this.provider,
    required this.label,
    required this.configHome,
    required this.addedAt,
  });

  Account toAccount({String deviceId = 'local'}) => Account(
        id: id,
        provider: provider,
        label: label,
        configHome: configHome,
        deviceId: deviceId,
        addedAt: addedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider.name,
        'label': label,
        'configHome': configHome,
        'addedAt': addedAt.toIso8601String(),
      };

  factory ExtraAccount.fromJson(Map<String, dynamic> j) => ExtraAccount(
        id: j['id'] as String,
        provider: Provider.values.byName(j['provider'] as String),
        label: j['label'] as String,
        configHome: j['configHome'] as String,
        addedAt: DateTime.parse(j['addedAt'] as String),
      );
}

/// Local-only persistence for account removals and last-known status
/// (PRD §10.1, FR-RN-07). A single JSON file — no credentials, no
/// prompt/response content (R0).
///
/// [Store.memory] never touches disk (used by [Store.load]'s in-memory
/// fallback and by tests); [Store.load] reads/writes a real file.
/// Default daily dark-wake time when the user hasn't set one (PRD §9.2 —
/// "아침 앵커"): 8:00am local.
const defaultMorningAnchorHour = 8;
const defaultMorningAnchorMinute = 0;

class Store {
  final File? _file;
  final Set<String> _removedAccountIds;
  final Map<String, Status> _status;
  final Map<String, bool> _autoStart;
  final List<ExtraAccount> _extraAccounts;
  int? _morningAnchorHour;
  int? _morningAnchorMinute;
  bool? _launchAtLogin;
  bool? _darkWake;
  Map<String, dynamic> _loginLedger = const {};

  Store._(this._file, this._removedAccountIds, this._status, this._autoStart,
      this._extraAccounts,
      [this._morningAnchorHour,
      this._morningAnchorMinute,
      this._launchAtLogin,
      this._darkWake]);

  static String defaultPath() {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/.wakieai/store.json';
  }

  /// Where a new [ExtraAccount]'s isolated `configHome` should live
  /// (FR-UI-04) — sibling to [defaultPath] under the same `~/.wakieai/` root.
  static String defaultAccountsDir() {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/.wakieai/accounts';
  }

  factory Store.memory() =>
      Store._(null, <String>{}, <String, Status>{}, <String, bool>{}, []);

  /// Loads the store from [path] (default: [defaultPath]). A missing or
  /// corrupt file behaves like an empty store rather than throwing (FR-ER).
  factory Store.load([String? path]) {
    final file = File(path ?? defaultPath());
    if (!file.existsSync()) {
      return Store._(file, <String>{}, <String, Status>{}, <String, bool>{}, []);
    }
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final removed = <String>{
        for (final id in (json['removedAccountIds'] as List? ?? const []))
          id as String,
      };
      final statusJson = json['status'] as Map<String, dynamic>? ?? const {};
      final status = <String, Status>{
        for (final entry in statusJson.entries)
          entry.key:
              _statusFromJson(entry.key, entry.value as Map<String, dynamic>),
      };
      final autoStartJson =
          json['autoStart'] as Map<String, dynamic>? ?? const {};
      final autoStart = <String, bool>{
        for (final entry in autoStartJson.entries) entry.key: entry.value as bool,
      };
      final extraJson = json['extraAccounts'] as List? ?? const [];
      final extra = [
        for (final e in extraJson)
          ExtraAccount.fromJson(e as Map<String, dynamic>),
      ];
      return Store._(
          file,
          removed,
          status,
          autoStart,
          extra,
          json['morningAnchorHour'] as int?,
          json['morningAnchorMinute'] as int?,
          json['launchAtLogin'] as bool?,
          json['darkWake'] as bool?)
        .._loginLedger =
            json['loginLedger'] as Map<String, dynamic>? ?? const {};
    } catch (_) {
      return Store._(file, <String>{}, <String, Status>{}, <String, bool>{}, []);
    }
  }

  bool isRemoved(String accountId) => _removedAccountIds.contains(accountId);

  /// Marks an account removed so rediscovery won't resurrect it, and drops
  /// it from [extraAccounts] if it was a user-added one. Safe to call for
  /// either kind — a no-op on the list for an ambient default id.
  void removeAccount(String accountId) {
    _removedAccountIds.add(accountId);
    _extraAccounts.removeWhere((e) => e.id == accountId);
    _save();
  }

  /// The user's explicit auto-start (session chaining) choice for an
  /// account, or null if they haven't set one — callers fall back to
  /// [defaultAutoStart] for the account's provider (PRD §17 R0 traffic
  /// light: Claude on by default, Codex/Antigravity off).
  bool? autoStartPreference(String accountId) => _autoStart[accountId];

  void setAutoStart(String accountId, bool enabled) {
    _autoStart[accountId] = enabled;
    _save();
  }

  /// User-added accounts beyond each provider's single ambient default
  /// (FR-UI-04) — isolated by their own [ExtraAccount.configHome].
  List<ExtraAccount> get extraAccounts => List.unmodifiable(_extraAccounts);

  void addExtraAccount(ExtraAccount account) {
    _extraAccounts.removeWhere((e) => e.id == account.id);
    _extraAccounts.add(account);
    _save();
  }

  /// The daily dark-wake time (PRD §9.2 "아침 앵커"), defaulting to 8:00am
  /// local when the user hasn't set one.
  int get morningAnchorHour => _morningAnchorHour ?? defaultMorningAnchorHour;
  int get morningAnchorMinute =>
      _morningAnchorMinute ?? defaultMorningAnchorMinute;

  void setMorningAnchor(int hour, int minute) {
    _morningAnchorHour = hour;
    _morningAnchorMinute = minute;
    _save();
  }

  /// Whether the app registers itself as a login item. Off until the user
  /// turns it on (the toggle must reflect what's actually installed).
  bool get launchAtLogin => _launchAtLogin ?? false;

  void setLaunchAtLogin(bool enabled) {
    _launchAtLogin = enabled;
    _save();
  }

  /// Whether the app has programmed a daily hardware wake (`pmset`) so it can
  /// update while the Mac sleeps. Off until the user turns it on (an admin
  /// action — see [runWithAdminPrompt]); mirrors what's actually scheduled.
  bool get darkWake => _darkWake ?? false;

  void setDarkWake(bool enabled) {
    _darkWake = enabled;
    _save();
  }

  /// The persisted login-ledger JSON (see `LoginLedger`) — which login owned
  /// each provider's shared default home over time, for attributing that
  /// home's API-value estimate per account. Raw JSON so the store stays
  /// decoupled from the ledger type.
  Map<String, dynamic> get loginLedgerJson => _loginLedger;

  void saveLoginLedger(Map<String, dynamic> json) {
    _loginLedger = json;
    _save();
  }

  Status? statusFor(String accountId) => _status[accountId];

  /// Caches an account's last-known status so the dashboard has something to
  /// show immediately on the next cold start, before a live read completes.
  void saveStatus(Status status) {
    _status[status.accountId] = status;
    _save();
  }

  /// Convenience: wraps a live [ProviderStatus] read into a [Status] record
  /// (stamped with now, outcome ok) and saves it. Shared by the GUI engine's
  /// refresh path and the headless runner, so both cache reads identically.
  void cacheStatus(String accountId, ProviderStatus status) => saveStatus(
        Status(
          accountId: accountId,
          session: status.session,
          weekly: status.weekly,
          lastOutcome: Outcome.ok,
          lastCheckedAt: DateTime.now(),
        ),
      );

  void _save() {
    final file = _file;
    if (file == null) return;
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode({
      'removedAccountIds': _removedAccountIds.toList(),
      'status': {
        for (final entry in _status.entries)
          entry.key: _statusToJson(entry.value),
      },
      'autoStart': _autoStart,
      'extraAccounts': [for (final e in _extraAccounts) e.toJson()],
      if (_morningAnchorHour != null) 'morningAnchorHour': _morningAnchorHour,
      if (_morningAnchorMinute != null)
        'morningAnchorMinute': _morningAnchorMinute,
      if (_launchAtLogin != null) 'launchAtLogin': _launchAtLogin,
      if (_darkWake != null) 'darkWake': _darkWake,
      if (_loginLedger.isNotEmpty) 'loginLedger': _loginLedger,
    }));
  }

  static Map<String, dynamic> _statusToJson(Status s) => {
        'sessionUsedPct': s.session.usedPct,
        'sessionResetLabel': s.session.resetLabel,
        'sessionResetAt': s.session.resetAt?.toIso8601String(),
        'weeklyUsedPct': s.weekly.usedPct,
        'weeklyResetLabel': s.weekly.resetLabel,
        'weeklyResetAt': s.weekly.resetAt?.toIso8601String(),
        'lastStartedAt': s.lastStartedAt?.toIso8601String(),
        'lastOutcome': s.lastOutcome.name,
        'lastCheckedAt': s.lastCheckedAt?.toIso8601String(),
      };

  static Status _statusFromJson(String accountId, Map<String, dynamic> j) {
    DateTime? date(String key) =>
        j[key] != null ? DateTime.parse(j[key] as String) : null;
    return Status(
      accountId: accountId,
      session: UsageWindow(
        usedPct: j['sessionUsedPct'] as int?,
        resetLabel: j['sessionResetLabel'] as String?,
        resetAt: date('sessionResetAt'),
      ),
      weekly: UsageWindow(
        usedPct: j['weeklyUsedPct'] as int?,
        resetLabel: j['weeklyResetLabel'] as String?,
        resetAt: date('weeklyResetAt'),
      ),
      lastStartedAt: date('lastStartedAt'),
      lastOutcome:
          Outcome.values.byName(j['lastOutcome'] as String? ?? 'unknown'),
      lastCheckedAt: date('lastCheckedAt'),
    );
  }
}
