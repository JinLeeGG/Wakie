import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

/// API list prices in dollars per million tokens. Cache writes are priced by
/// TTL (5-minute writes bill 1.25× input, 1-hour writes 2×); for OpenAI,
/// [cacheRead] is the cached-input rate and the write rates are zero (cached
/// input is a discount, not a separately billed write).
class ApiRates {
  final double input;
  final double output;
  final double cacheRead;
  final double cacheWrite5m;
  final double cacheWrite1h;
  const ApiRates(
    this.input,
    this.output,
    this.cacheRead, [
    this.cacheWrite5m = 0,
    this.cacheWrite1h = 0,
  ]);
}

// Anthropic sticker prices (cache read = 0.1× input, writes 1.25×/2×).
// Sonnet uses the non-introductory price — this is "what the tokens would
// cost at list price", not a billing reconstruction.
const _fable = ApiRates(10, 50, 1, 12.5, 20);
const _opus = ApiRates(5, 25, .5, 6.25, 10);
const _sonnet = ApiRates(3, 15, .3, 3.75, 6);
const _haiku = ApiRates(1, 5, .1, 1.25, 2);

// OpenAI (gpt-5 family; Codex serves gpt-5.x).
const _gpt = ApiRates(1.25, 10, 0.125);
const _gptMini = ApiRates(0.25, 2, 0.025);
const _gptNano = ApiRates(0.05, 0.4, 0.005);

/// Rates for a Claude model id, matched by family so unreleased point
/// versions still price ("claude-opus-4-9" → opus). Unknown families fall
/// back to opus (the middle tier); non-model ids (`<synthetic>`) get null
/// and are skipped.
ApiRates? claudeRates(String model) {
  final m = model.toLowerCase();
  if (m.contains('fable') || m.contains('mythos')) return _fable;
  if (m.contains('opus')) return _opus;
  if (m.contains('sonnet')) return _sonnet;
  if (m.contains('haiku')) return _haiku;
  if (m.contains('claude')) return _opus;
  return null;
}

/// Rates for an OpenAI model id. Everything Codex runs is gpt-5-family;
/// mini/nano variants get their cheaper tiers.
ApiRates openAiRates(String model) {
  final m = model.toLowerCase();
  if (m.contains('nano')) return _gptNano;
  if (m.contains('mini')) return _gptMini;
  return _gpt;
}

/// One priced slice of usage from a local CLI log. [key] deduplicates
/// entries that appear in several files (Claude Code repeats a message's
/// usage line when a session is continued/branched); null means unique.
class ApiUsageEvent {
  final String? key;
  final DateTime at; // UTC
  final double cost; // dollars
  const ApiUsageEvent({required this.key, required this.at, required this.cost});
}

/// Parses a Claude Code transcript (`~/.claude/projects/**/*.jsonl`) into
/// priced usage events — one per assistant message carrying `usage`.
List<ApiUsageEvent> parseClaudeLog(String content) {
  final events = <ApiUsageEvent>[];
  for (final line in const LineSplitter().convert(content)) {
    // Cheap pre-filter: only assistant messages carry a usage object.
    if (!line.contains('"usage"')) continue;
    final Map<String, dynamic> obj;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map<String, dynamic>) continue;
      obj = decoded;
    } catch (_) {
      continue;
    }
    final msg = obj['message'];
    if (msg is! Map<String, dynamic>) continue;
    final usage = msg['usage'];
    if (usage is! Map<String, dynamic>) continue;
    final model = msg['model'];
    if (model is! String) continue;
    final rates = claudeRates(model);
    if (rates == null) continue;
    final ts = obj['timestamp'];
    final at = ts is String ? DateTime.tryParse(ts) : null;
    if (at == null) continue;

    final input = _n(usage['input_tokens']);
    final output = _n(usage['output_tokens']);
    final cacheRead = _n(usage['cache_read_input_tokens']);
    int write5m = 0, write1h = 0;
    final breakdown = usage['cache_creation'];
    if (breakdown is Map<String, dynamic>) {
      write5m = _n(breakdown['ephemeral_5m_input_tokens']);
      write1h = _n(breakdown['ephemeral_1h_input_tokens']);
    } else {
      // Older entries lack the TTL breakdown; Claude Code writes 1h entries
      // (verified against live logs), so price the aggregate as 1h.
      write1h = _n(usage['cache_creation_input_tokens']);
    }
    final cost = (input * rates.input +
            output * rates.output +
            cacheRead * rates.cacheRead +
            write5m * rates.cacheWrite5m +
            write1h * rates.cacheWrite1h) /
        1e6;

    final id = msg['id'];
    final req = obj['requestId'];
    events.add(ApiUsageEvent(
      key: id is String && req is String ? '$id:$req' : null,
      at: at.toUtc(),
      cost: cost,
    ));
  }
  return events;
}

