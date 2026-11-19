// Chi's thread 0006 (approved 16/11): the Today picture follows the time of day; white greeting at night;
// the garden on the sand with today's bud; a light violet page at night.
import 'package:bloomback/app_state.dart';
import 'package:bloomback/data/models.dart';
import 'package:bloomback/data/store.dart';
import 'package:bloomback/l10n/strings.dart';
import 'package:bloomback/main.dart';
import 'package:bloomback/rules/plan.dart';
import 'package:bloomback/rules/reminders.dart';
import 'package:bloomback/sound/after_sound.dart';
import 'package:bloomback/ui/today_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chi_fixes_4_7_test.dart' show an;
import 'fake_server.dart';

Future<AppState> _at(WidgetTester tester, int hour, int minute, {bool checkIn = false}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final now = DateTime(2026, 11, 16, hour, minute);
  final app = AppState(MemoryStore(), clock: () => now, account: FakeServer().account(), sound: SilentSound());
  final nowMin = now.toUtc().millisecondsSinceEpoch ~/ 60000;
  final p = an(nowMin - 3 * 1440);
  await tester.runAsync(() async {
    await app.load();
    await app.saveName('An');
    await app.finishOnboarding(p, initialPlan(profile: p, domains: {Domain.movement}, mainHabitId: 'stairs', nowMinute: nowMin),
        suggestedReminderSettings(p.shift, app.settings, habitId: 'stairs'));
    if (checkIn) await app.checkIn(CheckinStatus.done);
  });
  await tester.pumpWidget(BloomBackApp(state: app));
  await tester.pumpAndSettle();
  return app;
}

void main() {
  test('hours: dawn 05:30, noon 08:00, evening 17:00, night 19:00', () {
    DayLight at(int h, int m) => dayLightAt(DateTime(2026, 11, 16, h, m));
    expect(at(5, 29), DayLight.night);
    expect(at(5, 30), DayLight.dawn);
    expect(at(7, 59), DayLight.dawn);
    expect(at(8, 0), DayLight.noon);
    expect(at(16, 59), DayLight.noon);
    expect(at(17, 0), DayLight.evening);
    expect(at(18, 59), DayLight.evening);
    expect(at(19, 0), DayLight.night);
    expect(at(2, 30), DayLight.night);
  });

  for (final (h, m, light) in [(6, 10, DayLight.dawn), (12, 40, DayLight.noon), (17, 45, DayLight.evening), (2, 30, DayLight.night)]) {
    testWidgets('Today at $h:$m shows the ${light.name} picture', (tester) async {
      await _at(tester, h, m);
      expect(find.byKey(Key('heroImage_${light.name}')), findsOneWidget);
      final greeting = tester.widget<Text>(find.byKey(const Key('greeting')));
      expect(greeting.style!.color, light == DayLight.night ? Colors.white : isNot(Colors.white));
      final page = tester.widget<ColoredBox>(find.ancestor(of: find.byKey(const Key('todayHero')), matching: find.byType(ColoredBox)).first);
      expect(page.color, pageColorFor(light));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("the sand shows today's bud until the step blooms, then the flower count", (tester) async {
    await _at(tester, 12, 0);
    expect(find.byKey(const Key('heroBud')), findsOneWidget);
    expect(find.text(s.heroGardenLabel(0, waiting: true)), findsOneWidget);
  });

  testWidgets('after Done the bud becomes a flower', (tester) async {
    await _at(tester, 12, 0, checkIn: true);
    expect(find.byKey(const Key('heroBud')), findsNothing);
    expect(find.text(s.heroGardenLabel(1, waiting: false)), findsOneWidget);
    await tester.tap(find.byKey(const Key('heroGarden')));
    await tester.pumpAndSettle();
    expect(find.text(s.tabGarden), findsWidgets);
  });
}
