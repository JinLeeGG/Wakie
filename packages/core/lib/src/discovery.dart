import 'account.dart';
import 'adapter.dart';
import 'preflight.dart';
import 'provider.dart';
import 'store.dart';

/// Each provider's CLI binary, for [terminalCommandFor].
const _executables = {
  Provider.claude: 'claude',
  Provider.codex: 'codex',
  Provider.antigravity: 'agy',
};

/// The shell command that runs [account]'s CLI in a terminal — the adapter's
/// own [ProviderAdapter.envFor] as an env prefix, so switching accounts is
/// typing a different command instead of re-logging-in (which overwrites the
/// ambient login and is how duplicate identities happen in the first place).
/// For an ambient account this is just the bare binary.
String terminalCommandFor(ProviderAdapter adapter, Account account) {
  final env = adapter.envFor(account);
  final binary = _executables[account.provider]!;
  final prefix =
      env.entries.map((e) => '${e.key}="${e.value}"').join(' ');
  return prefix.isEmpty ? binary : '$prefix $binary';
}

/// The ambient default account candidate for each provider (not yet probed).
/// Each uses `configHome: null` so the CLI runs with no env override — the
/// Keychain-backed default (PRD §7.2). Additional isolated accounts are
/// user-added later (FR-UI-04).
List<Account> defaultCandidateAccounts(
  Iterable<Provider> providers, {
  String deviceId = 'local',
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  return [
    for (final p in providers)
      Account(
        id: '${p.name}-default',
        provider: p,
        label: 'default',
        configHome: null,
        deviceId: deviceId,
        addedAt: at,
      ),
  ];
}

/// Auto-detects each provider's ambient default account (PRD §7.2 FR-RN-01).
///
/// Probes candidates in parallel with each adapter's own `detect()` (no token
/// reads) and returns only the accounts that come back logged in.
Future<List<Account>> discoverDefaultAccounts(
  Map<Provider, ProviderAdapter> adapters, {
  String deviceId = 'local',
  DateTime? now,
}) async {
  final candidates =
      defaultCandidateAccounts(adapters.keys, deviceId: deviceId, now: now);
  final preflights = await Future.wait(
      candidates.map((a) => adapters[a.provider]!.detect(a)));
  return [
    for (var i = 0; i < candidates.length; i++)
      if (preflights[i].isOk) candidates[i],
  ];
}

/// Discovers logged-in accounts paired with their [Preflight] (email, plan —
/// needed for display): each provider's ambient default plus any
/// user-added [Store.extraAccounts] (FR-UI-04), skipping ones the user has
/// removed (persisted in [store]) so a rescan doesn't resurrect them. The one
/// discovery path shared by the Mac GUI engine and the headless runner
/// (PRD §9.2, FR-RN-01/07).
///
/// [includePendingExtras] also returns user-added accounts whose login isn't
/// finished yet (preflight not ok), so a dashboard can show them as
/// actionable "sign in" rows (FR-ER) instead of silently hiding them.
/// Ambient defaults are never included when not ok — that would just render
/// three permanent "not installed" rows. The headless runner keeps the
/// default (false): reading usage or starting sessions on a half-logged-in
/// account is wasted work.
Future<List<(Account, Preflight)>> discoverLiveAccounts(
  Map<Provider, ProviderAdapter> adapters,
  Store store, {
  String deviceId = 'local',
  DateTime? now,
  bool includePendingExtras = false,
}) async {
  final defaults =
      defaultCandidateAccounts(adapters.keys, deviceId: deviceId, now: now);
  final extras = [
    for (final e in store.extraAccounts)
      if (adapters.containsKey(e.provider)) e.toAccount(deviceId: deviceId),
  ];
  final candidates = [...defaults, ...extras];
  final preflights = await Future.wait(
      candidates.map((a) => adapters[a.provider]!.detect(a)));

  // Identity dedupe: accounts are identities, not slots. The ambient
  // default's identity drifts whenever the user re-logs-in in a terminal;
  // if it lands on the same login as an isolated extra, keeping both would
  // show the same account twice (and the runner would chain it twice). The
  // extra wins — it's the stable, user-labeled one.
  final extraIdentities = <(Provider, String)>{
    for (var i = defaults.length; i < candidates.length; i++)
      if (preflights[i].isOk &&
          preflights[i].email != null &&
          !store.isRemoved(candidates[i].id))
        (candidates[i].provider, preflights[i].email!),
  };
  bool duplicatesAnExtra(int i) =>
      i < defaults.length &&
      preflights[i].email != null &&
      extraIdentities.contains((candidates[i].provider, preflights[i].email!));

  return [
    for (var i = 0; i < candidates.length; i++)
      if (!store.isRemoved(candidates[i].id) &&
          !duplicatesAnExtra(i) &&
          (preflights[i].isOk ||
              (includePendingExtras && i >= defaults.length)))
        (candidates[i], preflights[i]),
  ];
}
