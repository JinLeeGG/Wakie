import 'provider.dart';

/// A managed account — WakieAI's core unit (PRD §4, §10.1).
///
/// `{provider, label, configHome, device}`. One provider can hold several
/// accounts, each isolated by its own config home.
class Account {
  final String id;
  final Provider provider;
  final String label;

  /// The provider-specific config home used to isolate this account, e.g.
  /// `~/.claude` (`CLAUDE_CONFIG_DIR`). Local-only, never leaves the Mac.
  ///
  /// `null` means the provider's ambient default account — the one the CLI
  /// uses with no env override. For Claude that credential lives in the macOS
  /// Keychain, so setting `CLAUDE_CONFIG_DIR` (even to `~/.claude`) would hide
  /// it; the default account must run with no override.
  final String? configHome;
  final String deviceId;
  final DateTime addedAt;

  const Account({
    required this.id,
    required this.provider,
    required this.label,
    required this.configHome,
    required this.deviceId,
    required this.addedAt,
  });
}
