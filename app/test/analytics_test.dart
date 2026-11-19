// Same synthetic cases as wearable/test/test_core/test_main.cpp.
import 'package:bloomback/analytics/daily.dart';
import 'package:bloomback/analytics/fhir.dart';
import 'package:bloomback/analytics/sleep.dart';
import 'package:bloomback/band/fake_band.dart';
import 'package:bloomback/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deterministic stand-in for C rand().
class Rng {
  int _x;
  Rng(this._x);
  int next() => _x = (_x * 1103515245 + 12345) & 0x7fffffff;
}

/// 24 h of minutes: awake (big angle changes) except a still block.
List<MinuteRec> day(int start, int sleepFrom, int sleepLen, int wakeBlip, {int flagsInSleep = 0}) {
  final r = Rng(4);
  final v = <MinuteRec>[];
  for (var i = 0; i < 1440; i++) {
    var steps = 0, med = 0, mx = 0, flags = 0;
    final asleep = i >= sleepFrom && i < sleepFrom + sleepLen;
    if (asleep) {
      med = r.next() % 5; // < 0.05 deg
      mx = 50 + r.next() % 200;
      flags = flagsInSleep;
      if (wakeBlip > 0 && i >= sleepFrom + wakeBlip && i < sleepFrom + wakeBlip + 20) {
        med = 600; // 20-minute wake in the middle (bathroom)
        mx = 3000;
      }
    } else {
      med = 200 + r.next() % 2000;
      mx = med + 1000;
      steps = (i % 60 < 10) ? 110 : 5;
    }
    v.add(MinuteRec(start + i, steps, med, mx, flags));
  }
  return v;
}

void main() {
  const start = 29000000;

  test('7 h night block is found within 5 min', () {
    final s = detectMainSleep(day(start, 900, 420, 0));
    expect(s.found, isTrue);
    expect((s.startMinute - (start + 900)).abs(), lessThanOrEqualTo(5));
    expect((s.endMinute - (start + 1320)).abs(), lessThanOrEqualTo(5));
    expect((s.sleepMinutes - 420).abs(), lessThanOrEqualTo(10));
  });

  test('a 20-min wake inside is joined into one window', () {
    final s = detectMainSleep(day(start, 600, 400, 200));
    expect(s.found, isTrue);
    expect((s.startMinute - (start + 600)).abs(), lessThanOrEqualTo(5));
    expect((s.endMinute - (start + 1000)).abs(), lessThanOrEqualTo(5));
    expect(s.sleepMinutes, lessThan(390));
  });

  test('charging minutes never count as sleep', () {
    final s = detectMainSleep(day(start, 900, 420, 0, flagsInSleep: MinuteRec.charging));
    expect(s.found, isFalse);
  });

  test('a gap in the data breaks blocks', () {
    final v = day(start, 900, 420, 0)..removeRange(1100, 1180); // band off 80 min
    final s = detectMainSleep(v);
    expect(s.found, isTrue);
    expect(s.endMinute - s.startMinute, lessThan(300));
  });

  test('too little data finds nothing', () {
    expect(detectMainSleep(day(start, 0, 20, 0).sublist(0, 20)).found, isFalse);
  });

  test('day summary: steps, moderate minutes, sleep in the 24 h ending at day end', () {
    // Local day starting at UTC minute `dayStart` (tz 0 for simplicity).
    const tz = 0;
    final d0 = localDay(start, tz);
    final s0 = dayStartMinute(d0, tz);
    // Previous day 18:00 .. this day 18:00 is the sleep window; put sleep 23:00-06:00.
    final recs = day(s0 - 1440, 0, 0, 0) + day(s0, 0, 0, 0);
    final withSleep = [
      for (final r in recs)
        (r.minute >= s0 - 60 && r.minute < s0 + 360) ? MinuteRec(r.minute, 0, 1, 80, 0) : r
    ];
    final sum = summarizeDay(withSleep, d0, tz, 18 * 60);
    expect(sum.moderateMinutes, (24 - 6) * 10); // 10 min an hour at 110 steps, none in the 6 sleep hours
    expect(sum.sleep.found, isTrue);
    expect((sum.sleep.startMinute - (s0 - 60)).abs(), lessThanOrEqualTo(5));
    expect((sum.sleep.endMinute - (s0 + 360)).abs(), lessThanOrEqualTo(5));
  });

  test('FakeBand Ravi: ~5.5 h day sleep after the night shift, charging excluded', () {
    const tz = 240; // Abu Dhabi
    final first = 1794528000 ~/ 60 - 14 * 1440;
    final recs = [
      for (var m = first; m < first + 14 * 1440; m++)
        () {
          final r = RaviModel.minute(m, tz, first);
          return MinuteRec(m, r.$1, r.$2, r.$3, r.$4);
        }()
    ];
    final d0 = localDay(first, tz) + 1;
    final days = summarizeDays(recs, d0, d0 + 12, tz, 18 * 60);
    final nights = days.where((d) => d.sleep.found).toList();
    expect(nights.length, greaterThanOrEqualTo(11));
    final week1 = nights.where((d) => d.day < d0 + 6).map((d) => d.sleep.sleepMinutes).toList();
    final avg1 = week1.reduce((a, b) => a + b) / week1.length;
    expect(avg1, inInclusiveRange(300, 400)); // about 5.5 h on shift days, a bit more on days off
    final weeks = summarizeWeeks(days, {}, d0, d0 + 12, tz, 18 * 60);
    expect(weeks.length, 2);
    expect(weeks.first.moderateMinutes, inInclusiveRange(40, 80)); // ~60 min/week
    expect(weeks.last.avgSleepMinutes!, greaterThan(weeks.first.avgSleepMinutes!));
  });

  group('FHIR', () {
    test('formatLocal matches export.cpp', () {
      expect(formatLocal(1794528000 ~/ 60, 420), '2026-11-13T07:00:00+07:00');
      expect(formatLocal(1794528000 ~/ 60, 240), '2026-11-13T04:00:00+04:00');
      expect(formatLocal(1794528000 ~/ 60, -300), '2026-11-12T19:00:00-05:00');
    });

    test('bundle has the LOINC codes and source tags', () {
      final s0 = 1794528000 ~/ 60;
      final v = day(s0, 900, 420, 0);
      final d = summarizeDay(v, localDay(s0, 240), 240, 18 * 60);
      final full = DaySummary(
        day: d.day,
        dayStartMinute: d.dayStartMinute,
        steps: d.steps,
        moderateMinutes: d.moderateMinutes,
        recordedMinutes: d.recordedMinutes,
        sleep: detectMainSleep(v),
      );
      final b = buildFhirBundle(
        days: [full],
        checkins: [
          Checkin(s0 + 600, CheckinStatus.partial, DataSource.watch),
          Checkin(s0 + 700, CheckinStatus.done, DataSource.selfReport),
        ],
        tzMinutes: 240,
        bandName: 'Test Band',
        profile: Profile(
          goalIds: ['tiredOnWaking'],
          mainGoalId: 'tiredOnWaking',
          activity: WorkActivity.standingLight,
          shift: ShiftType.nightFixed,
          place: WorkPlace.indoor,
          selfSleepMinutes: 330,
          selfWalkMinutes: 60,
          startMinute: s0,
        ),
      );
      final text = fhirJson(b);
      expect(b['resourceType'], 'Bundle');
      for (final code in ['"55423-8"', '"55411-3"', '"93832-4"', '"code": "watch"', '"code": "self-report"', '"partial"', '"done"']) {
        expect(text, contains(code));
      }
      expect(d.moderateMinutes, greaterThan(100));
    });
  });
}