/// Parses one Codex rollout (`~/.codex/sessions/**/rollout-*.jsonl`) into a
/// single priced event: `token_count` events carry a *cumulative*
/// `total_token_usage`, so the file's last one is the whole session.
List<ApiUsageEvent> parseCodexRollout(String content) {
  String? model;
  Map<String, dynamic>? totals;
  DateTime? at;
  for (final line in const LineSplitter().convert(content)) {
    final isCount = line.contains('"token_count"');
    final isModel = line.contains('"model"');
    if (!isCount && !isModel) continue;
    final Map<String, dynamic> obj;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map<String, dynamic>) continue;
      obj = decoded;
    } catch (_) {
      continue;
    }
    final payload = obj['payload'];
    if (payload is! Map<String, dynamic>) continue;
    final m = payload['model'];
    if (m is String) model = m;
    if (payload['type'] != 'token_count') continue;
    final info = payload['info'];
    if (info is! Map<String, dynamic>) continue;
    final t = info['total_token_usage'];
    if (t is! Map<String, dynamic>) continue;
    totals = t;
    final ts = obj['timestamp'];
    if (ts is String) at = DateTime.tryParse(ts)?.toUtc() ?? at;
  }
  if (totals == null || at == null) return const [];
  final rates = openAiRates(model ?? '');
  final input = _n(totals['input_tokens']);
  final cached = _n(totals['cached_input_tokens']).clamp(0, input);
  // OpenAI counts cached input inside input_tokens; reasoning inside output.
  final cost = ((input - cached) * rates.input +
          cached * rates.cacheRead +
          _n(totals['output_tokens']) * rates.output) /
      1e6;
  return [ApiUsageEvent(key: null, at: at, cost: cost)];
}

int _n(dynamic v) => v is num ? v.toInt() : 0;

class _FileCache {
  final int mtimeMs;
  final int size;
  final List<ApiUsageEvent> events;
  const _FileCache(this.mtimeMs, this.size, this.events);
}

/// Sums the last 7 days of local CLI usage, priced at API list rates.
///
/// Incremental: each file's parsed events are cached against (mtime, size),
/// so a rescan only re-reads files that changed. Parsing itself runs in a
/// short-lived isolate — transcripts can be hundreds of MB and would jank
/// the UI thread.
class ApiValueScanner {
  static const _window = Duration(days: 7);
  final Map<String, _FileCache> _cache = {};

  /// Weekly API-equivalent dollars for one Claude config home
  /// (`~/.claude`, or a sandboxed account's `CLAUDE_CONFIG_DIR`).
  Future<double> claudeWeekly(String configHome, {DateTime? now}) =>
      _weekly('$configHome/projects', _claudeFile, now: now);

  /// Weekly API-equivalent dollars for one Codex home
  /// (`~/.codex`, or a sandboxed account's `CODEX_HOME`).
  Future<double> codexWeekly(String codexHome, {DateTime? now}) =>
      _weekly('$codexHome/sessions', _codexFile, now: now);

  static Future<List<ApiUsageEvent>> _claudeFile(String path) =>
      Isolate.run(() => parseClaudeLog(File(path).readAsStringSync()));

  static Future<List<ApiUsageEvent>> _codexFile(String path) =>
      Isolate.run(() => parseCodexRollout(File(path).readAsStringSync()));

  Future<double> _weekly(
    String root,
    Future<List<ApiUsageEvent>> Function(String path) parse, {
    DateTime? now,
  }) async {
    final cutoff = (now ?? DateTime.now()).toUtc().subtract(_window);
    final dir = Directory(root);
    if (!await dir.exists()) return 0;

    final files = <File>[];
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is File && e.path.endsWith('.jsonl')) files.add(e);
    }

    var total = 0.0;
    final seen = <String>{};
    final keep = <String>{};
    for (final f in files) {
      final FileStat stat;
      try {
        stat = await f.stat();
      } catch (_) {
        continue;
      }
      // A file untouched since the cutoff holds no in-window events.
      if (stat.modified.toUtc().isBefore(cutoff)) continue;
      keep.add(f.path);
      var entry = _cache[f.path];
      if (entry == null ||
          entry.mtimeMs != stat.modified.millisecondsSinceEpoch ||
          entry.size != stat.size) {
        List<ApiUsageEvent> events;
        try {
          events = await parse(f.path);
        } catch (_) {
          events = const [];
        }
        entry = _FileCache(
            stat.modified.millisecondsSinceEpoch, stat.size, events);
        _cache[f.path] = entry;
      }
      for (final ev in entry.events) {
        if (ev.at.isBefore(cutoff)) continue;
        if (ev.key != null && !seen.add(ev.key!)) continue;
        total += ev.cost;
      }
    }
    // Drop cache entries for files that aged out or vanished — but only under
    // this root; the same scanner serves several homes.
    _cache.removeWhere((k, _) => k.startsWith(root) && !keep.contains(k));
    return total;
  }
}
