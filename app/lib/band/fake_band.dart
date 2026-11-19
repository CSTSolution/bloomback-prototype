// A pretend band that speaks the same protocol, so the whole app is demo-able
// without hardware. Synthetic data only: persona Ravi from the rules PDF (C7):
// fixed night shift, standing / light walking at work, indoors, about 5.5 h of
// day sleep, about 60 min of brisk walking a week, some partial check-ins.
// In the second week his sleep and walking get a little better, so the Week
// screen has something to compare.
import 'dart:async';
import 'dart:convert';

import 'band_link.dart';
import 'protocol.dart';

class FakeBandLink implements BandLink {
  final DateTime Function() now;
  final int historyDays;

  /// Demo scenarios (lib/demo/scenarios.dart): the band's data starts here
  /// instead of [historyDays] before now.
  final int? firstMinute;

  /// Demo scenarios: the band check-in for a local day (days since 1970 in the
  /// band's zone): 0 done, 1 partly, 2 not today, -1 none. Days not listed use
  /// Ravi's usual pattern ([RaviModel.checkin]).
  final Map<int, int> checkinScript;
  FakeBandState? _state;

  FakeBandLink({DateTime Function()? now, this.historyDays = 14, this.firstMinute, this.checkinScript = const {}})
      : now = now ?? DateTime.now;

  FakeBandState get state => _state ??= FakeBandState(
        firstMinute: firstMinute ?? now().toUtc().millisecondsSinceEpoch ~/ 60000 - historyDays * 1440,
        tzMinutes: now().timeZoneOffset.inMinutes,
        checkinScript: checkinScript,
      );

  @override
  bool get isFake => true;

  @override
  Stream<List<FoundBand>> scan({Duration timeout = const Duration(seconds: 10)}) async* {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    yield const [FoundBand('fake', 'BloomBack-DEMO', -48)];
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<BandTransport> connect(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return FakeTransport(state, now);
  }

  @override
  Future<bool> forget(String id) async => true;
}

/// What the pretend band keeps between connections.
class FakeBandState {
  int firstMinute; // data starts here (moves forward on "delete yes")
  int tzMinutes;
  String habit = '';
  Map<String, dynamic> config = {};
  final Map<int, int> checkinScript;
  FakeBandState({required this.firstMinute, required this.tzMinutes, this.checkinScript = const {}});

  /// The check-in tapped on the band at minute [m], or null.
  int? checkin(int m) => RaviModel.checkin(m, tzMinutes, script: checkinScript);
}

class FakeTransport implements BandTransport {
  final FakeBandState s;
  final DateTime Function() now;
  final _out = StreamController<String>.broadcast();
  final _closed = Completer<void>();
  final _asm = LineAssembler();
  bool _timeSet = false;

  FakeTransport(this.s, this.now);

  int get _nowMinute => now().toUtc().millisecondsSinceEpoch ~/ 60000;

  @override
  Stream<String> get lines => _out.stream;

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<void> close() async {
    if (!_closed.isCompleted) _closed.complete();
    await _out.close();
  }

  void _emit(String line) {
    if (!_out.isClosed) _out.add(line);
  }

  @override
  Future<void> send(String line) async {
    // Same path as BLE: bytes -> line assembler -> command.
    for (final cmd in _asm.add(utf8.encode(line))) {
      // Answer after the caller has started listening.
      scheduleMicrotask(() => _handle(cmd.trim()));
    }
  }

  Future<void> _handle(String cmd) async {
    final parts = cmd.split(' ');
    switch (parts.first) {
      case 'info':
        final last = _nowMinute - 1;
        _emit('INFO ${jsonEncode({
              'fw': '0.2.0',
              'board': 'fake',
              'battery': 87,
              'days': ((last - s.firstMinute) / 1440).ceil().clamp(0, 60),
              'time_valid': _timeSet,
              'first_minute': s.firstMinute,
              'last_minute': last,
              'tz': s.tzMinutes,
            })}');
      case 'time':
        if (parts.length != 3 || int.tryParse(parts[1]) == null || int.tryParse(parts[2]) == null) {
          _emit('ERR args');
          return;
        }
        s.tzMinutes = int.parse(parts[2]);
        _timeSet = true;
        _emit('OK time');
      case 'config':
        try {
          final j = jsonDecode(cmd.substring(7)) as Map<String, dynamic>;
          s.config.addAll(j);
          s.habit = (s.config['habit'] ?? '') as String;
          _emit('OK config');
        } catch (_) {
          _emit('ERR args');
        }
      case 'sync':
        final since = parts.length == 2 ? int.tryParse(parts[1]) : null;
        if (since == null) {
          _emit('ERR args');
          return;
        }
        if (!_timeSet) {
          _emit('ERR time-not-set');
          return;
        }
        await _sync(since);
      case 'delete':
        if (parts.length == 2 && parts[1] == 'yes') {
          s.firstMinute = _nowMinute;
          _emit('OK deleted');
        } else {
          _emit('ERR args');
        }
      default:
        _emit('ERR unknown');
    }
  }

  Future<void> _sync(int since) async {
    _emit('BEGIN sync');
    final from = (since + 1) > s.firstMinute ? since + 1 : s.firstMinute;
    final to = _nowMinute; // the current minute is still open
    var count = 0;
    for (var m = from; m < to; m++) {
      final r = RaviModel.minute(m, s.tzMinutes, s.firstMinute);
      _emit('M $m ${r.$1} ${r.$2} ${r.$3} ${r.$4}');
      count++;
      final c = s.checkin(m);
      if (c != null) {
        _emit('C $m $c');
        count++;
      }
      if (count % 400 == 0) await Future<void>.delayed(Duration.zero);
    }
    _emit('END sync $count');
  }
}

