// Rules added 13 Nov: A1 inputs + D2 note, heat season (C4), fasting mode (C4,
// habit 21), shift types (B6 axis 2, C5 Lapse Radar), work movement (B6 axis 1),
// the weight card's 300 goal (B5), sleep regularity (C2), barrier "Move" (C5).
// Synthetic data only (persona Ravi and variations).
import 'package:bloomback/app_state.dart';
import 'package:bloomback/data/models.dart';
import 'package:bloomback/data/store.dart';
import 'package:bloomback/rules/biomarkers.dart';
import 'package:bloomback/rules/environment.dart';
import 'package:bloomback/rules/habits.dart';
import 'package:bloomback/rules/plan.dart';
import 'package:bloomback/rules/regularity.dart';
import 'package:bloomback/rules/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

Profile person({
  ShiftType shift = ShiftType.dayFixed,
  WorkPlace place = WorkPlace.indoor,
  WorkActivity activity = WorkActivity.standingLight,
  int walk = 60,
  int sleep = 330,
  List<String> goals = const ['energy'],
  int? height = 172,
  int? weight = 74,
  int workBrisk = 0,
  String? nextNights,
}) =>
    Profile(
      goalIds: goals,
      mainGoalId: goals.first,
      activity: activity,
      shift: shift,
      place: place,
      selfSleepMinutes: sleep,
      selfWalkMinutes: walk,
      startMinute: 0,
      heightCm: height,
      weightKg: weight,
      city: City.abuDhabi,
      workBriskMinutes: workBrisk,
      nextNightsDate: nextNights,
    );

Plan planFor(Profile p, String habit, {Set<Domain> domains = const {Domain.movement}, List<String> backups = const []}) =>
    initialPlan(profile: p, domains: domains, mainHabitId: habit, backupHabitIds: backups, nowMinute: 0);

DayRules rulesOn(Profile p, Plan pl, DateTime d, {Settings? st, FastingMode? f}) =>
    dayRules(profile: p, plan: pl, settings: st ?? Settings(), fasting: f, date: d);

