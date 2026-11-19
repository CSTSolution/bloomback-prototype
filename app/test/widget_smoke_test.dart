// Renders every screen of Chi's design with the demo band's data and walks the
// onboarding one answer at a time, checking for an exception after every tap
// (a null-check crash like that was found on the emulator on 13 Nov).
import 'package:bloomback/app_state.dart';
import 'package:bloomback/data/models.dart';
import 'package:bloomback/data/store.dart';
import 'package:bloomback/demo/scenarios.dart';
import 'package:bloomback/l10n/strings.dart';
import 'package:bloomback/main.dart';
import 'package:bloomback/rules/plan.dart';
import 'package:bloomback/rules/reminders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_server.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

/// Taps and checks for an exception after every single answer.
class Walker {
  final WidgetTester tester;
  Walker(this.tester);

  void ok(String what) {
    final e = tester.takeException();
    if (e is FlutterError) fail('after $what: ${e.diagnostics.map((d) => d.toStringDeep()).join('\n')}');
    expect(e, isNull, reason: 'after $what');
  }

  /// Scrolls the visible list down, then up, until [f] is built.
  Future<void> scrollTo(Finder f) async {
    final list = find.byType(Scrollable).hitTestable().first;
    try {
      await tester.scrollUntilVisible(f, 150, scrollable: list, maxScrolls: 30);
    } catch (_) {
      await tester.scrollUntilVisible(f, -150, scrollable: list, maxScrolls: 60);
    }
  }

  Future<void> tap(Finder f, String what) async {
    if (f.evaluate().isEmpty) {
      await scrollTo(f);
    }
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
    ok(what);
  }

  Future<void> text(String t) => tap(find.text(t), 'tapping "$t"');
  Future<void> key(String k) => tap(find.byKey(Key(k)), 'tapping $k');

  Future<void> type(String k, String v) async {
    final f = find.byKey(Key(k));
    if (f.evaluate().isEmpty) {
      await scrollTo(f);
    }
    await tester.enterText(f, v);
    await tester.pumpAndSettle();
    ok('typing "$v" into $k');
  }

  Future<void> next([String? label]) => tap(find.widgetWithText(FilledButton, label ?? s.continueLabel), 'Continue');

  FilledButton button(String label) => tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

  Future<void> back() => key('back');

  /// Finds [f] in the lazily built list (scrolling to it) and expects it once.
  Future<void> see(Finder f) async {
    if (f.evaluate().isEmpty) {
      await scrollTo(f);
    }
    expect(f, findsOneWidget);
  }
}

Profile ravi(int startMinute, {ShiftType shift = ShiftType.nightFixed, String? nextNights}) => Profile(
      goalIds: ['tiredOnWaking', 'shiftSleep'],
      mainGoalId: 'tiredOnWaking',
      motivation: kRaviMotivation,
      activity: WorkActivity.standingLight,
      shift: shift,
      place: WorkPlace.indoor,
      selfSleepMinutes: 330,
      selfWalkMinutes: 60,
      startMinute: startMinute,
      heightCm: 172,
      weightKg: 74,
      city: City.abuDhabi,
      nextNightsDate: nextNights,
    );

