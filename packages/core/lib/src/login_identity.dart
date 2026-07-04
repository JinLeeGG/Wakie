import 'dart:convert';
import 'dart:io';

/// Cheap "who is signed in right now" readers for the login ledger — plain
/// config-file reads, no subprocess, so the engine can sample every tick.
/// Both return a lowercased email, or null when signed out / unreadable
/// (never throw: an unreadable file is just "unknown").

/// The login email in a Claude config file (`~/.claude.json`, or
/// `<CLAUDE_CONFIG_DIR>/.claude.json` for sandboxed homes).
String? claudeLoginEmail(String claudeJsonPath) {
  try {
    final json =
        jsonDecode(File(claudeJsonPath).readAsStringSync()) as Map<String, dynamic>;
    final oauth = json['oauthAccount'];
    if (oauth is! Map) return null;
    final email = oauth['emailAddress'];
    return email is String ? email.toLowerCase() : null;
  } catch (_) {
    return null;
  }
}

/// The login email in a Codex auth file (`~/.codex/auth.json`, or
/// `<CODEX_HOME>/auth.json`) — decoded from the OAuth id_token's JWT payload.
/// Reads identity only; the tokens themselves are never returned or stored
/// (R0 invariant).
String? codexLoginEmail(String authJsonPath) {
  try {
    final json =
        jsonDecode(File(authJsonPath).readAsStringSync()) as Map<String, dynamic>;
    final tokens = json['tokens'];
    if (tokens is! Map) return null;
    final idToken = tokens['id_token'];
    if (idToken is! String) return null;
    final parts = idToken.split('.');
    if (parts.length < 2) return null;
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final claims = jsonDecode(payload) as Map<String, dynamic>;
    final email = claims['email'];
    return email is String ? email.toLowerCase() : null;
  } catch (_) {
    return null;
  }
}
