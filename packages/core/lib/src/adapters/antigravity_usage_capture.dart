import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'antigravity_usage_parser.dart';
import '../vt.dart';

/// Live pty capture of Antigravity's `/usage` panel (the fragile A1 seam).
///
/// Unlike Claude, the `agy` TUI refuses to render unless it is attached to a
/// real, sized terminal — running it under `script` (a 0×0 pty) makes it drop
/// straight out of its alt-screen and sit idle. So we allocate a proper pty via
/// `openpty` (40×120) and launch `agy` on it with `posix_spawnp`. We do *not*
/// `fork()` the Dart VM (its background threads make a post-fork child
/// deadlock-prone); `posix_spawn` hands the job to the OS cleanly.
///
/// Then, exactly like the Claude seam, it drives `/usage`, polls the rendered
/// screen until the numbers appear, and returns the VT-rendered text (feed to
/// [parseAntigravityUsage]). Not unit-tested — the parser and VT emulator it
/// feeds are.
Future<String> captureAntigravityUsagePanel({
  Map<String, String> env = const {},
  String executable = 'agy',
  Duration maxBoot = const Duration(seconds: 25),
  Duration maxRender = const Duration(seconds: 12),
  Duration poll = const Duration(milliseconds: 200),
}) async {
  final pty = _Pty.spawn(executable, env);
  if (pty == null) return '';

  try {
    // 1. Wait for the input prompt (sign-in can be slow on a cold start, so
    // maxBoot is generous), then open /usage — retrying the whole command,
    // since a keystroke sent a hair early is silently dropped and the panel
    // never opens (the failure that leaves the card stuck "loading").
    await _pollUntil(() => _promptReady.hasMatch(pty.screenText()), maxBoot, poll);
    for (var attempt = 0; attempt < 3; attempt++) {
      pty.write('/usage');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      pty.write('\r');
      if (await _pollUntil(() => _panelOpening.hasMatch(pty.screenText()),
          const Duration(seconds: 3), poll)) {
        break;
      }
    }

    // 2. Wait until the panel's numbers have actually rendered.
    await _pollUntil(() {
      final s = parseAntigravityUsage(pty.screenText());
      return s.session.isKnown || s.weekly.isKnown;
    }, maxRender, poll);

    pty.write('\x1b'); // Esc closes the panel
    pty.write('\x03'); // Ctrl-C to exit
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return pty.screenText();
  } finally {
    pty.dispose();
  }
}

/// Input is only ready once sign-in finishes and the shortcuts hint appears —
/// the banner ("Antigravity CLI") shows earlier, mid sign-in, so keying /usage
/// off that races ahead of the prompt and the command is dropped.
final _promptReady =
    RegExp(r'for shortcuts|Models & Quota', caseSensitive: false);

/// The /usage panel is opening (loading or already showing numbers).
final _panelOpening =
    RegExp(r'Models & Quota|Weekly Limit|remaining', caseSensitive: false);

Future<bool> _pollUntil(
    bool Function() cond, Duration max, Duration poll) async {
  final deadline = DateTime.now().add(max);
  while (DateTime.now().isBefore(deadline)) {
    if (cond()) return true;
    await Future<void>.delayed(poll);
  }
  return cond();
}

// ── pty plumbing (dart:ffi over libSystem; zero external deps) ──────────────

final class _Winsize extends Struct {
  @Uint16()
  external int row;
  @Uint16()
  external int col;
  @Uint16()
  external int xpixel;
  @Uint16()
  external int ypixel;
}

final _lib = DynamicLibrary.process();
final _malloc = _lib.lookupFunction<Pointer<Void> Function(IntPtr),
    Pointer<Void> Function(int)>('malloc');
final _free =
    _lib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
        'free');
final _openpty = _lib.lookupFunction<
    Int32 Function(Pointer<Int32>, Pointer<Int32>, Pointer<Void>,
        Pointer<Void>, Pointer<_Winsize>),
    int Function(Pointer<Int32>, Pointer<Int32>, Pointer<Void>, Pointer<Void>,
        Pointer<_Winsize>)>('openpty');
final _faInit = _lib.lookupFunction<Int32 Function(Pointer<Pointer<Void>>),
    int Function(Pointer<Pointer<Void>>)>('posix_spawn_file_actions_init');
final _faDup2 = _lib.lookupFunction<
    Int32 Function(Pointer<Pointer<Void>>, Int32, Int32),
    int Function(Pointer<Pointer<Void>>, int,
        int)>('posix_spawn_file_actions_adddup2');
final _faClose = _lib.lookupFunction<
    Int32 Function(Pointer<Pointer<Void>>, Int32),
    int Function(
        Pointer<Pointer<Void>>, int)>('posix_spawn_file_actions_addclose');
final _attrInit = _lib.lookupFunction<Int32 Function(Pointer<Pointer<Void>>),
    int Function(Pointer<Pointer<Void>>)>('posix_spawnattr_init');
final _attrFlags = _lib.lookupFunction<
    Int32 Function(Pointer<Pointer<Void>>, Int16),
    int Function(Pointer<Pointer<Void>>, int)>('posix_spawnattr_setflags');
