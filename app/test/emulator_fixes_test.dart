// Fixes from the emulator check on 14 Nov (1080x2400 phone, about 411 dp wide):
// screen 5 sleep defaults by shift, the reminder that follows the habit (Plan tab),
// blank garden days before the plan started, the "Welcome back, Ravi" title on one
// line (measured with Chi's real heading font), and the sprout logo on screen 1.
import 'package:bloomback/app_state.dart';
import 'package:bloomback/data/store.dart';
import 'package:bloomback/demo/scenarios.dart';
import 'package:bloomback/l10n/strings.dart';
import 'package:bloomback/main.dart';
import 'package:bloomback/ui/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A phone [widthDp] wide at the emulator's density (1080 px / 2.625 = 411 dp).
void phoneDp(WidgetTester tester, {double widthDp = 1080 / 2.625}) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = Size(widthDp * 2.625, 2400);
  addTearDown(tester.view.reset);
}

final _now = DateTime(2026, 11, 13, 17, 0);

Future<AppState> _scenario(WidgetTester tester, DemoScenario sc, {String? name}) async {
  final app = AppState(MemoryStore(), clock: () => _now);
  await tester.runAsync(() async {
    await app.load();
    await app.applyScenario(sc);
    if (name != null) await app.saveName(name);
  });
  await tester.pumpWidget(BloomBackApp(state: app));
  await tester.pump();
  return app;
}

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  if (f.evaluate().isNotEmpty) return;
  await tester.scrollUntilVisible(f, 150, scrollable: find.byType(Scrollable).hitTestable().first, maxScrolls: 40);
}

