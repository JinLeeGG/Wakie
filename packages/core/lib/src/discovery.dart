import 'account.dart';
import 'adapter.dart';
import 'provider.dart';

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
