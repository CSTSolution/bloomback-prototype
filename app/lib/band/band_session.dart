// The protocol client: what the app does on every connect (time, info, config,
// sync <last saved minute>), over any BandTransport. Pure Dart, unit-tested with FakeBand.
import 'dart:async';

import '../data/models.dart';
import 'band_link.dart';
import 'protocol.dart';

class BandException implements Exception {
  final String message;
  BandException(this.message);
  @override
  String toString() => message;
}

class SyncResult {
  final InfoMsg info;
  final List<MinuteRec> minutes;
  final List<Checkin> checkins;
  const SyncResult(this.info, this.minutes, this.checkins);

  /// New sync cursor: the last minute record saved (check-ins are keyed by minute
  /// and re-saving one is harmless).
  int? get lastMinute => minutes.isEmpty ? null : minutes.last.minute;
}

class BandConfig {
  final String habit;
  final Settings settings;
  const BandConfig(this.habit, this.settings);
}

class BandSession {
  final BandTransport t;
  final Duration timeout;
  BandSession(this.t, {this.timeout = const Duration(seconds: 20)});

  /// Sends [cmd] and waits for the first line [match] accepts. ERR lines throw.
  Future<BandMsg> _request(String cmd, bool Function(BandMsg) match) async {
    final c = Completer<BandMsg>();
    late StreamSubscription<String> sub;
    sub = t.lines.listen((line) {
      final m = parseLine(line);
      if (c.isCompleted) return;
      if (m is ErrMsg) {
        c.completeError(BandException('Band answered ERR ${m.reason} to "${cmd.trim()}"'));
      } else if (match(m)) {
        c.complete(m);
      }
    });
    try {
      await t.send(cmd);
      return await c.future.timeout(timeout,
          onTimeout: () => throw BandException('No answer to "${cmd.trim()}"'));
    } finally {
      await sub.cancel();
    }
  }

  Future<InfoMsg> info() async => (await _request(Cmd.info(), (m) => m is InfoMsg)) as InfoMsg;

  Future<void> setTime(DateTime nowUtc, int tzMinutes) =>
      _request(Cmd.time(nowUtc, tzMinutes), (m) => m is OkMsg && m.what == 'time');

  Future<void> setConfig(BandConfig cfg) => _request(
      Cmd.config(
        habit: cfg.habit,
        r1: cfg.settings.reminder1,
        r2: cfg.settings.reminder2,
        qs: cfg.settings.quietStart,
        qe: cfg.settings.quietEnd,
        de: cfg.settings.dayEnd,
      ),
      (m) => m is OkMsg && m.what == 'config');

  Future<void> deleteOnBand() =>
      _request(Cmd.deleteAll(), (m) => m is OkMsg && m.what == 'deleted');

  /// `sync <since>`: collects M and C records between `BEGIN sync` and `END sync <count>`.
  /// If the count does not match, nothing is returned (the cursor does not move).
  Future<(List<MinuteRec>, List<Checkin>)> sync(int since,
      {void Function(int received)? onProgress}) async {
    final minutes = <MinuteRec>[];
    final checkins = <Checkin>[];
    final done = Completer<int>();
    var begun = false;
    Timer? idle;
    void arm() {
      idle?.cancel();
      idle = Timer(timeout, () {
        if (!done.isCompleted) done.completeError(BandException('Sync stopped half way'));
      });
    }

    final sub = t.lines.listen((line) {
      if (done.isCompleted) return;
      final m = parseLine(line);
      arm();
      switch (m) {
        case ErrMsg(:final reason):
          done.completeError(BandException('Band answered ERR $reason to sync'));
        case BeginMsg(:final what) when what == 'sync':
          begun = true;
        case MinuteMsg(:final rec) when begun:
          minutes.add(rec);
          if (onProgress != null && minutes.length % 500 == 0) onProgress(minutes.length);
        case CheckinMsg(:final checkin) when begun:
          checkins.add(checkin);
        case EndMsg(:final what, :final count) when what == 'sync' && begun:
          done.complete(count ?? -1);
        default:
          break;
      }
    });
    try {
      arm();
      await t.send(Cmd.sync(since));
      final count = await done.future;
      if (count != minutes.length + checkins.length) {
        throw BandException('Sync count mismatch: band said $count, got '
            '${minutes.length + checkins.length}. Nothing saved; please sync again.');
      }
      minutes.sort((a, b) => a.minute.compareTo(b.minute));
      return (minutes, checkins);
    } finally {
      idle?.cancel();
      await sub.cancel();
    }
  }

  /// Everything the app does on every connect (PROTOCOL.md): time, info, config, sync.
  Future<SyncResult> onConnect({
    required DateTime nowUtc,
    required int tzMinutes,
    required BandConfig config,
    required int sinceMinute,
    void Function(String step)? onStep,
  }) async {
    onStep?.call('time');
    await setTime(nowUtc, tzMinutes);
    onStep?.call('info');
    final i = await info();
    if (!i.supported) throw BandException('Please update the band (firmware ${i.fw}).');
    onStep?.call('config');
    await setConfig(config);
    onStep?.call('sync');
    final (m, c) = await sync(sinceMinute, onProgress: (n) => onStep?.call('sync $n'));
    return SyncResult(i, m, c);
  }
}