void main() {
  group('1 screen 5 starts from the shift picked on screen 4', () {
    Future<void> toScreen5(WidgetTester tester, String shift) async {
      await tester.tap(find.text(shift));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, s.continueLabel));
      await tester.pumpAndSettle();
      expect(find.text(s.nowTitle), findsOneWidget);
    }

    String shown(WidgetTester tester, String key) {
      final rich = find.descendant(of: find.byKey(Key(key)), matching: find.byType(RichText));
      // the box shows the label, the time, then the day part, each on its own line
      return tester.widget<RichText>(rich.at(1)).text.toPlainText();
    }

    testWidgets('fixed night 08:30-14:00, fixed day 23:00-06:00, rotating 23:30-05:30', (tester) async {
      phoneDp(tester);
      final app = AppState(MemoryStore(), clock: () => DateTime(2026, 11, 13, 10));
      await tester.runAsync(app.load);
      await tester.pumpWidget(BloomBackApp(state: app));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.getStarted));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tryWithout')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, s.continueLabel));
      await tester.pumpAndSettle();
      // Work: everything but the shift.
      await tester.tap(find.text('Standing / light walking'));
      await tester.tap(find.text('Indoors (AC)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('city')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abu Dhabi').last);
      await tester.pumpAndSettle();

      for (final (shift, start, wake, hours) in [
        ('Fixed night', '08:30', '14:00', 330),
        ('Fixed day', '23:00', '06:00', 420),
        ('Rotating', '23:30', '05:30', 360),
      ]) {
        await toScreen5(tester, shift);
        expect(shown(tester, 'sleepStart'), start, reason: shift);
        expect(shown(tester, 'wakeTime'), wake, reason: shift);
        expect(find.text(s.hoursOfSleep(hours)), findsOneWidget, reason: shift);
        await tester.tap(find.byKey(const Key('back')));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('2 Plan tab: Ravi (fixed nights, straight to bed) is reminded at 07:30, end of the shift', (tester) async {
    phoneDp(tester);
    final app = await _scenario(tester, DemoScenario.week3);
    expect(app.plan!.mainHabitId, 'homeToBed');
    expect(app.plan!.backupHabitIds, ['blackout', 'napBeforeShift']);
    await tester.tap(find.text(s.tabPlan).last);
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const Key('reminderLine')));
    expect(find.text(s.reminderLine(['07:30'], '08:00', '15:00')), findsOneWidget);
    expect(find.text('Reminder 07:30 · Quiet hours 08:00–15:00'), findsOneWidget);
    expect(app.todayRules!.reminderTimes, [7 * 60 + 30]);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1)); // the auto-sync on open
  });

  group('4 garden: days before the plan started are blank', () {
    testWidgets('Today strip and Garden tab', (tester) async {
      phoneDp(tester);
      // Nights are coming: started 6 days ago (7 Nov), done or partly every day since, today open.
      final app = await _scenario(tester, DemoScenario.nightsSoon);
      final today = app.today, start = app.planDay;
      expect(today - start, 6);
      final strip = find.byKey(const Key('gardenStrip'));
      await _scrollTo(tester, strip);
      Finder inStrip(String key) => find.descendant(of: strip, matching: find.byKey(Key(key)));
      for (var d = today - 9; d < start; d++) {
        expect(inStrip('gardenBlank_$d'), findsOneWidget, reason: 'day ${d - today}');
        expect(inStrip('gardenGrey_$d'), findsNothing);
      }
      for (var d = start; d < today; d++) {
        expect(inStrip('gardenBloom_$d'), findsOneWidget, reason: 'day ${d - today}');
      }
      expect(inStrip('gardenGrey_$today'), findsOneWidget); // started, not checked in yet

      await tester.tap(find.text(s.tabGarden).last);
      await tester.pumpAndSettle();
      final grid = find.byKey(const Key('monthGrid'));
      Finder inGrid(String key) => find.descendant(of: grid, matching: find.byKey(Key(key)));
      final first = today - (_now.day - 1); // 1 Nov
      // Chi fix 15 (17/11): the grid starts at the plan's first week, so earlier weeks leave no blank block;
      // days of that week before the start stay blank.
      final weekStart = start - (start + 3) % 7;
      for (var d = first; d < start; d++) {
        expect(inGrid('gardenBlank_$d'), d >= weekStart ? findsOneWidget : findsNothing, reason: 'Nov ${d - first + 1}');
      }
      for (var d = start; d < today; d++) {
        expect(inGrid('gardenBloom_$d'), findsOneWidget);
      }
      expect(inGrid('gardenGrey_$today'), findsOneWidget);
      expect(inGrid('gardenFuture_${today + 1}'), findsOneWidget);
      expect(find.descendant(of: grid, matching: find.byWidgetPredicate((w) => w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('gardenGrey_'))), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('5 "Welcome back, <name>" title (Baloo 2, as on the phone)', () {
    setUpAll(() async {
      // Chi's heading font, so the widths are the phone's, not the test font's.
      final loader = FontLoader('Baloo2')..addFont(rootBundle.load('assets/fonts/Baloo2-Variable.ttf'));
      await loader.load();
    });

    const lineHeight = 22 * 1.2; // headlineSmall: Baloo 2, 22, height 1.2

    Future<(RenderParagraph, Rect, Rect)> title(WidgetTester tester, String name, double widthDp) async {
      phoneDp(tester, widthDp: widthDp);
      await _scenario(tester, DemoScenario.welcomeBack, name: name);
      expect(find.textContaining(s.welcomeBackName(name)), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'no overflow at $widthDp dp');
      // The first RichText is the title (the sprout Icon inside it is one too).
      final rich = find.descendant(of: find.byKey(const Key('welcomeBack')), matching: find.byType(RichText)).first;
      final para = tester.renderObject<RenderParagraph>(rich);
      return (para, tester.getRect(rich), tester.getRect(find.byKey(const Key('welcomeBackSprout'))));
    }

    void sproutNextToLastWord(RenderParagraph para, Rect text, Rect sprout) {
      // On the last line, after a word (not alone at the start of a line), inside the title.
      expect(sprout.center.dy, greaterThan(text.bottom - lineHeight));
      expect(sprout.left - text.left, greaterThan(40));
      expect(sprout.right, lessThanOrEqualTo(text.right + 0.5));
    }

    testWidgets('"Ravi" on a 411 dp phone: one line, sprout right after the name', (tester) async {
      final (para, text, sprout) = await title(tester, 'Ravi', 1080 / 2.625);
      expect(para.size.height, lessThan(lineHeight * 1.5), reason: 'one line');
      expect(para.didExceedMaxLines, isFalse);
      sproutNextToLastWord(para, text, sprout);
      expect(sprout.center.dy, closeTo(text.center.dy, 4));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a 12-letter name on 411 dp: no overflow, sprout kept with the name', (tester) async {
      final (para, text, sprout) = await title(tester, 'Christabella', 1080 / 2.625);
      sproutNextToLastWord(para, text, sprout);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a 12-letter name on a narrow 320 dp phone: wraps cleanly, sprout stays with the last word', (tester) async {
      final (para, text, sprout) = await title(tester, 'Christabella', 320);
      expect(para.size.height, greaterThan(lineHeight * 1.5), reason: 'wraps to 2 lines');
      expect(para.size.height, lessThan(lineHeight * 2.5));
      sproutNextToLastWord(para, text, sprout);
      await tester.pump(const Duration(seconds: 1));
    });
  });

  testWidgets('6 screen 1 shows the BloomBack sprout from the app icon', (tester) async {
    phoneDp(tester);
    final app = AppState(MemoryStore(), clock: () => DateTime(2026, 11, 13, 9));
    await tester.runAsync(app.load);
    await tester.pumpWidget(BloomBackApp(state: app));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('startLogo')), findsOneWidget);
    expect(find.byType(SproutMark), findsNWidgets(2)); // in the circle and before "BloomBack"
    final img = tester.widget<Image>(find.descendant(of: find.byKey(const Key('startLogo')), matching: find.byType(Image)));
    expect((img.image as AssetImage).assetName, SproutMark.asset);
    expect(find.byIcon(BBIcons.sprout), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('7 Ravi\'s sentence is Chi\'s exact text', () {
    expect(kRaviMotivation, 'So I still have energy to video-call my kids');
    final setup = buildScenario(DemoScenario.week3, _now);
    expect(setup.profile!.motivation, kRaviMotivation);
    expect(setup.settings!.reminder1, 7 * 60 + 30);
  });
}
