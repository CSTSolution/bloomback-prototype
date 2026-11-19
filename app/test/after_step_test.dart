// Chi's thread 0007: the sound and today's question after Done or Partly, and the research switch
// (design A-D in docs/design/new-features-2026-11-15.pdf). Persona An (thread 0004).
import 'dart:io';

import 'package:bloomback/app_state.dart';
import 'package:bloomback/data/models.dart';
import 'package:bloomback/data/store.dart';
import 'package:bloomback/l10n/strings.dart';
import 'package:bloomback/main.dart';
import 'package:bloomback/rules/plan.dart';
import 'package:bloomback/rules/quiz.dart';
import 'package:bloomback/rules/reminders.dart';
import 'package:bloomback/sound/after_sound.dart';
import 'package:bloomback/ui/after_step.dart';
import 'package:bloomback/ui/common.dart';
import 'package:bloomback/rules/org_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chi_fixes_4_7_test.dart' show an;
import 'fake_server.dart';

Future<(AppState, SilentSound)> _ready(
  WidgetTester tester, {
  int hour = 18,
  String sound = 'off',
  int quizPerDay = 1,
  bool headphones = false,
  bool checkIn = false,
  Set<Domain> domains = const {Domain.movement},
}) async {
  tester.view.physicalSize = const Size(1080, 4800);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final now = DateTime(2026, 11, 16, hour, 0);
  final silent = SilentSound(headphonesIn: headphones);
  final app = AppState(MemoryStore(), clock: () => now, account: FakeServer().account(), sound: silent);
  final nowMin = now.toUtc().millisecondsSinceEpoch ~/ 60000;
  final p = an(nowMin - 3 * 1440);
  await tester.runAsync(() async {
    await app.load();
    await app.saveName('An');
    final st = suggestedReminderSettings(p.shift, app.settings, habitId: 'stairs')
      ..sound = sound
      ..quizPerDay = quizPerDay;
    await app.finishOnboarding(
      p,
      initialPlan(profile: p, domains: domains, mainHabitId: 'stairs', nowMinute: nowMin)..moveChoice = 'keep',
      st,
    );
    if (checkIn) await app.checkIn(CheckinStatus.done);
  });
  await tester.pumpWidget(BloomBackApp(state: app));
  await tester.pumpAndSettle();
  return (app, silent);
}

Future<void> _tapDone(WidgetTester tester) async {
  await tester.tap(find.text(s.checkinDone));
  await tester.pumpAndSettle();
}

