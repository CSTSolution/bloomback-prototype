// Demo scenarios (Settings > Debug): each one resets the app through the normal
// paths (delete, onboarding result, pair the demo band, sync) and lands on the
// Today card it is meant to show.
import 'package:bloomback/app_state.dart';
import 'package:bloomback/band/fake_band.dart';
import 'package:bloomback/data/models.dart';
import 'package:bloomback/data/store.dart';
import 'package:bloomback/demo/scenarios.dart';
import 'package:bloomback/l10n/strings.dart';
import 'package:bloomback/main.dart';
import 'package:bloomback/rules/environment.dart';
import 'package:bloomback/rules/plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // After 15:00, when the demo band's check-ins of the day are made; and a morning.
  for (final now in [DateTime(2026, 11, 13, 17, 0), DateTime(2026, 11, 13, 9, 30)]) {
    group('at $now', () {
      Future<AppState> load(DemoScenario sc, [MemoryStore? store]) async {
        final app = AppState(store ?? MemoryStore(), clock: () => now);
        await app.load();
        await app.applyScenario(sc);
        return app;
      }

      test('Fresh start: no data, onboarding', () async {
        final store = MemoryStore();
        final app = await load(DemoScenario.week3, store);
        expect(app.onboarded, isTrue);
        await app.applyScenario(DemoScenario.fresh);
        expect(app.onboarded, isFalse);
        expect(app.minutes, isEmpty);
        expect(store.checkins, isEmpty);
        expect(app.settings.useFakeBand, isTrue);
        expect(app.settings.bandId, isNull);
      });

      test('Week 3, steady: band data, step-up suggestion', () async {
        final app = await load(DemoScenario.week3);
        expect(app.onboarded, isTrue);
        expect(app.today - app.firstDay, 21); // a band week before the plan + 15 days
        expect(app.minutes.length, 21 * 1440);
        expect(app.settings.bandName, 'BloomBack-DEMO');
        expect(app.checkins.every((c) => c.source == DataSource.watch), isTrue);
        expect(app.todayCheckin, isNull); // left open for the video
        expect(app.nudge, Nudge.stepUp);
        expect(app.radar, isEmpty);
      });

      test('Welcome back: 2 days without a check-in, his own sentence', () async {
        final app = await load(DemoScenario.welcomeBack);
        expect(app.nudge, Nudge.welcomeBack);
        expect(app.profile!.motivation, kRaviMotivation);
        expect(s.welcomeBackBody(app.profile!.motivation), contains(kRaviMotivation));
        expect(app.byDay[app.today - 1], isNull);
        expect(app.byDay[app.today - 2], isNull);
        expect(app.byDay[app.today - 3], isNotNull);
      });

      test('A bit hard lately: 3 "partly" in 5 days, shrink / swap / move', () async {
        final app = await load(DemoScenario.hardLately);
        expect(app.nudge, Nudge.difficulty);
        final partly = [for (var d = app.today - 4; d <= app.today; d++) app.byDay[d]]
            .where((c) => c == CheckinStatus.partial)
            .length;
        expect(partly, greaterThanOrEqualTo(3));
        expect(app.plan!.backupHabitIds, isNotEmpty); // "Swap" has something to offer
      });

      test('Nights are coming: rotating shift, nights in 2 days', () async {
        final app = await load(DemoScenario.nightsSoon);
        expect(app.profile!.shift, ShiftType.rotating);
        final r = app.radar.where((x) => x.kind == RadarKind.nightsSoon).single;
        expect(r.days, 2);
        expect(app.nudge, Nudge.none);
      });

      test('a scenario replaces the one before, and survives a restart', () async {
        final store = MemoryStore();
        await load(DemoScenario.week3, store);
        final app = await load(DemoScenario.hardLately, store);
        expect(app.minutes.length, 14 * 1440);
        expect(app.nudge, Nudge.difficulty);
        // Restart: same store, the demo band keeps its scenario check-ins.
        final later = now.add(const Duration(hours: 1));
        final again = AppState(store, clock: () => later);
        await again.load();
        expect((again.link as FakeBandLink).checkinScript[again.today], -1);
        await again.sync();
        expect(again.todayCheckin, isNull);
        expect(again.nudge, Nudge.difficulty);
        expect(again.minutes.length, 14 * 1440 + 60); // the hour since, synced on top
      });

      test('the demo band switch off: scenarios do nothing', () async {
        final app = AppState(MemoryStore(), clock: () => now);
        await app.load();
        await app.saveSettings(Settings.fromJson(app.settings.toJson())..useFakeBand = false);
        await app.applyScenario(DemoScenario.week3);
        expect(app.onboarded, isFalse);
      });
    });
  }

  group('Today shows the scenario card', () {
    final now = DateTime(2026, 11, 13, 17, 0);
    final cases = <DemoScenario, List<String>>{
      DemoScenario.week3: [s.stepUpTitle, s.stepUpYes],
      // Its own screen (14): his name, his own sentence word for word, restart small.
      DemoScenario.welcomeBack: [s.welcomeBackName('Ravi'), '"$kRaviMotivation"', s.restartSmallTitle, s.restartToday],
      DemoScenario.hardLately: [s.difficultyTitle, s.shrink, s.swap, s.move],
      DemoScenario.nightsSoon: [s.radarNightsTitle, s.radarNightsBody(2)],
    };
    for (final e in cases.entries) {
      testWidgets(s.scenarioTitle(e.key), (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.625;
        addTearDown(tester.view.reset);
        final app = AppState(MemoryStore(), clock: () => now);
        await tester.runAsync(() async {
          await app.load();
          await app.applyScenario(e.key);
        });
        await tester.pumpWidget(BloomBackApp(state: app));
        await tester.pump();
        for (final t in e.value) {
          // "Welcome back, Ravi" is rich text with the sprout inline.
          final f = t == s.welcomeBackName('Ravi') ? find.textContaining(t) : find.text(t);
          expect(f, findsOneWidget, reason: t);
        }
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 1)); // the auto-sync on open
      });
    }
  });

  testWidgets('web demo banner: scenario picker, Fresh start shows onboarding', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final app = AppState(MemoryStore(), clock: () => DateTime(2026, 11, 13, 17, 0));
    await tester.runAsync(app.load);
    await tester.pumpWidget(BloomBackApp(state: app, demoBanner: true));
    await tester.pumpAndSettle();
    expect(find.text(s.demoBanner), findsOneWidget);
    expect(find.text(s.getStarted), findsOneWidget);
    await tester.tap(find.byKey(const Key('bannerScenarios')));
    await tester.pumpAndSettle();
    for (final sc in DemoScenario.values) {
      expect(find.text(s.scenarioTitle(sc)), findsOneWidget);
      expect(find.text(s.scenarioDescription(sc)), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('scenario_fresh')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.ok));
    await tester.pumpAndSettle();
    expect(find.text(s.demoLoaded(s.scenarioTitle(DemoScenario.fresh))), findsOneWidget);
    expect(find.text(s.getStarted), findsOneWidget);
    expect(app.onboarded, isFalse);
  });
}
