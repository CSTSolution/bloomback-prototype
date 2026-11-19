// Chi's thread 0007 (16/11): BloomBack music (9 Kevin MacLeod tracks, CC BY 4.0, credit shown) and music with a
// countdown while doing a timed small step (design docs/design/music-while-you-move-2026-11-16.png). Persona An.
import 'dart:io';

import 'package:bloomback/app_state.dart';
import 'package:bloomback/data/models.dart';
import 'package:bloomback/data/store.dart';
import 'package:bloomback/l10n/strings.dart';
import 'package:bloomback/main.dart';
import 'package:bloomback/rules/plan.dart';
import 'package:bloomback/rules/reminders.dart';
import 'package:bloomback/sound/after_sound.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chi_fixes_4_7_test.dart' show an;
import 'fake_server.dart';

Future<(AppState, SilentSound)> _ready(WidgetTester tester,
    {String habit = 'briskWalk', String sound = 'off', String stepMusic = 'off', String track = 'morning'}) async {
  tester.view.physicalSize = const Size(1080, 4800);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final now = DateTime(2026, 11, 16, 17, 45);
  final silent = SilentSound();
  final app = AppState(MemoryStore(), clock: () => now, account: FakeServer().account(), sound: silent);
  final nowMin = now.toUtc().millisecondsSinceEpoch ~/ 60000;
  final p = an(nowMin - 3 * 1440);
  await tester.runAsync(() async {
    await app.load();
    await app.saveName('An');
    final st = suggestedReminderSettings(p.shift, app.settings, habitId: habit)
      ..sound = sound
      ..stepMusic = stepMusic
      ..musicTrack = track;
    await app.finishOnboarding(p, initialPlan(profile: p, domains: {Domain.movement}, mainHabitId: habit, nowMinute: nowMin), st);
  });
  await tester.pumpWidget(BloomBackApp(state: app));
  await tester.pumpAndSettle();
  return (app, silent);
}

void main() {
  test('the 9 tracks are in the app, each with its credit', () {
    expect(kMusic, hasLength(9));
    for (final m in kMusic) {
      expect(File(m.asset).existsSync(), isTrue, reason: m.asset);
      expect(m.credit, contains('Kevin MacLeod (incompetech.com)'));
      expect(m.credit, contains('https://creativecommons.org/licenses/by/4.0/'));
    }
  });

  testWidgets('BloomBack music after Done plays the chosen track and shows its credit', (tester) async {
    final (_, silent) = await _ready(tester, habit: 'stairs', sound: 'music', track: 'clear-air');
    await tester.tap(find.text(s.checkinDone));
    await tester.pumpAndSettle();
    expect(silent.plays, [musicTrack('clear-air').asset]);
    expect(find.text('Clear Air'), findsOneWidget);
    await tester.tap(find.byKey(const Key('musicCredit')));
    await tester.pumpAndSettle();
    expect(find.text(musicTrack('summer-day').credit), findsOneWidget);
  });

  testWidgets('steps without a time keep the three buttons', (tester) async {
    await _ready(tester, habit: 'stairs');
    expect(find.byKey(const Key('stepStart')), findsNothing);
    expect(find.text(s.checkinDone), findsOneWidget);
  });

  testWidgets('a timed step: Start, countdown, pause, Finish now, Partly', (tester) async {
    final (app, silent) = await _ready(tester, stepMusic: 'music', track: 'water-lily');
    final minutes = app.stepMinutes()!;
    expect(find.text(s.startStep(minutes, music: true)), findsOneWidget);
    expect(find.byKey(const Key('moveMusicCard')), findsOneWidget);
    expect(find.text(s.didItAlready), findsOneWidget);
    await tester.tap(find.byKey(const Key('stepStart')));
    await tester.pumpAndSettle();
    // the 9 tracks one after another, from the chosen one
    expect(silent.sessions.single.first, musicTrack('water-lily').asset);
    expect(silent.sessions.single, hasLength(9));
    expect(find.byKey(const Key('stepNowPlaying')), findsOneWidget);
    expect(find.text('Water Lily'), findsOneWidget);
    expect(find.text(s.outdoorsVolume), findsOneWidget);
    String left() => tester.widget<Text>(find.byKey(const Key('timerLeft'))).data!;
    expect(left(), '$minutes:00');
    await tester.pump(const Duration(seconds: 3));
    expect(left(), '${minutes - 1}:57');
    await tester.tap(find.byKey(const Key('timerPause')));
    await tester.pump(const Duration(seconds: 5));
    expect(left(), '${minutes - 1}:57');
    expect(silent.playing.value, isFalse);
    await tester.tap(find.byKey(const Key('musicNext')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('timerFinish')));
    await tester.pumpAndSettle();
    expect(find.text(s.stoppedEarlyTitle), findsOneWidget);
    expect(app.todayCheckin, isNull); // nothing saved before Done or Partly
    await tester.tap(find.byKey(const Key('timerPartly')));
    await tester.pumpAndSettle();
    expect(app.todayCheckin, CheckinStatus.partial);
    expect(find.byKey(const Key('checkinResult')), findsOneWidget);
    expect(find.byKey(const Key('quizCard')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('time is up: a soft chime, then Done', (tester) async {
    final (app, silent) = await _ready(tester);
    final minutes = app.stepMinutes()!;
    expect(find.text(s.startStep(minutes, music: false)), findsOneWidget);
    await tester.tap(find.byKey(const Key('stepStart')));
    await tester.pumpAndSettle();
    expect(silent.sessions, isEmpty); // music is off by default
    await tester.pump(Duration(seconds: minutes * 60 + 1));
    await tester.pumpAndSettle();
    expect(find.text(s.timeUpTitle(minutes)), findsOneWidget);
    expect(silent.plays, [kChimes['bell']]);
    await tester.tap(find.byKey(const Key('timerDone')));
    await tester.pumpAndSettle();
    expect(app.todayCheckin, CheckinStatus.done);
  });

  testWidgets('leaving the timer asks first and saves nothing', (tester) async {
    final (app, _) = await _ready(tester);
    await tester.tap(find.byKey(const Key('stepStart')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('back')));
    await tester.pumpAndSettle();
    expect(find.text(s.leaveTimerQ), findsOneWidget);
    await tester.tap(find.text(s.stopTimer));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stepStart')), findsOneWidget);
    expect(app.todayCheckin, isNull);
  });

  testWidgets('"I did it already" checks in without the timer', (tester) async {
    final (app, _) = await _ready(tester);
    await tester.tap(find.byKey(const Key('checkinAlready')));
    await tester.pumpAndSettle();
    expect(app.todayCheckin, CheckinStatus.done);
    expect(find.byKey(const Key('stepStart')), findsNothing);
  });
}