void main() {
  group('question bank (assets/quiz/questions.json)', () {
    final bank = parseQuizBank(File('assets/quiz/questions.json').readAsStringSync());

    test('the file is valid and every approved question has a source', () {
      expect(bank, isNotEmpty);
      for (final q in bank.where((q) => q.isApproved)) {
        expect(q.sources, isNotEmpty, reason: q.id);
        expect(q.answer, lessThan(q.choices.length), reason: q.id);
        if (q.topic == QuizTopic.numbers) expect(q.askDoctor, isTrue, reason: '${q.id}: numbers need "ask your doctor"');
      }
    });

    test('no judgement words of our own in the bank', () {
      final text = bank.map((q) => [q.question, ...q.choices, q.explanation].join(' ').toLowerCase()).join(' ');
      for (final w in ['bad', 'good result', 'wrong', 'correct!', 'score', 'streak']) {
        expect(text.contains(w), isFalse, reason: w);
      }
    });

    test('drafts without an approved date are never shown', () {
      final b = parseQuizBank('{"questions":[{"id":"draft-one","topic":"sleep","question":{"en":"Q?"},'
          '"choices":[{"en":"a"},{"en":"b"}],"answer":0,"explanation":{"en":"E."},"askDoctor":false,'
          '"sources":[{"title":"T","url":"https://example.org"}]}]}');
      expect(nextQuestion(b, domains: {Domain.sleep}, seen: [], shownToday: {}, shownCount: 0), isNull);
    });

    test('format errors name the question', () {
      expect(() => parseQuizBank('{"questions":[{"id":"x-1","topic":"diet"}]}'), throwsA(isA<QuizFormatError>()));
      expect(
          () => parseQuizBank('{"questions":[{"id":"x-1","topic":"sleep","question":{"en":"Q"},'
              '"choices":[{"en":"a"},{"en":"b"}],"answer":5,"explanation":{"en":"E"},"askDoctor":false,"sources":[]}]}'),
          throwsA(isA<QuizFormatError>()));
      expect(
          () => parseQuizBank('{"questions":[{"id":"x-1","topic":"sleep","question":{"en":"Q"},'
              '"choices":[{"en":"a"},{"en":"b"}],"answer":0,"explanation":{"en":"E"},"askDoctor":false,'
              '"sources":[],"approved":"2026-11-16"}]}'),
          throwsA(isA<QuizFormatError>()));
    });

    test('habit questions follow the user\'s area; about 1 in 5 is a numbers question', () {
      final b = [
        for (final (id, t) in [('s1', 'sleep'), ('s2', 'sleep'), ('m1', 'movement'), ('m2', 'movement'), ('m3', 'movement'),
          ('m4', 'movement'), ('n1', 'numbers')])
          QuizQuestion(
              id: id,
              topic: QuizTopic.values.byName(t),
              question: id,
              choices: const ['a', 'b'],
              answer: 0,
              explanation: 'e',
              askDoctor: t == 'numbers',
              sources: const [QuizSource('T', 'https://example.org')],
              approved: '2026-11-16'),
      ];
      final seen = <String>[];
      final order = <String>[];
      for (var i = 0; i < 5; i++) {
        final q = nextQuestion(b, domains: {Domain.movement}, seen: seen, shownToday: {}, shownCount: i)!;
        order.add(q.id);
        seen.add(q.id);
      }
      expect(order, ['m1', 'm2', 'm3', 'm4', 'n1']);
      // all movement and numbers seen: start again with the oldest
      expect(nextQuestion(b, domains: {Domain.movement}, seen: seen, shownToday: {}, shownCount: 5)!.id, 'm1');
    });
  });

  testWidgets('A-C: after Done the question card opens; another pick says "your answer", never wrong', (tester) async {
    final (app, _) = await _ready(tester);
    expect(find.byKey(const Key('quizCard')), findsNothing); // not before the small step
    await _tapDone(tester);
    expect(find.byKey(const Key('quizCard')), findsOneWidget);
    expect(find.byKey(const Key('nowPlayingCard')), findsNothing); // sound is off by default
    await tester.tap(find.byKey(const Key('quizOpen')));
    await tester.pumpAndSettle();
    final q = app.quizBank.firstWhere((x) => x.question == tester.widget<OrgText>(find.byKey(const Key('quizQuestion'))).text);
    expect(q.topic, isNot(QuizTopic.sleep)); // An chose movement
    expect(find.text(s.quizNoScore), findsOneWidget);
    // Check stays off until a choice is picked
    expect(tester.widget<FilledButton>(find.descendant(of: find.byKey(const Key('quizCheck')), matching: find.byType(FilledButton))).onPressed, isNull);
    final other = q.answer == 0 ? 1 : 0;
    await tester.tap(find.byKey(Key('quizChoice_$other')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quizCheck')));
    await tester.pumpAndSettle();
    expect(find.text(s.yourAnswer), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text(s.goodToKnow.toUpperCase()), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is OrgText && w.text == q.explanation), findsOneWidget);
    expect(find.textContaining('rong'), findsNothing); // no "wrong" / "Wrong"
    expect(find.byKey(const Key('askDoctorLine')), q.askDoctor ? findsOneWidget : findsNothing);
    await tester.ensureVisible(find.byKey(const Key('quizSources'))); // long explanations scroll on a small phone
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quizSources')));
    await tester.pumpAndSettle();
    expect(find.text(q.sources.first.url), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text(s.backToGarden), findsOneWidget);
    await tester.tap(find.byKey(const Key('quizDone')));
    await tester.pumpAndSettle();
    // one a day: the card is gone until tomorrow; only the id is kept, not the pick
    expect(find.byKey(const Key('quizCard')), findsNothing);
    expect(app.quiz['today'], [q.id]);
    expect(app.quiz.keys.toSet(), {'seen', 'count', 'day', 'today', 'skip'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Skip today" hides the card; Off shows none; 2 a day offers a next question', (tester) async {
    final (app, _) = await _ready(tester, checkIn: true);
    await tester.tap(find.byKey(const Key('quizSkipToday')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quizCard')), findsNothing);
    expect(app.quizSkippedToday, isTrue);
  });

  testWidgets('daily question Off: no card', (tester) async {
    await _ready(tester, checkIn: true, quizPerDay: 0);
    expect(find.byKey(const Key('quizCard')), findsNothing);
  });

  testWidgets('2 a day: the answer offers the next question', (tester) async {
    final (app, _) = await _ready(tester, checkIn: true, quizPerDay: 2, domains: {Domain.sleep, Domain.movement});
    expect(find.text(s.todaysQuestionSub(2)), findsOneWidget);
    await tester.tap(find.byKey(const Key('quizOpen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quizChoice_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quizCheck')));
    await tester.pumpAndSettle();
    expect(find.text(s.nextQuestion), findsOneWidget);
    await tester.tap(find.byKey(const Key('quizDone')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quizQuestion')), findsOneWidget);
    expect(app.quizLeftToday, 1);
  });

  testWidgets('sound: the chime plays after Done and Partly, not on a repeat tap', (tester) async {
    final (app, silent) = await _ready(tester, sound: 'chime');
    await _tapDone(tester);
    expect(silent.plays, [kChimes['bell']]);
    expect(find.byKey(const Key('nowPlayingCard')), findsOneWidget);
    // fix 8: the buttons are gone after a check-in; "Change" + the same answer adds nothing
    expect(find.text(s.checkinDone), findsNothing);
    expect(find.text(s.checkinResultTitle(CheckinStatus.done, s.habit('stairs'))), findsOneWidget);
    await tester.tap(find.byKey(const Key('checkinChange')));
    await tester.pumpAndSettle();
    await _tapDone(tester); // same answer again
    expect(silent.plays, hasLength(1));
    expect(app.checkins, hasLength(1));
    await tester.tap(find.byKey(const Key('checkinChange')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.checkinPartial));
    await tester.pumpAndSettle();
    expect(silent.plays, hasLength(2));
    expect(app.todayCheckin, CheckinStatus.partial);
  });

  testWidgets('sound in quiet hours: only with headphones', (tester) async {
    final (_, silent) = await _ready(tester, sound: 'chime', hour: 23); // An's quiet hours 22:00-06:00
    await _tapDone(tester);
    expect(silent.plays, isEmpty);
    expect(find.text(s.soundQuiet), findsOneWidget);
  });

  testWidgets('sound in quiet hours with headphones plays', (tester) async {
    final (_, silent) = await _ready(tester, sound: 'chime', hour: 23, headphones: true);
    await _tapDone(tester);
    expect(silent.plays, hasLength(1));
  });

  testWidgets('D: More › After my small step changes sound, chime and questions; research is off', (tester) async {
    final (app, silent) = await _ready(tester);
    await tester.tap(find.text(s.tabMore));
    await tester.pumpAndSettle();
    expect(find.text(s.afterStepRow('off', 1)), findsOneWidget);
    await tester.tap(find.byKey(const Key('more_afterStep')));
    await tester.pumpAndSettle();
    expect(find.text(s.afterStepBody), findsOneWidget);
    await tester.tap(find.byKey(const Key('sound_chime')));
    await tester.pumpAndSettle();
    expect(app.settings.sound, 'chime');
    await tester.tap(find.byKey(const Key('chime_wind')));
    await tester.pumpAndSettle();
    expect(app.settings.chime, 'wind');
    await tester.scrollUntilVisible(find.byKey(const Key('quiz_3')), 200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quiz_3')));
    await tester.pumpAndSettle();
    expect(app.settings.quizPerDay, 3);
    final research = find.byKey(const Key('choice_research'));
    await tester.scrollUntilVisible(research, 200, scrollable: find.byType(Scrollable).last);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -300)); // clear of the bottom bar
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(research).value, isFalse);
    await tester.tap(find.byKey(const Key('researchWhy')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Today nothing is sent'), findsOneWidget);
    expect(find.textContaining('Never your name'), findsOneWidget);
    expect(silent.plays, isEmpty); // choosing does not play by itself
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding screen 3 and Delete everything: research starts off', (tester) async {
    final (app, _) = await _ready(tester);
    expect(app.choices['research'], isFalse);
    await app.saveChoices({...app.choices, 'research': true});
    await tester.runAsync(app.deleteAllOnPhone);
    expect(app.choices['research'], isFalse);
    expect(app.quiz, isEmpty);
  });

  test('short organisation names: found in order, each once; CDC and CC BY lines', () {
    expect(orgNamesIn('CDC (U.S. Centers…), NIOSH and CDC again; WHO 2020 (BJSM; CC BY 4.0)'), ['CDC', 'NIOSH', 'WHO', 'BJSM']);
    expect(orgNamesIn('A WHOLE word only: CDCs, WHOever'), isEmpty);
    expect(needsCdcLine('NIOSH Training for Nurses'), isTrue);
    expect(isCcBy4('WHO 2020 (Bull et al., BJSM 2020; CC BY 4.0)'), isTrue);
    final bank = parseQuizBank(File('assets/quiz/questions.json').readAsStringSync());
    for (final q in bank) {
      for (final n in orgNamesIn([q.question, q.explanation, ...q.choices, ...q.sources.map((x) => x.title)].join(' '))) {
        expect(kOrgNames[n], isNotNull, reason: '${q.id}: $n');
      }
    }
  });

  testWidgets('the answer shows "?" for CDC and the CDC reuse line under its source', (tester) async {
    final (app, _) = await _ready(tester, checkIn: true, domains: {Domain.sleep});
    final q = app.quizBank.firstWhere((x) => x.question.contains('CDC') || x.explanation.contains('CDC'));
    await tester.pumpWidget(BloomBackApp(state: app));
    await tester.pumpAndSettle();
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute<void>(builder: (_) => QuizScreen(question: q)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quizChoice_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quizCheck')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('org_CDC')), findsWidgets);
    await tester.tap(find.byKey(const Key('org_CDC')).first);
    await tester.pumpAndSettle();
    expect(find.text('CDC: ${kOrgNames['CDC']}'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10)); // stays until closed (fix 13)
    expect(find.text('CDC: ${kOrgNames['CDC']}'), findsOneWidget);
    await tester.tap(find.text(s.ok));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('quizSources')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quizSources')));
    await tester.pumpAndSettle();
    expect(find.text(kCdcAttribution), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
