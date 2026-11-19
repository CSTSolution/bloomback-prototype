// Chi's 17/11 review (thread 0004 fixes 9-15, thread 0007 timer minutes). Persona An.
import 'package:bloomback/app_state.dart';
import 'package:bloomback/data/models.dart';
import 'package:bloomback/data/store.dart';
import 'package:bloomback/l10n/strings.dart';
import 'package:bloomback/main.dart';
import 'package:bloomback/rules/environment.dart';
import 'package:bloomback/rules/plan.dart';
import 'package:bloomback/rules/reminders.dart';
import 'package:bloomback/sound/after_sound.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chi_fixes_4_7_test.dart' show an;
import 'fake_server.dart';

Future<AppState> _ready(WidgetTester tester, {String habit = 'stretch', City? city = City.dubai}) async {
  tester.view.physicalSize = const Size(1080, 4800);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final now = DateTime(2026, 11, 17, 17, 45);
  final app = AppState(MemoryStore(), clock: () => now, account: FakeServer().account(), sound: SilentSound());
  final nowMin = now.toUtc().millisecondsSinceEpoch ~/ 60000;
  final p = an(nowMin - 3 * 1440)..city = city;
  await tester.runAsync(() async {
    await app.load();
    await app.saveName('An');
    await app.finishOnboarding(p, initialPlan(profile: p, domains: {Domain.movement}, mainHabitId: habit, nowMinute: nowMin),
        suggestedReminderSettings(p.shift, app.settings, habitId: habit));
  });
  await tester.pumpWidget(BloomBackApp(state: app));
  await tester.pumpAndSettle();
  return app;
}

void main() {
  test('fix 10: without a city there is no heat-season or Ramadan-date hint', () {
    final july = DateTime(2027, 7, 10);
    expect(suggestedRamadan(DateTime(2027, 1, 10), null), isNull);
    expect(suggestedRamadan(DateTime(2027, 1, 10), City.dubai), isNotNull);
    final p = an(0)..city = null;
    final pl = initialPlan(profile: p, domains: {Domain.movement}, mainHabitId: 'briskWalk', nowMinute: 0);
    expect(dayRules(profile: p, plan: pl, settings: Settings(), date: july).hot, isFalse);
    p.city = City.dubai;
    expect(dayRules(profile: p, plan: pl, settings: Settings(), date: july).hot, isTrue);
  });

  test('fix 14: the sign-in body no longer repeats the title', () {
    expect(s.signInBody, 'Your plan and garden stay on this phone. An account is only for Pro and the coach.');
  });

  testWidgets('timer minutes: stretching shows "5 min · BloomBack suggestion ?" and the user can change them', (tester) async {
    final app = await _ready(tester);
    expect(find.text(s.stepMinutesLine(5)), findsOneWidget);
    expect(find.text(s.bbSuggestion), findsWidgets);
    expect(find.byKey(const Key('stepMinutesWhy')), findsOneWidget);
    await tester.tap(find.byKey(const Key('changeMinutes')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('minMore1')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('minSave')));
    await tester.pumpAndSettle();
    expect(app.stepMinutes(), 8);
    expect(find.text(s.startStep(8, music: false)), findsOneWidget);
    expect(find.byKey(const Key('stepMinutesWhy')), findsNothing); // the user's own number: no suggestion label
    // back to the suggestion
    await tester.tap(find.byKey(const Key('changeMinutes')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(s.useSuggested));
    await tester.pumpAndSettle();
    expect(app.stepMinutes(), 5);
  });

  testWidgets('fix 11: the timer keeps the bottom bar; a tab asks first, then opens that tab', (tester) async {
    final app = await _ready(tester);
    await tester.tap(find.byKey(const Key('stepStart')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timerNavBar')), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const Key('timerNavBar')), matching: find.text(s.tabGarden)));
    await tester.pumpAndSettle();
    expect(find.text(s.leaveTimerQ), findsOneWidget);
    await tester.tap(find.text(s.stopTimer));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timerNavBar')), findsNothing);
    expect(find.byKey(const Key('monthGrid')), findsOneWidget); // the Garden tab
    expect(app.todayCheckin, isNull);
  });

  testWidgets('fix 11: "How did it go?" keeps the bottom bar too', (tester) async {
    await _ready(tester);
    await tester.tap(find.byKey(const Key('stepStart')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timerFinish')));
    await tester.pumpAndSettle();
    expect(find.text(s.howDidItGo), findsOneWidget);
    expect(find.byKey(const Key('timerNavBar')), findsOneWidget);
  });
}
