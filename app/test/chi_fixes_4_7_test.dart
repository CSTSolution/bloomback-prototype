// Chi's thread 0004 (15/11) fixes 4-7, with her persona An: office, fixed day shift, about 225 min a week,
// goal "Fitter", movement first, habit "Take the stairs", no band, "Try without an account" with a first name.
import 'package:bloomback/app_state.dart';
import 'package:bloomback/data/models.dart';
import 'package:bloomback/data/store.dart';
import 'package:bloomback/l10n/strings.dart';
import 'package:bloomback/main.dart';
import 'package:bloomback/rules/plan.dart';
import 'package:bloomback/rules/reminders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_server.dart';

Profile an(int startMinute) => Profile(
      goalIds: ['stronger'],
      mainGoalId: 'stronger',
      activity: WorkActivity.sitting,
      shift: ShiftType.dayFixed,
      place: WorkPlace.indoor,
      selfSleepMinutes: 420,
      selfWalkMinutes: 225,
      startMinute: startMinute,
      heightCm: 165,
      weightKg: 60,
      city: City.dubai,
      exerciseDays: 5,
      exerciseMinutes: 45,
    );

Future<AppState> _ready(WidgetTester tester, {String habit = 'stairs', String choice = 'keep'}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final now = DateTime(2026, 11, 15, 18, 0);
  final app = AppState(MemoryStore(), clock: () => now, account: FakeServer().account());
  final nowMin = now.toUtc().millisecondsSinceEpoch ~/ 60000;
  final p = an(nowMin - 3 * 1440);
  await tester.runAsync(() async {
    await app.load();
    await app.saveName('An');
    await app.finishOnboarding(
      p,
      initialPlan(profile: p, domains: {Domain.movement}, mainHabitId: habit, nowMinute: nowMin)
        ..moveChoice = choice
        ..movementGoal = choice == 'to300' ? 300 : 150,
      suggestedReminderSettings(p.shift, app.settings, habitId: habit),
    );
    await app.checkIn(CheckinStatus.done);
  });
  await tester.pumpWidget(BloomBackApp(state: app));
  await tester.pumpAndSettle();
  return app;
}

void main() {
  group('fix 6: the reminder follows the habit cue', () {
    test('day shift, "after I finish work" habits: one reminder at 17:30', () {
      for (final h in ['stairs', 'briskWalk', 'strength', 'indoorWalk']) {
        final st = suggestedReminderSettings(ShiftType.dayFixed, Settings(), habitId: h);
        expect(st.reminder1, 17 * 60 + 30, reason: h);
        expect(st.reminder2, -1, reason: h);
      }
    });
    test('morning and evening habits keep 07:30 and 18:30; night shifts unchanged', () {
      final bed = suggestedReminderSettings(ShiftType.dayFixed, Settings(), habitId: 'bedEarlier');
      expect((bed.reminder1, bed.reminder2), (7 * 60 + 30, 18 * 60 + 30));
      final night = suggestedReminderSettings(ShiftType.nightFixed, Settings(), habitId: 'briskWalk');
      expect((night.reminder1, night.reminder2), (16 * 60, 6 * 60 + 30));
      final home = suggestedReminderSettings(ShiftType.nightFixed, Settings(), habitId: 'homeToBed');
      expect(home.reminder1, 7 * 60 + 30);
    });
  });

  testWidgets('fix 4: Today without a band shows check-ins, never "0 min"; the line matches the habit', (tester) async {
    final app = await _ready(tester);
    expect(find.byKey(const Key('moveCheckins')), findsOneWidget);
    expect(find.text(s.daysOfPlan(1, 5)), findsOneWidget);
    expect(find.text(s.fromCheckins), findsOneWidget);
    expect(find.textContaining('0 min'), findsNothing);
    expect(find.text(s.toldUsHealthy(225)), findsOneWidget);
    // "Take the stairs": its own line, no walk count
    expect(find.text(s.stairsDose), findsOneWidget);
    expect(find.textContaining('walks'), findsNothing);
    expect(find.textContaining('Brisk minutes'), findsNothing);
    expect(app.habitDose(), s.stairsDose);
  });

  testWidgets('fix 4: a brisk walk while keeping the rhythm, no band: "Keep your usual rhythm"', (tester) async {
    final app = await _ready(tester, habit: 'briskWalk');
    expect(app.habitDose(), s.keepRhythmDose);
    expect(find.text(s.keepRhythmDose), findsOneWidget);
  });

  testWidgets('fix 5: Plan shows the 10b choice and the other choices, never "up to 150"', (tester) async {
    final app = await _ready(tester);
    await tester.tap(find.text(s.tabPlan));
    await tester.pumpAndSettle();
    expect(find.text(s.healthyRange), findsOneWidget);
    expect(find.byKey(const Key('moveChoice')), findsOneWidget);
    expect(find.textContaining('up to 150'), findsNothing);
    expect(find.byKey(const Key('moveChoice_to300')), findsOneWidget);
    expect(find.byKey(const Key('moveChoice_strength')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('moveChoice_to300')));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200)); // clear of the bottom bar
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('moveChoice_to300')));
    await tester.pumpAndSettle();
    expect(app.plan!.moveChoice, 'to300');
    expect(app.plan!.movementGoal, 300);
    expect(find.byKey(const Key('moveChoice_keep')), findsOneWidget);
    expect(find.textContaining('up to 300'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fix 7: not signed in reads as the same person; the avatar opens Account', (tester) async {
    await _ready(tester);
    expect(find.text(s.goodEvening('An')), findsOneWidget);
    await tester.tap(find.byKey(const Key('avatar')));
    await tester.pumpAndSettle();
    expect(find.text(s.notSignedInName('An')), findsOneWidget);
    expect(find.text(s.notSignedInLine), findsOneWidget);
    await tester.tap(find.byKey(const Key('back')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.tabMore));
    await tester.pumpAndSettle();
    expect(find.text(s.notSignedInName('An')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
