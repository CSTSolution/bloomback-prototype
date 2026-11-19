import 'dart:async';

import 'package:bloomback/band/band_link.dart';
import 'package:bloomback/band/band_session.dart';
import 'package:bloomback/band/fake_band.dart';
import 'package:bloomback/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// A transport that answers with fixed lines (for broken-band cases).
class ScriptTransport implements BandTransport {
  final List<String> Function(String cmd) answer;
  final _c = StreamController<String>.broadcast();
  ScriptTransport(this.answer);
  @override
  Stream<String> get lines => _c.stream;
  @override
  Future<void> send(String line) async =>
      scheduleMicrotask(() => answer(line.trim()).forEach(_c.add));
  @override
  Future<void> get closed => Completer<void>().future;
  @override
  Future<void> close() => _c.close();
}

void main() {
  var now = DateTime.utc(2026, 11, 13, 10, 0);
  final link = FakeBandLink(now: () => now, historyDays: 3);
  final cfg = BandConfig('Home, then bed', Settings());

  test('on connect: time, info, config, sync; then only new records', () async {
    final t = await link.connect('fake');
    final steps = <String>[];
    final r = await BandSession(t).onConnect(
      nowUtc: now,
      tzMinutes: 420,
      config: cfg,
      sinceMinute: 0,
      onStep: steps.add,
    );
    expect(steps.take(4), ['time', 'info', 'config', 'sync']);
    expect(r.info.timeValid, isTrue);
    expect(link.state.habit, 'Home, then bed');
    expect(r.minutes.length, 3 * 1440);
    expect(r.checkins.every((c) => c.source == DataSource.watch), isTrue);
    // Minutes are in order and contiguous.
    for (var i = 1; i < r.minutes.length; i++) {
      expect(r.minutes[i].minute, r.minutes[i - 1].minute + 1);
    }
    final cursor = r.lastMinute!;
    expect(cursor, now.millisecondsSinceEpoch ~/ 60000 - 1);

    now = now.add(const Duration(minutes: 10));
    final again = await BandSession(t).sync(cursor);
    expect(again.$1.length, 10);
    expect(again.$1.first.minute, cursor + 1);
    await t.close();
  });

  test('delete yes wipes the band', () async {
    final t = await link.connect('fake');
    final session = BandSession(t);
    await session.setTime(now, 420);
    await session.deleteOnBand();
    final (m, c) = await session.sync(0);
    expect(m, isEmpty);
    expect(c, isEmpty);
    await t.close();
  });

  test('ERR from the band becomes an error', () async {
    final t = ScriptTransport((cmd) => ['ERR time-not-set']);
    expect(BandSession(t).sync(0), throwsA(isA<BandException>()));
  });

  test('count mismatch saves nothing', () async {
    final t = ScriptTransport((cmd) => ['BEGIN sync', 'M 100 0 1 50 0', 'END sync 2']);
    expect(BandSession(t).sync(0), throwsA(isA<BandException>()));
  });

  test('newer firmware protocol is refused', () async {
    final t = ScriptTransport((cmd) => cmd.startsWith('time')
        ? ['OK time']
        : cmd == 'info'
            ? ['INFO {"fw":"1.0.0"}']
            : []);
    expect(
      BandSession(t).onConnect(nowUtc: now, tzMinutes: 0, config: cfg, sinceMinute: 0),
      throwsA(isA<BandException>()),
    );
  });
}