/// Deterministic synthetic minutes for persona Ravi (no real person's data).
class RaviModel {
  static double _r(int m, int salt) {
    var x = (m * 2654435761 + salt * 40503) & 0x7fffffff;
    x = (x ^ (x >> 13)) * 1274126177 & 0x7fffffff;
    x = x ^ (x >> 16);
    return (x % 100000) / 100000.0;
  }

  static int _dayIndex(int localMinute) => localMinute ~/ 1440;

  /// (steps, medDiff, maxDiff, flags) for UTC minute [m].
  static (int, int, int, int) minute(int m, int tz, int firstMinute) {
    final local = m + tz;
    final day = _dayIndex(local);
    final mod = local % 1440;
    final week = ((m - firstMinute) ~/ (7 * 1440)).clamp(0, 9);
    final dayOff = day % 7 == 2 || day % 7 == 3; // two nights off a week

    // Sleep: day sleep after the night shift; a normal night on days off.
    // Week 1 ~5.5 h, then the plan's step (+30 min) starts to show.
    final extra = week >= 1 ? 25 + (_r(day, 7) * 10).round() : 0;
    final jitter = (_r(day, 3) * 30).round() - 15;
    final sleepStart = dayOff ? 60 + jitter : 8 * 60 + 15 + jitter; // 01:00 or 08:15
    final sleepLen = (dayOff ? 390 : 330) + extra;
    final inSleep = mod >= sleepStart && mod < sleepStart + sleepLen;

    // On the charger 18:00-18:40 every day: never counted as sleep.
    if (mod >= 18 * 60 && mod < 18 * 60 + 40) return (0, 0, 0, 1);

    if (inSleep) {
      final turn = _r(m, 11) < 0.04; // turning over now and then
      final bathroom = !dayOff && _r(day, 13) < 0.3 && mod >= sleepStart + 150 && mod < sleepStart + 162;
      if (bathroom) return ((_r(m, 5) * 60).round(), 600, 3000, 0);
      return (0, (_r(m, 1) * 5).floor(), turn ? 800 : 50 + (_r(m, 2) * 200).floor(), 0);
    }

    // Awake. Brisk walks (>= 100 steps/min): ~60 min/week in week 1, ~75 later.
    final walkDays = week >= 1 ? const [0, 1, 4, 5] : const [0, 1, 4];
    final walkLen = week >= 1 ? 19 : 20;
    final walkStart = 16 * 60 + 30;
    if (walkDays.contains(day % 7) && mod >= walkStart && mod < walkStart + walkLen) {
      return (104 + (_r(m, 4) * 18).round(), 900, 2400, 0);
    }
    // Night shift 22:00-07:00 standing / light walking (not moderate).
    final onShift = !dayOff && (mod >= 22 * 60 || mod < 7 * 60);
    final steps = onShift
        ? (_r(m, 6) < 0.45 ? 20 + (_r(m, 8) * 60).round() : (_r(m, 9) * 10).round())
        : (_r(m, 6) < 0.2 ? 10 + (_r(m, 8) * 50).round() : 0);
    final med = 200 + (_r(m, 10) * 1800).round();
    return (steps, med, med + 1000, 0);
  }

  /// A check-in Ravi tapped on the band at 15:00 local on some days, or null.
  /// Mostly "done", sometimes "partly", now and then "not today".
  /// [script] (demo scenarios) fixes the answer for some days: -1 = none.
  static int? checkin(int m, int tz, {Map<int, int> script = const {}}) {
    final local = m + tz;
    if (local % 1440 != 15 * 60) return null;
    final day = _dayIndex(local);
    final fixed = script[day];
    if (fixed != null) return fixed < 0 ? null : fixed;
    final r = _r(day, 21);
    if (r < 0.35) return null; // answered in the app or not at all
    if (r < 0.70) return 0;
    if (r < 0.90) return 1;
    return 2;
  }
}
