/// A minimal VT/ANSI screen emulator: replays a terminal byte stream into a
/// character grid and reads it back as plain text.
///
/// Interactive CLIs (e.g. Claude's `/usage`) lay text out with cursor-movement
/// escapes rather than literal spaces, so naive escape-stripping glues or drops
/// characters. Replaying the moves into a grid recovers the on-screen text
/// faithfully. Supports only what these panels emit — relative cursor moves
/// (CUU/CUD/CUF/CUB), absolute positioning (CUP), and erase-line/display —
/// ignoring styling (SGR), mode, and OSC sequences.
class VtScreen {
  final List<List<String>> _grid = [];
  int _row = 0;
  int _col = 0;
  int _savedRow = 0;
  int _savedCol = 0;

  void _ensure(int row, int col) {
    while (_grid.length <= row) {
      _grid.add([]);
    }
    final line = _grid[row];
    while (line.length <= col) {
      line.add(' ');
    }
  }

  void _put(String ch) {
    _ensure(_row, _col);
    _grid[_row][_col] = ch;
    _col++;
  }

  /// Feed a decoded chunk of terminal output.
  void write(String data) {
    final runes = data.runes.toList();
    var i = 0;
    while (i < runes.length) {
      final r = runes[i];
      if (r == 0x1b) {
        i = _handleEscape(runes, i + 1);
        continue;
      }
      switch (r) {
        case 0x0d: // CR
          _col = 0;
        case 0x0a: // LF
          _row++;
        case 0x08: // BS
          if (_col > 0) _col--;
        case 0x09: // TAB → next 8-col stop
          _col += 8 - (_col % 8);
        default:
          if (r >= 0x20) _put(String.fromCharCode(r));
      }
      i++;
    }
  }

  /// Handles the escape starting after ESC; returns the next index to read.
  int _handleEscape(List<int> runes, int i) {
    if (i >= runes.length) return i;
    final kind = runes[i];

    if (kind == 0x5d) {
      // OSC: ESC ] ... (BEL | ESC \)
      i++;
      while (i < runes.length && runes[i] != 0x07) {
        if (runes[i] == 0x1b && i + 1 < runes.length && runes[i + 1] == 0x5c) {
          return i + 2;
        }
        i++;
      }
      return i + 1;
    }

    if (kind == 0x37) {
      // DECSC: save cursor.
      _savedRow = _row;
      _savedCol = _col;
      return i + 1;
    }
    if (kind == 0x38) {
      // DECRC: restore cursor.
      _row = _savedRow;
      _col = _savedCol;
      return i + 1;
    }

    if (kind != 0x5b) {
      // Non-CSI escape (e.g. charset selection) — skip one byte.
      return i + 1;
    }

    // CSI: ESC [ params... final
    i++;
    final params = StringBuffer();
    while (i < runes.length && runes[i] >= 0x20 && runes[i] < 0x40) {
      params.write(String.fromCharCode(runes[i]));
      i++;
    }
    if (i >= runes.length) return i;
    _applyCsi(String.fromCharCode(runes[i]), params.toString());
    return i + 1;
  }

  void _applyCsi(String finalByte, String params) {
    int arg([int fallback = 1]) {
      final n = int.tryParse(params.split(';').first);
      return (n == null || n == 0) ? fallback : n;
    }

    switch (finalByte) {
      case 'A': // cursor up
        _row = (_row - arg()).clamp(0, 1 << 30);
      case 'B': // cursor down
        _row += arg();
      case 'C': // cursor forward
        _col += arg();
      case 'D': // cursor back
        _col = (_col - arg()).clamp(0, 1 << 30);
      case 'G': // cursor horizontal absolute (1-based column)
        _col = (arg() - 1).clamp(0, 1 << 30);
      case 'H': // cursor position (row;col, 1-based)
      case 'f':
        final parts = params.split(';');
        _row = (int.tryParse(parts.first) ?? 1) - 1;
        _col = (parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1) - 1;
        if (_row < 0) _row = 0;
        if (_col < 0) _col = 0;
      case 'K': // erase in line: 0=to end (default), 1=to start, 2=whole
        _eraseLine(arg(0));
      case 'J': // erase in display: 2=whole screen
        if (arg(0) == 2) _grid.clear();
      default:
        break; // SGR (m), modes (h/l), device attrs, etc. — ignore.
    }
  }

  void _eraseLine(int mode) {
    if (_row >= _grid.length) return;
    final line = _grid[_row];
    if (mode == 2) {
      _grid[_row] = [];
    } else if (mode == 1) {
      for (var c = 0; c <= _col && c < line.length; c++) {
        line[c] = ' ';
      }
    } else {
      for (var c = _col; c < line.length; c++) {
        line[c] = ' ';
      }
    }
  }

  /// The rendered screen as text, trailing whitespace trimmed per line.
  String get text =>
      _grid.map((line) => line.join().replaceFirst(RegExp(r'\s+$'), '')).join('\n');
}

/// Convenience: render a full terminal byte stream to text in one call.
String renderVt(String data) => (VtScreen()..write(data)).text;