void main() {
  testWidgets('onboarding in Chi\'s order, one answer at a time, to Today', (tester) async {
    phone(tester);
    final now = DateTime(2026, 11, 13, 7, 32);
    final server = FakeServer();
    final app = AppState(MemoryStore(), clock: () => now, account: server.account());
    await tester.runAsync(app.load);
    await tester.pumpWidget(BloomBackApp(state: app));
    await tester.pumpAndSettle();
    final w = Walker(tester);

    // 1 Start
    expect(find.text(s.getStarted), findsOneWidget);
    expect(find.textContaining(s.tagline1), findsOneWidget);
    await w.text(s.getStarted);
    // 2 Sign in with an email code; the first name goes with the new account, then on to screen 3.
    expect(find.text(s.signInTitle), findsOneWidget);
    await w.type('name', 'Ravi');
    await w.text(s.withEmail);
    await w.type('emailField', 'ravi@example.com');
    await w.key('emailNext');
    expect(find.text(s.codeBody('ravi@example.com')), findsOneWidget);
    await w.type('codeField', '123456');
    await w.key('emailNext');
    expect(app.account.signedIn, isTrue);
    expect(server.name, 'Ravi');
    // 3 Your choices
    expect(find.text(s.choicesTitle), findsOneWidget);
    await w.next();
    // 4 Work, one answer at a time; Continue once activity, shift and place are given (city optional, fix 10).
    expect(find.text('1 / 5'), findsOneWidget);
    expect(w.button(s.continueLabel).onPressed, isNull);
    await w.text('Standing / light walking');
    await w.text('Fixed night');
    await w.text('Indoors (AC)');
    expect(w.button(s.continueLabel).onPressed, isNotNull, reason: 'city is optional (Chi, fix 10)');
    await w.key('city');
    await w.tap(find.text('Abu Dhabi').last, 'city');
    await w.next();
    // 5 Sleep and movement now
    expect(find.text(s.nowTitle), findsOneWidget);
    // Fixed night picked on screen 4: day sleep 08:30 -> 14:00 (Chi's screen 5).
    expect(find.text(s.hoursOfSleep(330)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('sleepStart')), matching: find.textContaining('08:30')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('wakeTime')), matching: find.textContaining('14:00')), findsOneWidget);
    // Days off (Chi's screen 5, 14/11): 01:00 -> 08:30; the spread is computed, never asked.
    expect(find.descendant(of: find.byKey(const Key('offSleepStart')), matching: find.textContaining('01:00')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('offWakeTime')), matching: find.textContaining('08:30')), findsOneWidget);
    expect(find.text(s.spreadComputed(450)), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    await w.key('addNap'); // 20:00-20:30
    expect(find.text(s.hoursOfSleep(360)), findsOneWidget);
    await w.key('days_3');
    await w.key('minMore');
    expect(find.text(s.exerciseTotal(75)), findsOneWidget);
    await w.next();
    // 6 Body measures: optional (Chi, fix 9), with "Skip for now"; one optional number with its source.
    expect(w.button(s.continueLabel).onPressed, isNotNull);
    expect(find.byKey(const Key('skipBody')), findsOneWidget);
    await w.type('height', '172');
    await w.type('weight', '78');
    await w.key('marker_bp');
    await w.type('bpSys', '135');
    await w.type('bpDia', '85');
    await w.tap(find.widgetWithText(FilledButton, s.save), 'save BP');
    expect(find.text('135 / 85'), findsOneWidget);
    await w.next();
    // 7 / 7b Safety: a "Yes" shows the note and "I understand · Continue"; never blocks.
    await w.key('q1_yes');
    expect(find.byKey(const Key('safetyNote')), findsOneWidget);
    expect(find.text(s.understandContinue), findsOneWidget);
    await w.key('q1_no');
    await w.key('q2_no');
    expect(find.byKey(const Key('safetyNote')), findsNothing);
    await w.next();
    // 8 Goals: cards, then "Which one matters most?", then the reason.
    expect(w.button(s.continueLabel).onPressed, isNull);
    await w.key('goal_shiftSleep');
    await w.key('goal_tiredOnWaking');
    expect(find.text(s.mattersMost), findsOneWidget);
    await w.key('main_tiredOnWaking');
    await w.type('motivation', kRaviMotivation);
    await w.next();
    // 9 Your picture: BloomBack suggests sleep; the user can pick any.
    expect(find.text(s.pictureTitle), findsOneWidget);
    expect(find.text(s.suggestsStart(Domain.sleep)), findsOneWidget);
    await w.key('area_2');
    await w.key('area_1');
    await w.key('area_0');
    await w.next();
    // 10 Sleep plan: both paces shown (Chi Q3), "BloomBack suggestion".
    expect(find.text(s.pace30), findsOneWidget);
    expect(find.text(s.pace15), findsOneWidget);
    expect(find.text(s.bbSuggestion), findsWidgets);
    await w.key('pace_slower');
    await w.key('pace_own');
    await w.key('pace_follow');
    await w.next();
    // 11 Pick one small step: 3 habits for a night shift, a backup, the sentence.
    expect(find.text(s.stepTitle), findsOneWidget);
    expect(find.byKey(const Key('habit_homeToBed')), findsOneWidget);
    expect(find.byKey(const Key('habit_blackout')), findsOneWidget);
    expect(find.byKey(const Key('habit_napBeforeShift')), findsOneWidget);
    expect(find.text(s.cue(s.habitAnchor('homeToBed'), s.habitAction('homeToBed'))), findsOneWidget);
    // Straight to bed: reminded at the end of the shift (Chi's screen 11).
    expect(find.widgetWithText(OutlinedButton, '07:30'), findsOneWidget);
    // A nap before the shift: reminded before the shift instead; then back.
    await w.key('habit_napBeforeShift');
    expect(find.widgetWithText(OutlinedButton, '16:00'), findsOneWidget);
    await w.key('habit_homeToBed');
    expect(find.widgetWithText(OutlinedButton, '07:30'), findsOneWidget);
    await w.text(s.startTomorrow);

    expect(app.onboarded, isTrue);
    expect(app.displayName, 'Ravi');
    expect(app.profile!.selfSleepMinutes, 360);
    expect(app.profile!.selfWalkMinutes, 75);
    expect(app.profile!.selfOffSleepStart, 60);
    expect(app.profile!.selfOffWakeTime, 510);
    expect(app.profile!.selfBedtimeSpreadMinutes, 450);
    expect(app.profile!.city, City.abuDhabi);
    expect(app.profile!.askDoctorFirst, isFalse);
    expect(app.plan!.domains, {Domain.sleep});
    expect(app.plan!.mainHabitId, 'homeToBed');
    expect(app.plan!.sleepIncrement, 30);
    expect(app.plan!.sleepTargetMinutes, 390);
    expect(app.plan!.backupHabitIds, ['blackout']);
    expect(app.settings.reminder1, 7 * 60 + 30);
    expect(app.settings.reminder2, -1);
    expect(app.settings.quietStart, 8 * 60);
    expect(app.biomarkers!.systolic, 135);
    expect(app.biomarkers!.sources['bp'], MarkerSource.selfReport);
    // Today, after a night shift.
    expect(find.text('Rest well, Ravi'), findsOneWidget);
    expect(find.byKey(const Key('stepCard')), findsOneWidget);
  });

  testWidgets('sign in: Google not ready, a wrong code, "Try without an account", Arabic coming soon', (tester) async {
    phone(tester);
    final server = FakeServer();
    final app = AppState(MemoryStore(), clock: () => DateTime(2026, 11, 13, 9), account: server.account());
    await tester.runAsync(app.load);
    await tester.pumpWidget(BloomBackApp(state: app));
    await tester.pumpAndSettle();
    final w = Walker(tester);
    await w.key('arabic');
    expect(find.text(s.arabicSoonTitle), findsOneWidget);
    await w.tap(find.widgetWithText(FilledButton, s.ok), 'close');
    await w.text(s.getStarted);
    // no Apple button off iPhone; Google says it is not set up
    expect(find.byKey(const Key('signInApple')), findsNothing);
    await w.text(s.withGoogle);
    expect(find.textContaining('Google sign-in is not ready'), findsOneWidget);
    await w.text(s.withEmail);
    await w.type('emailField', 'ravi@example.com');
    await w.key('emailNext');
    await w.type('codeField', '000000');
    await w.key('emailNext');
    expect(find.byKey(const Key('emailProblem')), findsOneWidget);
    expect(app.account.signedIn, isFalse);
    await w.back();
    await w.back();
    await w.key('tryWithout');
    expect(find.text(s.choicesTitle), findsOneWidget);
    // "Coming later" toggles do nothing yet; "use my answers" is needed.
    expect(tester.widget<Switch>(find.byKey(const Key('choice_sync'))).onChanged, isNull);
    expect(tester.widget<Switch>(find.byKey(const Key('choice_share'))).onChanged, isNull);
    await w.key('choice_useAnswers');
    expect(w.button(s.continueLabel).onPressed, isNull);
    expect(find.text(s.useAnswersNeeded), findsOneWidget);
    await w.key('choice_useAnswers');
    expect(w.button(s.continueLabel).onPressed, isNotNull);
  });

  // A1 inputs: height, weight and city one at a time (in two orders), moderate work
  // minutes (Chi Q7: 100 %), the D2 note from BMI, the weight card's 300 goal.
  for (final cityFirst in [false, true]) {
    testWidgets('onboarding: city, height, weight one at a time (city first: $cityFirst)', (tester) async {
      phone(tester);
      final app = AppState(MemoryStore(), clock: () => DateTime(2026, 11, 13, 10));
      await tester.runAsync(app.load);
      await tester.pumpWidget(BloomBackApp(state: app));
      await tester.pumpAndSettle();
      final w = Walker(tester);
      await w.text(s.getStarted);
      await w.key('tryWithout');
      await w.next();
      if (cityFirst) {
        await w.key('city');
        await w.tap(find.text('Other UAE').last, 'city');
      }
      await w.text('Moderate');
      await w.text('Rotating');
      expect(find.text(s.obNextNightsQ), findsOneWidget);
      await w.text('Outdoors');
      if (!cityFirst) {
        expect(w.button(s.continueLabel).onPressed, isNotNull, reason: 'city is optional');
        await w.key('city');
        await w.tap(find.text('Dubai').last, 'city');
      }
      await w.next();
      // Moderate work: confirmed moderate minutes at work (talk test).
      await w.type('workBrisk', '120');
      await w.next();
      expect(w.button(s.continueLabel).onPressed, isNotNull, reason: 'height and weight are optional (fix 9)');
      await w.type('height', '1'); // partial typing is not an error, but an out-of-range value holds Continue
      expect(w.button(s.continueLabel).onPressed, isNull);
      await w.type('height', '17');
      await w.type('height', '170');
      expect(w.button(s.continueLabel).onPressed, isNotNull);
      await w.type('weight', '9');
      expect(w.button(s.continueLabel).onPressed, isNull);
      await w.type('weight', '95');
      expect(w.button(s.continueLabel).onPressed, isNotNull);
      await w.type('height', ''); // cleared again: still fine, no crash
      expect(w.button(s.continueLabel).onPressed, isNotNull);
      await w.type('height', '170');
      await w.next();
      await w.key('q1_no');
      await w.key('q2_no');
      await w.next();
      await w.key('goal_weight');
      await w.next();
      expect(find.text(s.suggestsStart(Domain.movement)), findsOneWidget);
      await w.next();
      // Plan: work minutes counted, BMI 95 / 1.70² = 32.9 -> the D2 note; plan unchanged by it.
      expect(find.textContaining('counted from'), findsWidgets);
      expect(find.text(s.doctorNote), findsOneWidget);
      await w.text(s.goal300);
      await w.next();
      await w.text(s.startTomorrow);
      expect(app.onboarded, isTrue);
      expect(app.profile!.heightCm, 170);
      expect(app.profile!.weightKg, 95);
      expect(app.profile!.city, cityFirst ? City.otherUae : City.dubai);
      expect(app.plan!.movementGoal, 300);
      expect(app.plan!.workCredit, 120);
    });
  }

  // C5: Lapse Radar heads-up the day before nights, and the barrier "Move" that
  // really moves today's reminder from the sheet. Then More: work answers, Ramadan.
  testWidgets('Today: nights heads-up, Move sheet; More: what we use, Ramadan dates', (tester) async {
    phone(tester);
    final now = DateTime(2026, 11, 13, 9, 0);
    final app = AppState(MemoryStore(), clock: () => now);
    final nowMin = now.toUtc().millisecondsSinceEpoch ~/ 60000;
    final p = Profile(
      goalIds: ['energy'],
      mainGoalId: 'energy',
      activity: WorkActivity.standingLight,
      shift: ShiftType.rotating,
      place: WorkPlace.indoor,
      selfSleepMinutes: 400,
      selfWalkMinutes: 30,
      startMinute: nowMin - 10 * 1440,
      heightCm: 170,
      weightKg: 70,
      city: City.sharjah,
      nextNightsDate: '2026-11-14',
    );
    await tester.runAsync(() async {
      await app.load();
      await app.finishOnboarding(
          p,
          initialPlan(profile: p, domains: {Domain.movement}, mainHabitId: 'briskWalk', nowMinute: nowMin - 10 * 1440),
          suggestedReminderSettings(p.shift, app.settings));
      for (var d = 0; d < 3; d++) {
        await app.store.saveCheckin(Checkin(nowMin - d * 1440, CheckinStatus.partial, DataSource.selfReport));
      }
      await app.load();
    });
    await tester.pumpWidget(BloomBackApp(state: app));
    await tester.pumpAndSettle();
    final w = Walker(tester);
    expect(find.text('Nights are coming'), findsOneWidget);
    expect(find.textContaining('tomorrow'), findsWidgets);
    expect(find.text('A bit hard lately?'), findsOneWidget);
    await w.text(s.move);
    expect(find.text('Move today\'s reminder'), findsOneWidget);
    await w.key('move_1');
    await tester.tap(find.text('OK')); // time picker: keep its time (18:30)
    await tester.pumpAndSettle();
    w.ok('move');
    expect(app.settings.movedDate, '2026-11-13');
    expect(app.settings.movedIndex, 1);
    expect(app.settings.movedTime, 18 * 60 + 30);
    expect(find.text('Reminder moved to 18:30.'), findsOneWidget);
    // More > What we use: the work answers (next switch to nights).
    await w.tap(find.text(s.tabMore).last, 'More tab');
    await w.key('more_whatWeUse');
    expect(find.text(s.obNextNightsQ), findsOneWidget);
    await w.back();
    // More > Ramadan: Umm al-Qura dates (Chi's screen 17), fasting mode, save.
    await w.key('more_ramadan');
    expect(find.text('Mon 8 Feb – Mon 8 Mar 2027'), findsOneWidget);
    expect(find.text(s.ummAlQura), findsOneWidget);
    await w.key('thatsRight');
    expect(find.byKey(const Key('ramadanStep')), findsOneWidget);
    expect(find.textContaining(s.habit('walkAfterIftar')), findsOneWidget);
    await w.key('ramadanSave');
    expect(app.fasting!.from, '2027-02-08');
    expect(app.fasting!.to, '2027-03-08');
  });

  testWidgets('every tab and the screens behind More, with demo band data', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final now = DateTime(2026, 11, 13, 17, 0);
    final app = AppState(MemoryStore(), clock: () => now);
    final nowMin = now.toUtc().millisecondsSinceEpoch ~/ 60000;
    final p = ravi(nowMin - 30 * 1440)..askDoctorFirst = true;
    await tester.runAsync(() async {
      await app.load();
      await app.saveName('Ravi');
      await app.finishOnboarding(
          p,
          initialPlan(
              profile: p,
              domains: {Domain.sleep, Domain.movement},
              mainHabitId: 'homeToBed',
              backupHabitIds: ['blackout'],
              nowMinute: nowMin),
          suggestedReminderSettings(p.shift, app.settings));
      final found = await app.link.scan().first;
      await app.pair(found.single);
      await app.checkIn(CheckinStatus.done); // today checked in: no welcome back
    });
    expect(app.minutes, isNotEmpty);
    // The app syncs the paired band when it opens: let that finish in real time.
    await tester.runAsync(() async {
      await tester.pumpWidget(BloomBackApp(state: app));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      for (var i = 0; i < 200 && app.syncing; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    expect(app.syncing, isFalse);
    await tester.pumpAndSettle();
    final w = Walker(tester);

    // Today
    expect(find.text(s.todayHabit.toUpperCase()), findsOneWidget);
    await w.see(find.byKey(const Key('sleepWeek')));
    await w.see(find.text(s.bandSleepNote)); // Chi Q2 wording with band sleep
    await w.see(find.byKey(const Key('moveCard')));
    await w.see(find.byKey(const Key('gardenStrip')));
    await w.key('stepWhy');
    expect(find.text(s.whyTitle), findsOneWidget);
    expect(find.text(s.yourTarget), findsOneWidget);
    expect(find.text('"Go directly to bed when you arrive home."'), findsOneWidget);
    expect(find.byKey(const Key('openSource')), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    // 4 weeks in (30 days): the Today card opens screen 15.
    await w.key('fourWeeksCard');
    expect(find.text(s.howGoing), findsOneWidget);
    await w.key('pgic_1');
    expect(find.text(s.numbersW1W4.toUpperCase()), findsOneWidget);
    await w.key('review_keep');
    expect(find.byKey(const Key('fourWeeksCard')), findsNothing);

    // Plan
    await w.tap(find.text(s.tabPlan).last, 'Plan tab');
    expect(find.byKey(const Key('mainGoal')), findsOneWidget);
    expect(find.text(s.thisWeekShort), findsOneWidget);
    await w.see(find.byKey(const Key('movePlan')));
    await w.key('changePace');
    await w.text(s.pace15);
    expect(app.plan!.sleepIncrement, 15);

    // Garden
    await w.tap(find.text(s.tabGarden).last, 'Garden tab');
    expect(find.byKey(const Key('monthGrid')), findsOneWidget);
    await w.see(find.text(s.cameBack));
    await w.key('weekByWeek');
    expect(find.text(s.weekByWeek), findsWidgets);
    await w.back();

    // More and every screen behind it
    await w.tap(find.text(s.tabMore).last, 'More tab');
    for (final row in ['more_reminders', 'more_companion', 'more_ramadan', 'more_whatWeUse', 'more_sources', 'more_about']) {
      await w.key(row);
      await w.back();
    }
    await w.key('more_companion');
    await w.key('sendInvite');
    expect(find.text(s.invitePilotBody), findsOneWidget);
    await w.tap(find.widgetWithText(FilledButton, s.ok), 'close');
    await w.back();
    await w.key('more_band');
    expect(find.text(s.yourBand), findsOneWidget);
    expect(find.byKey(const Key('whyEstimate')), findsOneWidget);
    expect(find.text(s.bandSleepNote), findsOneWidget);
    expect(find.text(s.nextToOwn(60)), findsOneWidget);
    await w.key('bandSettings');
    expect(find.text(s.bandForget), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    await w.back();
    await w.key('more_language');
    expect(find.text(s.arabicSoonTitle), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    // Back to Today and check in.
    await w.tap(find.text(s.tabToday).last, 'Today tab');
    // the demo band already checked in today: the result row shows, "Change" brings the buttons back (fix 8)
    await w.key('checkinChange');
    await w.text(s.checkinPartial);
    expect(app.todayCheckin, CheckinStatus.partial);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Welcome back is its own screen; Restart today goes back to Today', (tester) async {
    phone(tester);
    final app = AppState(MemoryStore(), clock: () => DateTime(2026, 11, 13, 17, 0));
    await tester.runAsync(() async {
      await app.load();
      await app.applyScenario(DemoScenario.welcomeBack);
    });
    await tester.pumpWidget(BloomBackApp(state: app));
    await tester.pumpAndSettle();
    final w = Walker(tester);
    // The title is rich text (the sprout is inline, joined to the last word).
    expect(find.textContaining(s.welcomeBackName('Ravi')), findsOneWidget);
    expect(find.text('"$kRaviMotivation"'), findsOneWidget);
    expect(find.byKey(const Key('stepCard')), findsNothing);
    await w.text('Tired');
    await w.key('restart_swap');
    await w.key('restart_smaller');
    await w.text(s.restartToday);
    expect(find.byKey(const Key('stepCard')), findsOneWidget);
    expect(app.review['barriers'], contains('Tired'));
  });

  testWidgets('band pairing with the demo band: 6-digit code, then connected', (tester) async {
    phone(tester);
    final now = DateTime(2026, 11, 13, 17, 0);
    final app = AppState(MemoryStore(), clock: () => now);
    final nowMin = now.toUtc().millisecondsSinceEpoch ~/ 60000;
    final p = ravi(nowMin);
    await tester.runAsync(() async {
      await app.load();
      await app.finishOnboarding(
          p,
          initialPlan(profile: p, domains: {Domain.sleep}, mainHabitId: 'homeToBed', nowMinute: nowMin),
          suggestedReminderSettings(p.shift, app.settings));
    });
    await tester.pumpWidget(BloomBackApp(state: app));
    await tester.pumpAndSettle();
    final w = Walker(tester);
    await w.tap(find.text(s.tabMore).last, 'More tab');
    await w.key('more_band');
    expect(find.text(s.pairTitle), findsOneWidget);
    expect(find.text(s.bandPrivacy), findsOneWidget);
    expect(w.button(s.pairBand).onPressed, isNull);
    for (var i = 0; i < 6; i++) {
      await w.type('code_$i', '482913'[i]);
    }
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('pairBand')));
      for (var i = 0; i < 100 && (app.settings.bandId == null || app.syncing || app.minutes.isEmpty); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pumpAndSettle();
    w.ok('pair');
    expect(app.settings.bandId, isNotNull);
    expect(find.text(s.yourBand), findsOneWidget);
    expect(find.text(s.bandSleepNote), findsOneWidget);
  });

  testWidgets('Plan: add movement when ready (not started yet)', (tester) async {
    phone(tester);
    final now = DateTime(2026, 11, 13, 9, 0);
    final app = AppState(MemoryStore(), clock: () => now);
    final nowMin = now.toUtc().millisecondsSinceEpoch ~/ 60000;
    final p = ravi(nowMin);
    await tester.runAsync(() async {
      await app.load();
      await app.finishOnboarding(
          p,
          initialPlan(profile: p, domains: {Domain.sleep}, mainHabitId: 'homeToBed', nowMinute: nowMin),
          suggestedReminderSettings(p.shift, app.settings));
    });
    await tester.pumpWidget(BloomBackApp(state: app));
    await tester.pumpAndSettle();
    final w = Walker(tester);
    await w.tap(find.text(s.tabPlan).last, 'Plan tab');
    expect(find.byKey(const Key('moveNotStarted')), findsOneWidget);
    await w.key('addMove');
    await w.tap(find.widgetWithText(FilledButton, s.addMoveConfirm), 'add');
    expect(app.plan!.domains, {Domain.sleep, Domain.movement});
    expect(find.byKey(const Key('movePlan')), findsOneWidget);
    // "Change" opens onboarding at the work page with the answers kept.
    await w.key('changeGoal');
    expect(find.text(s.workTitle), findsOneWidget);
    expect(w.button(s.continueLabel).onPressed, isNotNull);
  });
  // Chi, thread 0004 (14/11): already at 225 min a week, the plan must not read "a gentle path to 150";
  // screen 10b offers keep (suggested), towards 300 or muscle strengthening, never a lower goal.
  for (final choice in ['moveKeep', 'move300', 'moveStrength']) {
    testWidgets('screen 10b: already active (225 min), choice $choice', (tester) async {
      phone(tester);
      final app = AppState(MemoryStore(), clock: () => DateTime(2026, 11, 14, 10));
      await tester.runAsync(app.load);
      await tester.pumpWidget(BloomBackApp(state: app));
      await tester.pumpAndSettle();
      final w = Walker(tester);
      await w.text(s.getStarted);
      await w.key('tryWithout');
      await w.next();
      await w.text('Mostly sitting');
      await w.text('Fixed day');
      await w.text('Indoors (AC)');
      await w.key('city');
      await w.tap(find.text('Dubai').last, 'city');
      await w.next();
      await w.key('days_5');
      for (var i = 0; i < 5; i++) {
        await w.key('minMore');
      }
      expect(find.text(s.exerciseTotal(225)), findsOneWidget);
      await w.next();
      await w.type('height', '170');
      await w.type('weight', '70');
      await w.next();
      await w.key('q1_no');
      await w.key('q2_no');
      await w.next();
      await w.key('goal_stronger');
      await w.next();
      await w.key('area_1');
      await w.next();
      expect(find.text(s.moveHealthyTitle), findsWidgets);
      expect(find.text(s.movePathTitle), findsNothing);
      expect(find.text(s.goal150), findsNothing, reason: 'no goal lower than the current level');
      expect(find.text(s.aboutWeekly(225)), findsOneWidget);
      expect(find.text(s.neverLower), findsOneWidget);
      await w.key(choice);
      await w.next();
      if (choice == 'moveStrength') {
        expect(find.byKey(const Key('habit_strength')), findsOneWidget);
      }
      await w.text(s.startTomorrow);
      expect(app.plan!.movementGoal, choice == 'move300' ? 300 : 150);
      expect(app.plan!.mainHabitId == 'strength', choice == 'moveStrength');
    });
  }

}
