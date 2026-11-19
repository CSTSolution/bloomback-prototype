import 'package:bloomback/data/models.dart';
import 'package:bloomback/rules/habits.dart';
import 'package:bloomback/rules/levels.dart';
import 'package:bloomback/rules/plan.dart';
import 'package:bloomback/rules/reminders.dart';
import 'package:bloomback/rules/safety.dart';
import 'package:flutter_test/flutter_test.dart';

Profile ravi({
  ShiftType shift = ShiftType.nightFixed,
  WorkPlace place = WorkPlace.indoor,
  WorkActivity activity = WorkActivity.standingLight,
  int walk = 60,
  int sleep = 330,
  List<String> goals = const ['tiredOnWaking', 'shiftSleep'],
}) =>
    Profile(
      goalIds: goals,
      mainGoalId: goals.first,
      motivation: 'So I still have energy to video-call my kids',
      activity: activity,
      shift: shift,
      place: place,
      selfSleepMinutes: sleep,
      selfWalkMinutes: walk,
      startMinute: 0,
    );

void main() {
  group('B4 levels', () {
    test('movement: 0 / <150 / 150-300 / >300', () {
      expect(moveLevel(0), MoveLevel.inactive);
      expect(moveLevel(1), MoveLevel.insufficient);
      expect(moveLevel(149), MoveLevel.insufficient);
      expect(moveLevel(150), MoveLevel.active);
      expect(moveLevel(300), MoveLevel.active);
      expect(moveLevel(301), MoveLevel.highlyActive);
    });

    test('sleep: <7 h vs >= 7 h', () {
      expect(sleepLevel(330), SleepLevel.short);
      expect(sleepLevel(419), SleepLevel.short);
      expect(sleepLevel(420), SleepLevel.enough);
    });

    test('both-area cards suggest the bigger gap', () {
      expect(sleepGapIsBigger(330, 120), isTrue); // Ravi-like sleep gap 21% vs move 20%
      expect(sleepGapIsBigger(420, 0), isFalse);
    });
  });

  group('C2 plan', () {
    test('from 0: the ladder 5x3, 10x3, 10x5 ... 30x5', () {
      final p = initialPlan(profile: ravi(walk: 0), domains: {Domain.movement}, mainHabitId: 'briskWalk', nowMinute: 0);
      final totals = <int>[];
      var cur = p;
      for (var i = 0; i < 7; i++) {
        totals.add(movementTarget(cur).weeklyMinutes);
        cur = stepUp(cur, 0);
      }
      expect(totals, [15, 30, 50, 75, 100, 125, 150]);
      expect(movementTarget(cur).weeklyMinutes, 150); // holds at the guideline
      expect(canStepUpMovement(cur), isFalse);
      final first = movementTarget(p);
      expect([first.perSession, first.sessions], [5, 3]);
    });

    test('with a base: +10 min a week up to 150, then hold', () {
      var p = initialPlan(profile: ravi(walk: 60), domains: {Domain.movement}, mainHabitId: 'briskWalk', nowMinute: 0);
      expect(movementTarget(p).weeklyMinutes, 70);
      for (var i = 0; i < 20; i++) {
        p = stepUp(p, 0);
      }
      expect(movementTarget(p).weeklyMinutes, 150);
      expect(movementTarget(p).holding, isTrue);
    });

    test('already active: keep the rhythm', () {
      final p = initialPlan(profile: ravi(walk: 200), domains: {Domain.movement}, mainHabitId: 'briskWalk', nowMinute: 0);
      expect(movementTarget(p).weeklyMinutes, 200);
      expect(canStepUpMovement(p), isFalse);
    });

    test('C3 example: target 70, done 60 -> one or two short walks', () {
      expect(movementGapDose(70, 60), (5, 2));
      expect(movementGapDose(70, 80), isNull);
    });

    test('sleep: +30 min steps from 5.5 h up to 7 h, never past', () {
      var p = initialPlan(profile: ravi(), domains: {Domain.sleep}, mainHabitId: 'homeToBed', nowMinute: 0);
      final targets = [p.sleepTargetMinutes];
      while (canStepUpSleep(p)) {
        p = stepUp(p, 0);
        targets.add(p.sleepTargetMinutes);
      }
      expect(targets, [360, 390, 420]); // 6 h, 6.5 h, 7 h (rules C7 Ravi)
      p = stepDown(p, 0, 330);
      expect(p.sleepTargetMinutes, 390);
    });

    test('step down never goes below the start', () {
      final p = initialPlan(profile: ravi(walk: 0), domains: {Domain.movement, Domain.sleep}, mainHabitId: 'briskWalk', nowMinute: 0);
      final d = stepDown(p, 0, 330);
      expect(d.movementStep, 0);
      expect(d.sleepTargetMinutes, 330);
    });
  });

  group('C5 nudges', () {
    Map<int, CheckinStatus> days(Map<int, CheckinStatus> m) => m;
    const done = CheckinStatus.done, partial = CheckinStatus.partial, no = CheckinStatus.notToday;

    test('step up after 5 of 7 days, only after a week on the step', () {
      final by = days({94: done, 95: done, 96: partial, 97: done, 98: done, 99: no, 100: done});
      expect(nudgeFor(byDay: by, today: 100, stepStartDay: 93, firstDay: 80, canStepUp: true), Nudge.stepUp);
      expect(nudgeFor(byDay: by, today: 100, stepStartDay: 96, firstDay: 80, canStepUp: true), Nudge.none);
      expect(nudgeFor(byDay: by, today: 100, stepStartDay: 93, firstDay: 80, canStepUp: false), Nudge.none);
    });

    test('difficulty after 3 partly in 5 days', () {
      final by = days({96: partial, 97: done, 98: partial, 99: partial, 100: done});
      expect(nudgeFor(byDay: by, today: 100, stepStartDay: 90, firstDay: 80, canStepUp: true), Nudge.difficulty);
    });

    test('welcome back after 2 days without it; no reset', () {
      final by = days({90: done, 97: done, 98: no});
      expect(nudgeFor(byDay: by, today: 100, stepStartDay: 90, firstDay: 80, canStepUp: true), Nudge.welcomeBack);
      // Checking in today clears it.
      by[100] = partial;
      expect(nudgeFor(byDay: by, today: 100, stepStartDay: 90, firstDay: 80, canStepUp: true), isNot(Nudge.welcomeBack));
    });

    test('B4: offer to adjust when the measured week differs a lot', () {
      expect(shouldOfferRecalibration(150, 80), isTrue);
      expect(shouldOfferRecalibration(60, 55), isFalse);
    });
  });

  group('C3 habits filtered by B6', () {
    final winter = DateTime(2026, 11, 13);
    final summer = DateTime(2026, 7, 1);

    test('night shift gets the NIOSH sleep habits first', () {
      final sug = suggestHabits(profile: ravi(), domains: {Domain.sleep}, today: winter);
      expect(sug.first.id, 'homeToBed');
      expect(sug.map((h) => h.id), containsAll(['homeToBed']));
      expect(sug.where((h) => h.nightShift).length, greaterThanOrEqualTo(2));
      expect(sug.length, 3);
    });

    // Chi's screen 11: C3 #15, #16, #14 (NIOSH) before the general AASM habits.
    test('fixed night shift with sleep: the three NIOSH night-shift habits, in Chi\'s order', () {
      expect(suggestHabits(profile: ravi(), domains: {Domain.sleep}, today: winter).map((h) => h.id),
          ['homeToBed', 'blackout', 'napBeforeShift']);
      // Without the shift-sleep card too (the night shift alone allows them).
      expect(suggestHabits(profile: ravi(goals: ['fallAsleep']), domains: {Domain.sleep}, today: winter).map((h) => h.id),
          ['homeToBed', 'blackout', 'napBeforeShift']);
      // Hot season, outdoor work: still sleep habits, still allowed by the filter.
      expect(
          suggestHabits(profile: ravi(place: WorkPlace.outdoor), domains: {Domain.sleep}, today: summer)
              .map((h) => h.id),
          ['homeToBed', 'blackout', 'napBeforeShift']);
      // Sleep and movement: one movement habit keeps its place.
      expect(suggestHabits(profile: ravi(), domains: {Domain.sleep, Domain.movement}, today: winter).map((h) => h.id),
          ['homeToBed', 'briskWalk', 'blackout']);
      // Day shift: the AASM habit first, no NIOSH habit forced in.
      final day = suggestHabits(profile: ravi(shift: ShiftType.dayFixed, goals: ['fallAsleep']), domains: {Domain.sleep}, today: winter);
      expect(day.first.id, 'bedEarlier');
      expect(day.any((h) => h.nightShift), isFalse);
      // Every suggestion is still one the B6 filter allows.
      final allowed = filterHabits(profile: ravi(), domains: {Domain.sleep}, today: winter).habits;
      expect(kNightShiftSleepHabits.every((id) => allowed.any((h) => h.id == id)), isTrue);
    });

    test('day shift does not get night-shift habits', () {
      final r = filterHabits(
          profile: ravi(shift: ShiftType.dayFixed, goals: ['fallAsleep']), domains: {Domain.sleep}, today: winter);
      expect(r.habits.where((h) => h.nightShift), isEmpty);
      expect(r.removed['napBeforeShift'], HabitFilterReason.notNightShift);
    });

    test('outdoor work 15 Jun - 15 Sep: no extra movement', () {
      final r = filterHabits(
          profile: ravi(place: WorkPlace.outdoor, goals: ['energy']), domains: {Domain.movement}, today: summer);
      expect(r.habits.where((h) => h.extraMovement), isEmpty);
      expect(r.removed['briskWalk'], HabitFilterReason.outdoorHeat);
      // Indoor workers in summer still get movement, indoors first.
      final indoor = suggestHabits(profile: ravi(goals: ['energy']), domains: {Domain.movement}, today: summer);
      expect(indoor.first.id, 'indoorWalk');
      // Outdoor workers outside the season are not filtered.
      final r2 = filterHabits(
          profile: ravi(place: WorkPlace.outdoor, goals: ['energy']), domains: {Domain.movement}, today: winter);
      expect(r2.habits.any((h) => h.id == 'briskWalk'), isTrue);
    });

    test('season edges', () {
      expect(isHotSeason(DateTime(2026, 6, 14)), isFalse);
      expect(isHotSeason(DateTime(2026, 6, 15)), isTrue);
      expect(isHotSeason(DateTime(2026, 9, 15)), isTrue);
      expect(isHotSeason(DateTime(2026, 9, 16)), isFalse);
    });

    test('heavy work: no stairs or strength', () {
      final r = filterHabits(
          profile: ravi(activity: WorkActivity.heavy, goals: ['stronger']), domains: {Domain.movement}, today: winter);
      expect(r.habits.map((h) => h.id), isNot(contains('stairs')));
      expect(r.habits.map((h) => h.id), isNot(contains('strength')));
    });

    test('every habit has a source; only listed habits', () {
      expect(kHabits.length, 25);
      expect(kHabits.every((h) => h.source.isNotEmpty), isTrue);
      expect(filterHabits(profile: ravi(), domains: {Domain.sleep, Domain.movement}, today: winter)
          .habits.any((h) => h.ramadan), isFalse);
    });
  });

  group('C4 reminders (port of reminders.cpp)', () {
    test('same cases as the band', () {
      final c = Settings(reminder1: 8 * 60, reminder2: 18 * 60, quietStart: 22 * 60, quietEnd: 6 * 60);
      expect(dueReminder(8 * 60 + 5, c, 0), 0);
      expect(dueReminder(8 * 60 + 5, c, 1), -1); // already sent
      expect(dueReminder(9 * 60, c, 0), -1); // missed: no catch-up
      expect(dueReminder(18 * 60, c, 1), 1);
      expect(inQuiet(23 * 60, c.quietStart, c.quietEnd), isTrue);
      expect(inQuiet(2 * 60, c.quietStart, c.quietEnd), isTrue);
      c.reminder1 = 23 * 60; // inside quiet hours
      expect(dueReminder(23 * 60, c, 0), -1);
      expect(activeReminderTimes(c), [18 * 60]);
      // Night-shift quiet hours in the day (Ravi): 08:00-15:00.
      expect(inQuiet(10 * 60, 8 * 60, 15 * 60), isTrue);
      expect(inQuiet(23 * 60, 8 * 60, 15 * 60), isFalse);
    });

    test('onboarding screen 5: usual sleep starts from the shift (only a default)', () {
      expect(suggestedSleepTimes(ShiftType.nightFixed), (8 * 60 + 30, 14 * 60)); // Chi's screen 5
      expect(suggestedSleepTimes(ShiftType.rotating), (23 * 60 + 30, 5 * 60 + 30));
      for (final sh in [ShiftType.dayFixed, ShiftType.longOrSplit, ShiftType.irregular]) {
        expect(suggestedSleepTimes(sh), (23 * 60, 6 * 60));
      }
    });

    test('fixed nights: the reminder follows the habit\'s moment, never in quiet hours', () {
      for (final id in ['homeToBed', 'blackout']) {
        final st = suggestedReminderSettings(ShiftType.nightFixed, Settings(), habitId: id);
        expect(habitMoment(id), HabitMoment.afterShift);
        expect((st.reminder1, st.reminder2), (7 * 60 + 30, -1), reason: id); // end of shift (Chi's screen 11)
        expect((st.quietStart, st.quietEnd), (8 * 60, 15 * 60));
        expect(activeReminderTimes(st), [7 * 60 + 30]);
      }
      final nap = suggestedReminderSettings(ShiftType.nightFixed, Settings(), habitId: 'napBeforeShift');
      expect(activeReminderTimes(nap), [16 * 60]); // after day sleep, before the shift
      // Other habits keep the night defaults; other shifts are unchanged by the habit.
      final other = suggestedReminderSettings(ShiftType.nightFixed, Settings(), habitId: 'screensOff');
      expect(activeReminderTimes(other), [16 * 60, 6 * 60 + 30]);
      final day = suggestedReminderSettings(ShiftType.dayFixed, Settings(), habitId: 'napBeforeShift');
      expect(activeReminderTimes(day), [7 * 60 + 30, 18 * 60 + 30]);
      for (final id in [null, 'homeToBed', 'blackout', 'napBeforeShift', 'briskWalk']) {
        final st = suggestedReminderSettings(ShiftType.nightFixed, Settings(), habitId: id);
        expect(activeReminderTimes(st).length, inInclusiveRange(1, 2));
        for (final t in [st.reminder1, st.reminder2].where((t) => t >= 0)) {
          expect(inQuiet(t, st.quietStart, st.quietEnd), isFalse, reason: '$id $t');
        }
      }
    });

    test('night shift defaults never ring in day sleep', () {
      final st = suggestedReminderSettings(ShiftType.nightFixed, Settings());
      expect(activeReminderTimes(st).length, 2);
      for (final t in activeReminderTimes(st)) {
        expect(inQuiet(t, st.quietStart, st.quietEnd), isFalse);
      }
    });
  });

  group('B2/B3 safety', () {
    test('danger words stop suggestions', () {
      expect(hasDangerSign('I get chest pain when I walk'), isTrue);
      expect(hasDangerSign('to call my kids'), isFalse);
    });

    test('identifiers are stripped from the motivation sentence', () {
      expect(stripIdentifiers('for my kids, call me +971 50 123 4567'), isNot(contains('4567')));
      expect(stripIdentifiers('mail ravi@example.com'), isNot(contains('@')));
      expect(stripIdentifiers('to have energy for my kids'), 'to have energy for my kids');
    });
  });
}
