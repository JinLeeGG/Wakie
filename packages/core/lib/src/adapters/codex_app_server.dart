import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Reads Codex account rate limits over the `codex app-server` JSON-RPC surface.
///
/// Spawns `codex app-server` (stdio transport), performs the `initialize`
/// handshake, then calls `account/rateLimits/read` and returns its `result`
/// object (feed to `parseCodexRateLimits`). This is Codex's robust, structured
/// alternative to scraping the interactive `/status` TUI. Returns null on
/// timeout / launch failure / missing result so `readStatus` degrades to
/// "unknown" rather than throwing (FR-ER). Official binary only, no token
/// extraction (R0). Not unit-tested — the pure parser it feeds is.
Future<Map<String, dynamic>?> readCodexRateLimits({
  Map<String, String> env = const {},
  String executable = 'codex',
  Duration timeout = const Duration(seconds: 15),
}) async {
  final Process proc;
  try {
    proc = await Process.start(executable, ['app-server'], environment: env);
  } on ProcessException {
    return null;
  }

  final result = Completer<Map<String, dynamic>?>();
  void send(Object message) {
    proc.stdin.write(jsonEncode(message));
    proc.stdin.write('\n');
  }

  final sub = proc.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
    if (line.trim().isEmpty) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      return; // skip any non-JSON banner line
    }
    if (decoded is! Map<String, dynamic>) return;

    // Response to initialize (id:1) → now ask for rate limits.
    if (decoded['id'] == 1) {
      send({'id': 2, 'method': 'account/rateLimits/read', 'params': null});
      proc.stdin.flush();
      return;
    }
    // Response to rateLimits/read (id:2).
    if (decoded['id'] == 2 && !result.isCompleted) {
      final r = decoded['result'];
      result.complete(r is Map<String, dynamic> ? r : null);
    }
  });
  proc.stderr.drain<void>();

  send({
    'id': 1,
    'method': 'initialize',
    'params': {
      'clientInfo': {'name': 'wakie', 'version': '0.1.0'},
    },
  });
  await proc.stdin.flush();

  try {
    return await result.future.timeout(timeout);
  } on TimeoutException {
    return null;
  } finally {
    await sub.cancel();
    proc.kill();
  }
}

/// Reads the signed-in account's identity (email + plan) over the same
/// `codex app-server` surface, via `account/read`. Returns the `account`
/// object — `{type, email, planType}` — or null on failure. Identity only,
/// never the token (R0): the response's auth token is never requested here.
Future<Map<String, dynamic>?> readCodexAccount({
  Map<String, String> env = const {},
  String executable = 'codex',
  Duration timeout = const Duration(seconds: 15),
}) async {
  final Process proc;
  try {
    proc = await Process.start(executable, ['app-server'], environment: env);
  } on ProcessException {
    return null;
  }

  final result = Completer<Map<String, dynamic>?>();
  void send(Object message) {
    proc.stdin.write(jsonEncode(message));
    proc.stdin.write('\n');
  }

  final sub = proc.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
    if (line.trim().isEmpty) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;

    // `account/read` requires a params object (null is rejected).
    if (decoded['id'] == 1) {
      send({'id': 2, 'method': 'account/read', 'params': <String, dynamic>{}});
      proc.stdin.flush();
      return;
    }
    if (decoded['id'] == 2 && !result.isCompleted) {
      final r = decoded['result'];
      final account = r is Map<String, dynamic> ? r['account'] : null;
      result.complete(account is Map<String, dynamic> ? account : null);
    }
  });
  proc.stderr.drain<void>();

  send({
    'id': 1,
    'method': 'initialize',
    'params': {
      'clientInfo': {'name': 'wakie', 'version': '0.1.0'},
    },
  });
  await proc.stdin.flush();

  try {
    return await result.future.timeout(timeout);
  } on TimeoutException {
    return null;
  } finally {
    await sub.cancel();
    proc.kill();
  }
}