void main() {
  final winter = DateTime(2026, 11, 13);
  final summer = DateTime(2026, 7, 1);

  group('A1 + D2: health numbers only show the ask-a-doctor note', () {
    Biomarkers b({int? sys, int? dia, double? glu, bool mg = false, double? a1c}) =>
        Biomarkers(systolic: sys, diastolic: dia, glucose: glu, glucoseMgDl: mg, hba1c: a1c, measuredMinute: 0);

    test('reference levels and their edges', () {
      // Ravi (C7): 135/85 is below 140/90 -> no note.
      expect(doctorNoteFlags(markers: b(sys: 135, dia: 85)), isEmpty);
      expect(doctorNoteFlags(markers: b(sys: 140, dia: 80)), {MarkerFlag.bloodPressure});
      expect(doctorNoteFlags(markers: b(sys: 120, dia: 90)), {MarkerFlag.bloodPressure});
      expect(doctorNoteFlags(markers: b(glu: 6.9)), isEmpty);
      expect(doctorNoteFlags(markers: b(glu: 7.0)), {MarkerFlag.glucose});
      expect(doctorNoteFlags(markers: b(glu: 125, mg: true)), isEmpty);
      expect(doctorNoteFlags(markers: b(glu: 126, mg: true)), {MarkerFlag.glucose});
      expect(doctorNoteFlags(markers: b(a1c: 6.4)), isEmpty);
      expect(doctorNoteFlags(markers: b(a1c: 6.5)), {MarkerFlag.hba1c});
      // BMI from the required height + weight: 29.9 vs 30.0.
      expect(doctorNoteFlags(heightCm: 170, weightKg: 86), isEmpty); // 29.8
      expect(doctorNoteFlags(heightCm: 170, weightKg: 87), {MarkerFlag.bmi}); // 30.1
      // "Don't know" everywhere = no note.
      expect(doctorNoteFlags(markers: b()), isEmpty);
      expect(doctorNoteFlags(), isEmpty);
    });

    test('numbers never change the level, the plan or today\'s habit', () async {
      final light = person(height: 175, weight: 60);
      final heavyBmi = person(height: 160, weight: 110); // BMI 43
      final a = planFor(light, 'briskWalk').toJson();
      final b2 = planFor(heavyBmi, 'briskWalk').toJson();
      expect(b2, a);
      expect(rulesOn(heavyBmi, Plan.fromJson(b2), winter).habitId, rulesOn(light, Plan.fromJson(a), winter).habitId);

      final now = DateTime(2026, 11, 13, 17);
      final app = AppState(MemoryStore(), clock: () => now);
      await app.load();
      final p = person();
      await app.finishOnboarding(p, planFor(p, 'briskWalk'), Settings());
      final before = app.plan!.toJson();
      expect(app.showDoctorNote, isFalse);
      await app.saveBiomarkers(Biomarkers(systolic: 150, diastolic: 95, hba1c: 7.1, measuredMinute: 0));
      expect(app.showDoctorNote, isTrue);
      expect(app.plan!.toJson(), before);
      expect(app.mainHabit!.id, 'briskWalk');
    });

    test('offered after the first week, not on day 1 (B1 "ask gradually")', () async {
      var now = DateTime(2026, 11, 13, 17);
      final app = AppState(MemoryStore(), clock: () => now);
      await app.load();
      final p = person()..startMinute = now.toUtc().millisecondsSinceEpoch ~/ 60000;
      await app.finishOnboarding(p, planFor(p, 'briskWalk'), Settings());
      expect(app.offerBiomarkers, isFalse);
      now = DateTime(2026, 11, 20, 17);
      expect(app.offerBiomarkers, isTrue);
      await app.hideBiomarkerOffer();
      expect(app.offerBiomarkers, isFalse);
    });

    test('profile JSON keeps the new fields; old profiles still load', () {
      final p = person(shift: ShiftType.rotating, nextNights: '2026-11-20', workBrisk: 90)
        ..selfBedtimeSpreadMinutes = 180;
      final back = Profile.fromJson(p.toJson());
      expect(back.heightCm, 172);
      expect(back.city, City.abuDhabi);
      expect(back.nextNightsDate, '2026-11-20');
      expect(back.workBriskMinutes, 90);
      expect(back.selfBedtimeSpreadMinutes, 180);
      final old = p.toJson()..removeWhere((k, _) => ['height', 'weight', 'city', 'workBrisk', 'spread', 'nextNights'].contains(k));
      final o = Profile.fromJson(old);
      expect(o.heightCm, isNull);
      expect(o.workBriskMinutes, 0);
      expect(Plan.fromJson((planFor(p, 'briskWalk').toJson()..remove('mGoal')..remove('workCredit'))).movementGoal, 150);
    });
  });

  group('C4 heat season', () {
    test('no outdoor walk reminder 12:30-15:00 from 15 Jun to 15 Sep, for anyone', () {
      final p = person();
      final pl = planFor(p, 'briskWalk');
      final st = Settings(reminder1: 7 * 60 + 30, reminder2: 13 * 60);
      final r = rulesOn(p, pl, summer, st: st);
      expect(r.reminderTimes, [7 * 60 + 30, kAfterSunset]);
      expect(r.movedForHeat, isTrue);
      expect(r.heatNote, isTrue);
      expect(r.reminderTimes.any(inMidday), isFalse);
      // Edges: 12:29 and 15:00 stay; outside the season nothing moves.
      expect(rulesOn(p, pl, summer, st: Settings(reminder1: 12 * 60 + 29, reminder2: 15 * 60)).reminderTimes,
          [12 * 60 + 29, 15 * 60]);
      expect(rulesOn(p, pl, DateTime(2026, 9, 16), st: st).reminderTimes, [7 * 60 + 30, 13 * 60]);
      expect(rulesOn(p, pl, winter, st: st).heatNote, isFalse);
      // An indoor habit is not moved.
      expect(rulesOn(p, planFor(p, 'indoorWalk'), summer, st: st).reminderTimes, [7 * 60 + 30, 13 * 60]);
    });

    test('moved to early morning when after sunset is quiet (night shift day sleep)', () {
      final p = person(shift: ShiftType.nightFixed);
      final st = Settings(reminder1: 13 * 60, reminder2: -1, quietStart: 19 * 60, quietEnd: 5 * 60);
      expect(rulesOn(p, planFor(p, 'briskWalk'), summer, st: st).reminderTimes, [kEarlyMorning]);
    });

    test('outdoor workers: no extra movement in the season, reminders included', () {
      final p = person(place: WorkPlace.outdoor);
      final pl = planFor(p, 'briskWalk', backups: ['walkAfterMeal']);
      final r = rulesOn(p, pl, summer);
      expect(r.change, HabitChange.outdoorHeat);
      expect(r.habit.area, HabitArea.sleep);
      final events = reminderSchedule(
          profile: p, plan: pl, settings: Settings(), now: DateTime(2026, 7, 1, 6), days: 7);
      expect(events, isNotEmpty);
      expect(events.every((e) => habitById(e.habitId).area != HabitArea.movement), isTrue);
      // 16 Sep: the user's own habit is back.
      expect(rulesOn(p, pl, DateTime(2026, 9, 16)).habitId, 'briskWalk');
      // "Both" places count as outdoor too (B6 axis 3).
      expect(rulesOn(person(place: WorkPlace.both), pl, summer).change, HabitChange.outdoorHeat);
    });

    test('Lapse Radar: a heads-up a week before 15 Jun', () {
      final p = person();
      expect(lapseRadar(profile: p, today: DateTime(2027, 6, 10)).map((r) => r.kind), contains(RadarKind.heatSoon));
      expect(lapseRadar(profile: p, today: DateTime(2027, 6, 1)).map((r) => r.kind), isNot(contains(RadarKind.heatSoon)));
    });
  });

  group('C4 fasting mode (Ramadan, habit 21)', () {
    const f = FastingMode('2027-02-08', '2027-03-09');

    test('suggested Ramadan 1448 dates (approximate) for the region', () {
      final r = suggestedRamadan(winter, City.dubai)!;
      expect(r.hijriYear, 1448);
      expect(dateKey(r.from), '2027-02-08');
      expect(dateKey(r.to), '2027-03-08'); // Umm al-Qura, Chi's screen 17
      expect(suggestedRamadan(DateTime(2027, 3, 10), City.other), isNull);
    });

    test('only "fasting mode on, from - to" is stored', () {
      expect(f.toJson().keys.toSet(), {'on', 'from', 'to'});
      expect(FastingMode.fromJson(f.toJson())!.covers(DateTime(2027, 2, 8)), isTrue);
      expect(f.covers(DateTime(2027, 3, 9, 23, 59)), isTrue);
      expect(f.covers(DateTime(2027, 2, 7)), isFalse);
      expect(f.covers(DateTime(2027, 3, 10)), isFalse);
    });

    test('walk after iftar, no vigorous activity, reminders moved; off afterwards', () {
      final p = person(goals: ['stronger']);
      final st = Settings(reminder1: 7 * 60 + 30, reminder2: 13 * 60);
      for (final h in ['briskWalk', 'stairs', 'strength']) {
        final r = rulesOn(p, planFor(p, h), DateTime(2027, 2, 15), st: st, f: f);
        expect(r.habitId, 'walkAfterIftar', reason: h);
        expect(r.change, HabitChange.fasting);
        expect(r.reminderTimes, [7 * 60 + 30, kAfterIftar]);
      }
      // Sleep habit: the second reminder goes to the evening, before suhoor.
      final sleep = rulesOn(p, planFor(p, 'bedEarlier', domains: {Domain.sleep}), DateTime(2027, 2, 15), st: st, f: f);
      expect(sleep.habitId, 'bedEarlier');
      expect(sleep.reminderTimes.last, kSleepBeforeSuhoor);
      expect(sleep.fasting, isTrue);
      // The day after the last date: back to the user's own habit and times.
      final after = rulesOn(p, planFor(p, 'briskWalk'), DateTime(2027, 3, 10), st: st, f: f);
      expect(after.habitId, 'briskWalk');
      expect(after.reminderTimes, [7 * 60 + 30, 13 * 60]);
      // Without fasting mode the iftar habit is never suggested.
      expect(rulesOn(p, planFor(p, 'briskWalk'), DateTime(2027, 2, 15), st: st).habitId, 'briskWalk');
    });

    test('Lapse Radar offers the dates 2 weeks before, until the user decides', () {
      final p = person();
      expect(lapseRadar(profile: p, today: winter).where((r) => r.kind == RadarKind.ramadanSoon), isEmpty);
      final soon = lapseRadar(profile: p, today: DateTime(2027, 1, 30)).where((r) => r.kind == RadarKind.ramadanSoon);
      expect(soon.single.days, 9);
      expect(lapseRadar(profile: p, fasting: f, today: DateTime(2027, 1, 30)).where((r) => r.kind == RadarKind.ramadanSoon),
          isEmpty);
    });

    test('AppState saves and clears fasting mode', () async {
      final now = DateTime(2027, 2, 10, 9);
      final store = MemoryStore();
      final app = AppState(store, clock: () => now);
      await app.load();
      final p = person();
      await app.finishOnboarding(p, planFor(p, 'briskWalk'), Settings());
      await app.saveFasting(f);
      expect(app.mainHabit!.id, 'walkAfterIftar');
      expect(store.kv['fasting'], isNot(contains('relig')));
      await app.saveFasting(null);
      expect(app.mainHabit!.id, 'briskWalk');
      expect(store.kv.containsKey('fasting'), isFalse);
    });
  });

  group('B6 axis 2: shift types', () {
    test('rotating: heads-up 1-2 days before nights; first 2 nights sleep habits only', () {
      final p = person(shift: ShiftType.rotating, nextNights: '2026-11-20');
      final pl = planFor(p, 'briskWalk', domains: {Domain.movement, Domain.sleep}, backups: ['stretch', 'bedEarlier']);
      List<RadarKind> radar(DateTime d) => lapseRadar(profile: p, today: d).map((r) => r.kind).toList();
      expect(radar(DateTime(2026, 11, 17)), isNot(contains(RadarKind.nightsSoon)));
      expect(radar(DateTime(2026, 11, 18)), contains(RadarKind.nightsSoon));
      expect(radar(DateTime(2026, 11, 19)), contains(RadarKind.nightsSoon));
      expect(radar(DateTime(2026, 11, 20)), isNot(contains(RadarKind.nightsSoon)));

      for (final d in [DateTime(2026, 11, 20), DateTime(2026, 11, 21)]) {
        final r = rulesOn(p, pl, d);
        expect(r.firstNights, isTrue);
        expect(r.change, HabitChange.firstNights);
        expect(r.habitId, 'bedEarlier'); // the user's own sleep backup first
        // Night-shift reminder times and day quiet hours on those days.
        expect(r.reminderTimes, [16 * 60, 6 * 60 + 30]);
        expect(r.quietStart, 8 * 60);
      }
      expect(rulesOn(p, pl, DateTime(2026, 11, 22)).habitId, 'briskWalk');
      // Without a sleep backup: the NIOSH nap before the shift.
      expect(rulesOn(p, planFor(p, 'briskWalk'), DateTime(2026, 11, 20)).habitId, 'napBeforeShift');
      // A sleep habit stays as it is.
      expect(rulesOn(p, planFor(p, 'homeToBed', domains: {Domain.sleep}), DateTime(2026, 11, 20)).change,
          HabitChange.none);
      // Once the nights have started, ask for the next switch date.
      expect(radar(DateTime(2026, 11, 22)), contains(RadarKind.nextNightsUnknown));
      expect(lapseRadar(profile: person(shift: ShiftType.rotating), today: winter).map((r) => r.kind),
          contains(RadarKind.nextNightsUnknown));
    });

    test('long or split shift: smaller parts in the break', () {
      expect(breakSplit(10), (2, 5));
      expect(breakSplit(15), (2, 8));
      expect(breakSplit(5), (1, 5));
      final p = person(shift: ShiftType.longOrSplit);
      final st = suggestedReminderSettings(ShiftType.longOrSplit, Settings())..breakMinute = 13 * 60;
      expect(rulesOn(p, planFor(p, 'briskWalk'), winter, st: st).reminderTimes, [7 * 60 + 30, 13 * 60]);
      // In the hot season a break at 13:00 is midday: the outdoor walk reminder moves.
      expect(rulesOn(p, planFor(p, 'briskWalk'), summer, st: st).reminderTimes, [7 * 60 + 30, kAfterSunset]);
      // Break-friendly habits come first in the list.
      final sug = suggestHabits(profile: p, domains: {Domain.movement}, today: winter).map((h) => h.id);
      expect(sug, contains('standUp'));
      expect(suggestHabits(profile: person(), domains: {Domain.movement}, today: winter).map((h) => h.id),
          isNot(contains('standUp')));
    });

    test('irregular hours: reminders keyed to check-ins, not fixed times', () {
      final p = person(shift: ShiftType.irregular);
      final pl = planFor(p, 'briskWalk');
      final st = suggestedReminderSettings(ShiftType.irregular, Settings());
      expect(rulesOn(p, pl, winter, st: st).reminderTimes, isEmpty);
      final now = DateTime(2026, 11, 13, 10, 0);
      final ev = reminderSchedule(
        profile: p,
        plan: pl,
        settings: st,
        now: now,
        lastActive: now,
        lastCheckin: DateTime(2026, 11, 12, 21, 0),
      );
      expect(ev.map((e) => e.at), [DateTime(2026, 11, 13, 13, 0), DateTime(2026, 11, 13, 21, 0)]);
      // Already checked in today: no "3 h later" reminder; the next-day one comes.
      final ev2 = reminderSchedule(
        profile: p,
        plan: pl,
        settings: st,
        now: now,
        lastActive: now,
        lastCheckin: DateTime(2026, 11, 13, 9, 30),
        checkedInToday: true,
      );
      expect(ev2.map((e) => e.at), [DateTime(2026, 11, 14, 9, 30)]);
      // Never in quiet hours (22:00-06:00).
      final late = DateTime(2026, 11, 13, 21, 0);
      expect(reminderSchedule(profile: p, plan: pl, settings: st, now: late, lastActive: late), isEmpty);
    });
  });

  group('B6 axis 1: movement at work', () {
    test('moderate work: 100 % of the confirmed moderate minutes at work count (Chi Q7); shown apart', () {
      expect(kWorkCreditPercent, 100);
      expect(workCredit(person(activity: WorkActivity.moderate, walk: 40, workBrisk: 120)), 120);
      expect(kWorkCreditSource, contains('Bull et al., BJSM 2020'));
      final p = person(activity: WorkActivity.moderate, walk: 40, workBrisk: 60);
      expect(workCredit(p), 60);
      expect(currentWeeklyMovement(p), 100);
      final pl = planFor(p, 'briskWalk');
      expect(pl.workCredit, 60);
      expect(pl.movementBaseWeekly, 100);
      expect(movementTarget(pl).weeklyMinutes, 110);
      expect(leisureTarget(pl), 50);
      // Other work types: nothing counted.
      expect(workCredit(person(activity: WorkActivity.standingLight, workBrisk: 120)), 0);
      // Enough at work: hold the rhythm, nothing extra outside work.
      final busy = planFor(person(activity: WorkActivity.moderate, walk: 0, workBrisk: 400), 'briskWalk');
      expect(movementTarget(busy).holding, isTrue);
      expect(leisureTarget(busy), 0);
    });

    test('heavy work: sleep first, stretching first, no extra heavy exercise', () {
      final p = person(activity: WorkActivity.heavy, goals: ['energy']);
      expect(suggestedStartDomain(p), Domain.sleep);
      expect(suggestedStartDomain(person(goals: ['energy'])), Domain.movement);
      final sug = suggestHabits(profile: p, domains: {Domain.movement}, today: winter).map((h) => h.id).toList();
      expect(sug.first, 'stretch');
      expect(sug, isNot(contains('stairs')));
      expect(sug, isNot(contains('strength')));
      // A heavy habit chosen earlier is swapped for today, never forced.
      final r = rulesOn(p, planFor(p, 'stairs', backups: ['stretch']), winter);
      expect(r.habitId, 'stretch');
      expect(r.change, HabitChange.heavyWork);
    });
  });

  group('B5 weight card: 300 only when chosen', () {
    test('default 150 holds; 300 keeps stepping', () {
      final p = person(walk: 200, goals: ['weight']);
      final def = planFor(p, 'briskWalk');
      expect(def.movementGoal, 150);
      expect(movementTarget(def).holding, isTrue);
      final hi = initialPlan(profile: p, domains: {Domain.movement}, mainHabitId: 'briskWalk', nowMinute: 0, movementGoal: 300);
      expect(movementTarget(hi).weeklyMinutes, 210);
      expect(canStepUpMovement(hi), isTrue);
      final top = Plan.fromJson(hi.toJson())..movementStep = 20;
      expect(movementTarget(top).weeklyMinutes, 300);
      expect(movementTarget(top).holding, isTrue);
      // From 0: the ladder to 150, then +10 a week toward 300.
      final zero = initialPlan(
          profile: person(walk: 0, goals: ['weight']), domains: {Domain.movement}, mainHabitId: 'briskWalk', nowMinute: 0, movementGoal: 300);
      final atLadderEnd = Plan.fromJson(zero.toJson())..movementStep = kMoveLadder.length - 1;
      expect(movementTarget(atLadderEnd).weeklyMinutes, 150);
      expect(movementTarget(atLadderEnd).holding, isFalse);
      expect(movementTarget(stepUp(atLadderEnd, 0)).weeklyMinutes, 160);
      // Any other number is not accepted as a goal.
      expect(initialPlan(profile: p, domains: {Domain.movement}, mainHabitId: 'briskWalk', nowMinute: 0, movementGoal: 220)
          .movementGoal, 150);
    });
  });

  group('C2 sleep regularity step', () {
    test('-30 min every 2 weeks until under 1 h; the user accepts or not', () {
      expect(nextSpreadTarget(180), 150);
      expect(nextSpreadTarget(90), kSpreadUnder1h);
      expect(nextSpreadTarget(70), kSpreadUnder1h);
      final first = spreadOffer(currentSpread: 180, target: null, targetSetDay: null, today: 100)!;
      expect(first.target, 150);
      expect(first.first, isTrue);
      expect(spreadOffer(currentSpread: 45, target: null, targetSetDay: null, today: 100), isNull);
      // Accepted on day 100: nothing new for 2 weeks, then the next step.
      expect(spreadOffer(currentSpread: 170, target: 150, targetSetDay: 100, today: 113), isNull);
      expect(spreadOffer(currentSpread: 140, target: 150, targetSetDay: 100, today: 114)!.target, 120);
      // "Not now" hides it for 2 weeks.
      expect(spreadOffer(currentSpread: 180, target: null, targetSetDay: null, today: 110, declinedDay: 100), isNull);
      expect(spreadOffer(currentSpread: 180, target: null, targetSetDay: null, today: 114, declinedDay: 100), isNotNull);
      // Last step set, or already under 1 h: nothing more.
      expect(spreadOffer(currentSpread: 80, target: kSpreadUnder1h, targetSetDay: 0, today: 200), isNull);
      expect(spreadOffer(currentSpread: 50, target: 90, targetSetDay: 0, today: 200), isNull);
      expect(kSpreadSource, contains('set by BloomBack'));
    });

    test('self-reported spread when there is no band; accept saves the target', () async {
      final now = DateTime(2026, 11, 13, 17);
      final app = AppState(MemoryStore(), clock: () => now);
      await app.load();
      final p = person()..selfBedtimeSpreadMinutes = 180;
      await app.finishOnboarding(p, planFor(p, 'bedEarlier', domains: {Domain.sleep}), Settings());
      expect(app.currentSpread, (180, DataSource.selfReport));
      final o = app.spreadOfferToday!;
      expect(o.target, 150);
      await app.acceptSpread(o.target);
      expect(app.plan!.spreadTargetMinutes, 150);
      expect(app.spreadOfferToday, isNull);
    });
  });

  group('C5 barrier "Move"', () {
    test('moves today\'s reminder only, or keeps the new time', () async {
      var now = DateTime(2026, 11, 13, 9);
      final app = AppState(MemoryStore(), clock: () => now);
      await app.load();
      final p = person();
      await app.finishOnboarding(p, planFor(p, 'briskWalk'), Settings(reminder1: 7 * 60 + 30, reminder2: 18 * 60 + 30));
      await app.moveReminder(1, 20 * 60);
      expect(app.todayRules!.reminderTimes, [7 * 60 + 30, 20 * 60]);
      expect(app.upcomingReminders().first.at, DateTime(2026, 11, 13, 20, 0));
      now = DateTime(2026, 11, 14, 9);
      expect(app.todayRules!.reminderTimes, [7 * 60 + 30, 18 * 60 + 30]);
      await app.moveReminder(0, 8 * 60, keep: true);
      expect(app.settings.reminder1, 8 * 60);
      expect(app.todayRules!.reminderTimes, [8 * 60, 18 * 60 + 30]);
      // At most 2 a day, every day, none in quiet hours.
      final ev = app.upcomingReminders();
      for (var d = 0; d < 7; d++) {
        final day = ev.where((e) => daysBetween(DateTime(2026, 11, 14), e.at) == d);
        expect(day.length, lessThanOrEqualTo(2));
      }
      expect(ev.every((e) => !inQuiet(e.at.hour * 60 + e.at.minute, 22 * 60, 6 * 60)), isTrue);
    });
  });

  test('bedtime spread from work-day and day-off bedtimes (Chi screen 5, 14/11)', () {
    expect(spreadFromBedtimes(8 * 60 + 30, 60, rotating: false), 450); // Ravi: 08:30 vs 01:00
    expect(spreadFromBedtimes(23 * 60, 60, rotating: false), 120); // across midnight, the short way
    expect(spreadFromBedtimes(22 * 60, 22 * 60, rotating: false), 0);
    expect(spreadFromBedtimes(8 * 60, 23 * 60, rotating: true), isNull); // C2: same shift type only
  });
}
