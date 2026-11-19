// Chi's thread 0008 (18/11): "Your day" around today's shift, "My shifts this week" and "Sleep from your band",
// on the demo band (persona Ravi, fixed nights 22:00-06:00; day sleep 08:30-14:00, nights off 01:00-08:00).
import 'package:bloomback/app_state.dart';
import 'package:bloomback/data/models.dart';
import 'package:bloomback/data/store.dart';
import 'package:bloomback/demo/scenarios.dart';
import 'package:bloomback/l10n/strings.dart';
import 'package:bloomback/main.dart';
import 'package:bloomback/rules/shift_week.dart';
import 'package:bloomback/ui/your_day.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chi_fixes_4_7_test.dart' show an;

Profile ravi() => an(0)
  ..shift = ShiftType.nightFixed
  ..selfSleepStart = 8 * 60 + 30
  ..selfWakeTime = 14 * 60
  ..selfOffSleepStart = 60
  ..selfOffWakeTime = 8 * 60;

final wed = DateTime(2026, 11, 18, 18, 40); // a Wednesday

void main() {
  group('rules', () {
    test('a night today after a night: sleep 08:30-14:00, nap 19:00, shift 22:00, coffee late, home to bed 06:00', () {
      final yd = buildYourDay(p: ravi(), st: Settings(), now: wed, habitId: 'homeToBed');
      expect(yd.today, DayShift.night);
      expect([for (final r in yd.rows) r.kind],
          [DayRowKind.mainSleep, DayRowKind.nap, DayRowKind.shiftStart, DayRowKind.coffee, DayRowKind.homeToBed]);
      expect(yd.rows[0].at, 8 * 60 + 30);
      expect(yd.rows[0].until, 14 * 60);
      expect(yd.rows[1].at, 19 * 60);
      expect(yd.rows[2].at, 22 * 60);
      expect(yd.rows[3].at, isNull);
      expect(yd.rows[4].at, 30 * 60); // 06:00 tomorrow
      expect(yd.rows[4].isStep, isTrue);
      // at 18:40 the sleep is behind, the nap is next
      expect(rowPassed(yd.rows[0], yd.rows, 18 * 60 + 40), isTrue);
      expect(rowPassed(yd.rows[1], yd.rows, 18 * 60 + 40), isFalse);
      // every NIOSH row quotes NIOSH
      for (final r in yd.rows.skip(1)) {
        expect(r.source, startsWith('NIOSH'), reason: r.kind.name);
      }
    });

    test('a night worker on a day off: NIOSH compromise schedule; a day worker: wake-up, step, wind-down, bedtime', () {
      final fri = DateTime(2026, 11, 20, 12); // nights Sunday to Thursday, Friday and Saturday off
      final off = buildYourDay(p: ravi(), st: Settings(), now: fri, habitId: 'homeToBed');
      expect(off.today, DayShift.off);
      expect(off.rows.first.kind, DayRowKind.mainSleep); // after Thursday's night
      expect(off.rows.any((r) => r.kind == DayRowKind.dayOff && r.source.contains('3-4 a.m.')), isTrue);
      final day = buildYourDay(p: an(0), st: Settings(reminder1: 17 * 60 + 30), now: wed, habitId: 'stairs');
      expect(day.today, DayShift.day);
      expect([for (final r in day.rows) r.kind], [DayRowKind.wake, DayRowKind.step, DayRowKind.windDown, DayRowKind.bedtime]);
      expect(day.rows[1].at, 17 * 60 + 30);
      expect(day.rows.where((r) => r.kind == DayRowKind.dayOff), isEmpty);
    });

    test('coming up: days off after nights, and a change of shift type', () {
      final st = Settings();
      final c = comingUp(st, ravi(), wed);
      expect(c.single.kind, ComingKind.daysOffAfterNights);
      expect([for (final d in c.single.days) d.weekday], [DateTime.friday, DateTime.saturday]);
      st.shiftWeek = ['night', 'night', 'night', 'night', 'off', 'off', 'day'];
      final c2 = comingUp(st, ravi(), wed);
      // Sunday to days, then Monday back to nights
      expect(c2.map((x) => x.kind), [ComingKind.daysOffAfterNights, ComingKind.newShiftType, ComingKind.newShiftType]);
      expect(c2[1].days.single.weekday, DateTime.sunday);
      expect(c2[1].to, DayShift.day);
      expect(c2[2].days.single.weekday, DateTime.monday);
      expect(c2[2].to, DayShift.night);
    });

    test('the first two days on a new shift type keep to sleep steps (only once the week is set)', () {
      final p = ravi();
      final st = Settings();
      final sun = DateTime(2026, 11, 22), mon = DateTime(2026, 11, 23), tue = DateTime(2026, 11, 24);
      expect(inFirstDaysOfNewShift(st, p, sun), isFalse);
      st.shiftWeek = ['day', 'day', 'night', 'night', 'off', 'off', 'day'];
      expect(inFirstDaysOfNewShift(st, p, sun), isTrue); // Thursday night → Sunday day
      expect(inFirstDaysOfNewShift(st, p, mon), isTrue);
      expect(inFirstDaysOfNewShift(st, p, tue), isFalse);
      expect(inFirstDaysOfNewShift(st, p, DateTime(2026, 11, 25)), isTrue); // Wednesday: back to nights
    });
  });

  Future<AppState> ready(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final app = AppState(MemoryStore(), clock: () => wed);
    await tester.runAsync(() async {
      await app.load();
      await app.applyScenario(DemoScenario.week3);
    });
    await tester.pumpWidget(BloomBackApp(state: app));
    await tester.pump();
    return app;
  }

  testWidgets('Today: "Your day · night shift tonight" with the band line and the nap next', (tester) async {
    final app = await ready(tester);
    expect(find.text(s.yourDayLabel('night').toUpperCase()), findsOneWidget);
    expect(find.text(s.dayRowTitle('mainSleep', until: '14:00')), findsOneWidget);
    expect(find.byKey(const Key('bandLine')), findsOneWidget); // the demo band slept today
    expect(find.text(s.dayRowTitle('nap')), findsOneWidget);
    expect(find.text(s.late), findsOneWidget);
    expect(find.text(s.yourDayFooterNight), findsOneWidget);
    final next = tester.widget<Container>(find.descendant(of: find.byKey(const Key('dayRow_nap')), matching: find.byType(Container)).first);
    expect(next, isNotNull);
    expect(app.todayCheckin, isNull);
    // the step card stays under the timeline
    expect(find.byKey(const Key('stepCard')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('My shifts: tap Sunday to Day; coming up shows days off and the switch', (tester) async {
    final app = await ready(tester);
    await tester.tap(find.byKey(const Key('openMyShifts')));
    await tester.pumpAndSettle();
    expect(find.text(s.myShiftsTitle), findsOneWidget);
    expect(find.byKey(const Key('comingDaysOff')), findsOneWidget);
    expect(find.byKey(const Key('comingNewShift')), findsNothing);
    await tester.tap(find.byKey(const Key('shiftDay_6'))); // Sunday night → day
    await tester.pumpAndSettle();
    expect(app.settings.shiftWeek!.last, 'day');
    expect(find.byKey(const Key('comingNewShift')), findsNWidgets(2)); // Sunday to days, Monday back to nights
    expect(find.text(s.newShiftTitle('Sunday', 'day')), findsOneWidget);
    expect(find.text(s.newShiftTitle('Monday', 'night')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Sleep from your band: last sleep, 7 days on a 24 h line, work days vs days off', (tester) async {
    final app = await ready(tester);
    await tester.tap(find.byKey(const Key('dayRow_mainSleep')));
    await tester.pumpAndSettle();
    expect(find.text(s.bandSleepTitle), findsOneWidget);
    expect(find.byKey(const Key('lastMainSleep')), findsOneWidget);
    expect(find.text(s.estimate), findsWidgets);
    expect(find.byKey(const Key('sleep24h')), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byKey(const Key('bandCompare')), findsOneWidget);
    expect(find.text(s.bandCompareNote), findsOneWidget);
    expect(app.days.where((d) => d.sleep.found), isNotEmpty);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('More has "Sleep from your band" and "My shifts this week"', (tester) async {
    await ready(tester);
    await tester.tap(find.text(s.tabMore));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('more_bandSleep')), findsOneWidget);
    expect(find.byKey(const Key('more_myShifts')), findsOneWidget);
    expect(find.byType(BandSleepScreen), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('My shifts and Sleep from your band keep the tab bar; a tab goes back and opens it', (tester) async {
    await ready(tester);
    await tester.tap(find.byKey(const Key('openMyShifts')));
    await tester.pumpAndSettle();
    final bar = find.byType(NavigationBar);
    expect(bar, findsWidgets);
    await tester.tap(find.descendant(of: bar.last, matching: find.text(s.tabGarden)));
    await tester.pumpAndSettle();
    expect(find.byType(MyShiftsScreen), findsNothing);
    expect(find.byKey(const Key('monthGrid')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
