// Band <-> app protocol v1, exactly as docs/PROTOCOL.md. Pure Dart, unit-tested.
import 'dart:convert';

import '../data/models.dart';

/// Nordic UART Service (docs/PROTOCOL.md "Transport").
class Nus {
  static const service = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const rx = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E'; // app -> band, write
  static const tx = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E'; // band -> app, notify
  static const namePrefix = 'BloomBack-';
  static const mtu = 247;
  static const maxLineBytes = 200;
}

/// Joins notification chunks (up to MTU-3 bytes each) and splits on '\n'.
/// Decodes UTF-8 only once a full line is in, so a multi-byte character cut
/// between two chunks is not broken.
class LineAssembler {
  final List<int> _buf = [];

  /// Adds one chunk; returns the complete lines it finished (without '\n' or '\r').
  List<String> add(List<int> chunk) {
    final out = <String>[];
    for (final b in chunk) {
      if (b == 0x0A) {
        var line = utf8.decode(_buf, allowMalformed: true);
        if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
        _buf.clear();
        out.add(line);
      } else {
        _buf.add(b);
      }
    }
    // A runaway line (no '\n' for far longer than the 200-byte limit) is dropped.
    if (_buf.length > 4096) _buf.clear();
    return out;
  }

  void reset() => _buf.clear();
}

/// One parsed line from the band.
sealed class BandMsg {
  const BandMsg();
}

class InfoMsg extends BandMsg {
  final String fw;
  final String board;
  final int battery; // -1 unknown
  final int days;
  final bool timeValid;
  final int firstMinute;
  final int lastMinute;
  final int tz;
  const InfoMsg({
    required this.fw,
    required this.board,
    required this.battery,
    required this.days,
    required this.timeValid,
    required this.firstMinute,
    required this.lastMinute,
    required this.tz,
  });

  /// Protocol major version the app understands. A band with a newer major
  /// firmware line is refused ("Please update the band"), see PROTOCOL.md "Versioning".
  bool get supported {
    final major = int.tryParse(fw.split('.').first) ?? 0;
    return major == 0;
  }
}

class OkMsg extends BandMsg {
  final String what; // "time", "config", "deleted"
  const OkMsg(this.what);
}

class ErrMsg extends BandMsg {
  final String reason; // unknown, args, time-not-set, busy
  const ErrMsg(this.reason);
}

class BeginMsg extends BandMsg {
  final String what; // "sync", "json", "csv"
  const BeginMsg(this.what);
}

class EndMsg extends BandMsg {
  final String what; // "sync" or "" for exports
  final int? count;
  const EndMsg(this.what, this.count);
}

class MinuteMsg extends BandMsg {
  final MinuteRec rec;
  const MinuteMsg(this.rec);
}

class CheckinMsg extends BandMsg {
  final Checkin checkin;
  const CheckinMsg(this.checkin);
}

class OtherMsg extends BandMsg {
  final String line; // anything else (export body, debug text)
  const OtherMsg(this.line);
}

BandMsg parseLine(String raw) {
  final line = raw.trim();
  if (line.startsWith('INFO ')) {
    try {
      final j = jsonDecode(line.substring(5)) as Map<String, dynamic>;
      return InfoMsg(
        fw: (j['fw'] ?? '') as String,
        board: (j['board'] ?? '') as String,
        battery: (j['battery'] ?? -1) as int,
        days: (j['days'] ?? 0) as int,
        timeValid: (j['time_valid'] ?? false) as bool,
        firstMinute: (j['first_minute'] ?? 0) as int,
        lastMinute: (j['last_minute'] ?? 0) as int,
        tz: (j['tz'] ?? 0) as int,
      );
    } catch (_) {
      return OtherMsg(line);
    }
  }
  final parts = line.split(RegExp(r'\s+'));
  switch (parts.first) {
    case 'OK':
      return OkMsg(parts.length > 1 ? parts[1] : '');
    case 'ERR':
      return ErrMsg(parts.length > 1 ? parts.sublist(1).join(' ') : '');
    case 'BEGIN':
      return BeginMsg(parts.length > 1 ? parts[1] : '');
    case 'END':
      final what = parts.length > 1 ? parts[1] : '';
      final count = parts.length > 2 ? int.tryParse(parts[2]) : null;
      return EndMsg(what, count);
    case 'M':
      if (parts.length == 6) {
        final v = parts.sublist(1).map(int.tryParse).toList();
        if (v.every((x) => x != null && x >= 0)) {
          return MinuteMsg(MinuteRec(v[0]!, v[1]!, v[2]!, v[3]!, v[4]!));
        }
      }
      return OtherMsg(line);
    case 'C':
      if (parts.length == 3) {
        final m = int.tryParse(parts[1]);
        final s = int.tryParse(parts[2]);
        if (m != null && s != null && s >= 0 && s <= 2) {
          return CheckinMsg(Checkin(m, CheckinStatus.values[s], DataSource.watch));
        }
      }
      return OtherMsg(line);
  }
  return OtherMsg(line);
}

/// Command builders. Each returns one line ending in '\n'.
class Cmd {
  static String info() => 'info\n';

  static String time(DateTime nowUtc, int tzMinutes) =>
      'time ${nowUtc.millisecondsSinceEpoch ~/ 1000} $tzMinutes\n';

  static String sync(int sinceMinute) => 'sync $sinceMinute\n';

  static String deleteAll() => 'delete yes\n';

  /// `config {...}`. habit is cut to 24 characters (tiny screen) and the whole
  /// line is kept under the 200-byte limit.
  static String config({
    required String habit,
    required int r1,
    required int r2,
    required int qs,
    required int qe,
    required int de,
  }) {
    var h = habit.runes.length > 24 ? String.fromCharCodes(habit.runes.take(24)) : habit;
    String build() =>
        'config ${jsonEncode({'habit': h, 'r1': r1, 'r2': r2, 'qs': qs, 'qe': qe, 'de': de})}\n';
    var line = build();
    while (utf8.encode(line).length > Nus.maxLineBytes && h.isNotEmpty) {
      h = String.fromCharCodes(h.runes.take(h.runes.length - 1));
      line = build();
    }
    return line;
  }
}