final _spawnp = _lib.lookupFunction<
    Int32 Function(Pointer<Int32>, Pointer<Uint8>, Pointer<Pointer<Void>>,
        Pointer<Pointer<Void>>, Pointer<Pointer<Uint8>>, Pointer<Pointer<Uint8>>),
    int Function(Pointer<Int32>, Pointer<Uint8>, Pointer<Pointer<Void>>,
        Pointer<Pointer<Void>>, Pointer<Pointer<Uint8>>,
        Pointer<Pointer<Uint8>>)>('posix_spawnp');
final _read = _lib.lookupFunction<IntPtr Function(Int32, Pointer<Uint8>, IntPtr),
    int Function(int, Pointer<Uint8>, int)>('read');
final _write = _lib.lookupFunction<
    IntPtr Function(Int32, Pointer<Uint8>, IntPtr),
    int Function(int, Pointer<Uint8>, int)>('write');
final _close =
    _lib.lookupFunction<Int32 Function(Int32), int Function(int)>('close');
// fcntl is variadic; on arm64 the third arg only lands correctly when declared
// with VarArgs (a fixed Int32 signature silently drops O_NONBLOCK → the read
// stays blocking and the poll loop hangs).
final _fcntl = _lib.lookupFunction<Int32 Function(Int32, Int32, VarArgs<(Int32,)>),
    int Function(int, int, int)>('fcntl');
final _kill = _lib
    .lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>('kill');

const _fGetfl = 3, _fSetfl = 4, _oNonblock = 4, _spawnSetsid = 0x0400;

/// Owns one `agy` process running on a pty; reads are non-blocking so the
/// caller can poll from the event loop.
class _Pty {
  final int _fd;
  final int _pid;
  final List<int> _raw = [];
  final Pointer<Uint8> _buf = _malloc(8192).cast<Uint8>();

  _Pty._(this._fd, this._pid);

  static _Pty? spawn(String executable, Map<String, String> env) {
    final ws = _malloc(sizeOf<_Winsize>()).cast<_Winsize>();
    ws.ref
      ..row = 40
      ..col = 120
      ..xpixel = 0
      ..ypixel = 0;
    final amaster = _malloc(4).cast<Int32>();
    final aslave = _malloc(4).cast<Int32>();
    if (_openpty(amaster, aslave, nullptr, nullptr, ws) != 0) return null;
    final master = amaster.value, slave = aslave.value;

    final fa = _malloc(sizeOf<Pointer<Void>>()).cast<Pointer<Void>>();
    _faInit(fa);
    _faClose(fa, master);
    _faDup2(fa, slave, 0);
    _faDup2(fa, slave, 1);
    _faDup2(fa, slave, 2);
    _faClose(fa, slave);
    final attr = _malloc(sizeOf<Pointer<Void>>()).cast<Pointer<Void>>();
    _attrInit(attr);
    _attrFlags(attr, _spawnSetsid);

    final merged = {
      ...Platform.environment,
      'TERM': 'xterm-256color',
      ...env,
    };
    final path = _cstr(executable);
    final argv = _carr([executable]);
    final envp =
        _carr([for (final e in merged.entries) '${e.key}=${e.value}']);
    final pidp = _malloc(4).cast<Int32>();

    final rc = _spawnp(pidp, path, fa, attr, argv, envp);
    _close(slave);
    _free(ws.cast());
    _free(amaster.cast());
    _free(aslave.cast());
    if (rc != 0) {
      _close(master);
      return null;
    }
    final pid = pidp.value;
    final fl = _fcntl(master, _fGetfl, 0);
    _fcntl(master, _fSetfl, fl | _oNonblock);
    return _Pty._(master, pid);
  }

  /// Drains whatever the pty has produced, then returns the VT-rendered screen.
  String screenText() {
    // Drain what's buffered, but cap the burst so a continuously-animating TUI
    // can never wedge this synchronous loop — the next poll picks up the rest.
    for (var reads = 0; reads < 512; reads++) {
      final n = _read(_fd, _buf, 8192);
      if (n <= 0) break;
      for (var i = 0; i < n; i++) {
        _raw.add(_buf[i]);
      }
    }
    return (VtScreen()..write(utf8.decode(_raw, allowMalformed: true))).text;
  }

  void write(String s) {
    final p = _cstr(s);
    _write(_fd, p, utf8.encode(s).length);
    _free(p.cast());
  }

  void dispose() {
    _kill(_pid, 15); // SIGTERM
    _close(_fd);
    _free(_buf.cast());
  }
}

Pointer<Uint8> _cstr(String s) {
  final b = utf8.encode(s);
  final p = _malloc(b.length + 1).cast<Uint8>();
  for (var i = 0; i < b.length; i++) {
    p[i] = b[i];
  }
  p[b.length] = 0;
  return p;
}

Pointer<Pointer<Uint8>> _carr(List<String> items) {
  final p = _malloc((items.length + 1) * sizeOf<Pointer<Uint8>>())
      .cast<Pointer<Uint8>>();
  for (var i = 0; i < items.length; i++) {
    p[i] = _cstr(items[i]);
  }
  p[items.length] = nullptr;
  return p;
}
