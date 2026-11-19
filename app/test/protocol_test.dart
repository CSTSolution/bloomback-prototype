import 'dart:convert';

import 'package:bloomback/band/protocol.dart';
import 'package:bloomback/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LineAssembler', () {
    test('joins chunks and splits on newline', () {
      final a = LineAssembler();
      expect(a.add(utf8.encode('OK ti')), isEmpty);
      expect(a.add(utf8.encode('me\nM 29914200 104 312 1450 0\nC 2991')), ['OK time', 'M 29914200 104 312 1450 0']);
      expect(a.add(utf8.encode('4230 1\n')), ['C 29914230 1']);
    });

    test('a UTF-8 character cut between chunks survives', () {
      final a = LineAssembler();
      final bytes = utf8.encode('OK config Ngủ sớm\n');
      final cut = bytes.indexOf(0xBB) ; // inside "ủ" (E1 BB A7)
      expect(a.add(bytes.sublist(0, cut)), isEmpty);
      expect(a.add(bytes.sublist(cut)), ['OK config Ngủ sớm']);
    });

    test('drops a trailing carriage return', () {
      expect(LineAssembler().add(utf8.encode('END sync 3\r\n')), ['END sync 3']);
    });
  });

  group('parseLine', () {
    test('INFO', () {
      final m = parseLine('INFO {"fw":"0.2.0","board":"c3-oled","battery":87,"days":3,'
          '"time_valid":true,"first_minute":29910000,"last_minute":29914320,"tz":420}');
      expect(m, isA<InfoMsg>());
      final i = m as InfoMsg;
      expect(i.fw, '0.2.0');
      expect(i.battery, 87);
      expect(i.days, 3);
      expect(i.timeValid, isTrue);
      expect(i.firstMinute, 29910000);
      expect(i.lastMinute, 29914320);
      expect(i.tz, 420);
      expect(i.supported, isTrue);
    });

    test('INFO from a newer protocol is refused', () {
      final i = parseLine('INFO {"fw":"1.0.0","battery":-1}') as InfoMsg;
      expect(i.supported, isFalse);
      expect(i.battery, -1);
    });

    test('OK / ERR / BEGIN / END', () {
      expect((parseLine('OK time') as OkMsg).what, 'time');
      expect((parseLine('OK deleted') as OkMsg).what, 'deleted');
      expect((parseLine('ERR time-not-set') as ErrMsg).reason, 'time-not-set');
      expect((parseLine('BEGIN sync') as BeginMsg).what, 'sync');
      final e = parseLine('END sync 1442') as EndMsg;
      expect(e.what, 'sync');
      expect(e.count, 1442);
      expect((parseLine('END') as EndMsg).count, isNull);
    });

    test('M and C records', () {
      final m = (parseLine('M 29914200 104 312 1450 0') as MinuteMsg).rec;
      expect([m.minute, m.steps, m.medDiff, m.maxDiff, m.flags], [29914200, 104, 312, 1450, 0]);
      expect(m.isModerate, isTrue);
      expect(m.isCharging, isFalse);
      final charging = (parseLine('M 29914201 0 0 0 1') as MinuteMsg).rec;
      expect(charging.isCharging, isTrue);
      final c = (parseLine('C 29914230 1') as CheckinMsg).checkin;
      expect(c.minute, 29914230);
      expect(c.status, CheckinStatus.partial);
      expect(c.source, DataSource.watch);
    });

    test('malformed records are not data', () {
      expect(parseLine('M 1 2 3'), isA<OtherMsg>());
      expect(parseLine('M 1 2 3 x 0'), isA<OtherMsg>());
      expect(parseLine('C 29914230 7'), isA<OtherMsg>());
      expect(parseLine('INFO {broken'), isA<OtherMsg>());
    });
  });

  group('Cmd', () {
    test('time / sync / delete', () {
      expect(Cmd.time(DateTime.utc(2026, 11, 13), 420), 'time 1794528000 420\n');
      expect(Cmd.sync(29914200), 'sync 29914200\n');
      expect(Cmd.deleteAll(), 'delete yes\n');
    });

    test('config keeps habit <= 24 chars and the line <= 200 bytes', () {
      final line = Cmd.config(
          habit: 'Straight to bed after the night shift, no chores first',
          r1: 960, r2: 390, qs: 480, qe: 900, de: 1080);
      expect(line.endsWith('\n'), isTrue);
      final j = jsonDecode(line.substring(7)) as Map<String, dynamic>;
      expect((j['habit'] as String).runes.length, lessThanOrEqualTo(24));
      expect(j['r1'], 960);
      expect(j['qs'], 480);
      expect(j['de'], 1080);
      expect(utf8.encode(line).length, lessThanOrEqualTo(200));
    });
  });
}
