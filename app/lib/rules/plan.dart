// Rules C2 (step-up plan) and C5 (difficulty, lapse, step up only when the
// user agrees). Pure Dart. BB only suggests; the user accepts or not.
import '../data/models.dart';
import 'environment.dart';
import 'levels.dart';

/// C2 example "movement from 0": (minutes per session, sessions per week).
/// Weeks 1-2 5'x3, 3-4 10'x3, 5-6 10'x5, 7-8 15'x5, 9-10 20'x5, 11-12 25'x5, 13-14 30'x5.
const kMoveLadder = <(int, int)>[(5, 3), (10, 3), (10, 5), (15, 5), (20, 5), (25, 5), (30, 5)];

const kMoveStepSource =
    'HHS 2018 ch. 7 p. 90: add 5-15 min per session, 2-3 times a week, step up after '
    '1-2 weeks; p. 63: once at 150 min, work toward 300. WHO 2020; DHA 2026 sec. 9 '
    '"Start with small changes".';
const kSleepStepSource =
    'AASM: keep a fixed wake time and move bedtime earlier until you get 7-8 hours. '
    'The 15-30 min step size is set by BloomBack (no official number yet).';
const kStepUpSource =
    'BloomBack rules C2/C5: step up when the habit is done on 5 days in a row or 5 of 7 days, '
    'and only if you agree. Hold or step back when it is hard; never blame.';
const kLapseSource =
    'BloomBack rules C5: welcome back with your own words, restart small, nothing is reset. '
    'Behaviour change techniques: BCT Taxonomy v1 (Michie et al. 2013).';

class MoveTarget {
  final int weeklyMinutes;
  final int perSession;
  final int sessions;
  final bool holding; // at the guideline or above: keep the rhythm
  const MoveTarget(this.weeklyMinutes, this.perSession, this.sessions, {this.holding = false});
}

/// The suggested starting plan from the self-reported numbers (B4 + C2).
Plan initialPlan({
  required Profile profile,
  required Set<Domain> domains,
  required String mainHabitId,
  List<String> backupHabitIds = const [],
  required int nowMinute,
  int movementGoal = kMoveGuideline,
}) {
  // B2 ④ / B6 axis 1: part of the movement at work counts toward the current level.
  final base = currentWeeklyMovement(profile).clamp(0, 2000);
  return Plan(
    domains: domains,
    movementStep: 0,
    movementBaseWeekly: moveLevel(base) == MoveLevel.inactive ? 0 : base,
    movementIncrement: 10,
    movementGoal: movementGoal == kMoveUpper ? kMoveUpper : kMoveGuideline,
    workCredit: workCredit(profile),
    sleepTargetMinutes: firstSleepTarget(profile.selfSleepMinutes, 30),
    sleepIncrement: 30,
    mainHabitId: mainHabitId,
    backupHabitIds: backupHabitIds,
    stepStartMinute: nowMinute,
  );
}

/// Start from where the user is: one small step above the current sleep, up to 7 h.
int firstSleepTarget(int currentSleep, int increment) {
  if (currentSleep >= kSleepGuideline) return currentSleep; // keep the rhythm
  final t = currentSleep + increment;
  return t > kSleepGuideline ? kSleepGuideline : t;
}

/// This step's movement target (all of it, including minutes counted from work).
/// From 0: the C2 ladder. With a base: +10 (or +15) min/week up to the goal, then hold.
/// The goal is 150 unless the user chose 300 on the weight card (B5, C2; HHS 2018 p. 63).
MoveTarget movementTarget(Plan p) {
  final goal = p.movementGoal > kMoveGuideline ? p.movementGoal : kMoveGuideline;
  if (p.movementBaseWeekly <= 0) {
    final last = kMoveLadder.length - 1;
    if (p.movementStep <= last || goal <= kMoveGuideline) {
      final s = kMoveLadder[p.movementStep.clamp(0, last)];
      return MoveTarget(s.$1 * s.$2, s.$1, s.$2,
          holding: p.movementStep >= last && goal <= kMoveGuideline);
    }
    // Past the ladder's 150 with a higher goal: +increment per step up to the goal.
    final t = kMoveGuideline + p.movementIncrement * (p.movementStep - last);
    return _split(t >= goal ? goal : t, holding: t >= goal);
  }
  if (p.movementBaseWeekly >= goal) {
    return _split(p.movementBaseWeekly, holding: true);
  }
  final t = p.movementBaseWeekly + p.movementIncrement * (p.movementStep + 1);
  return _split(t >= goal ? goal : t, holding: t >= goal);
}

/// The part of this week's target to do outside work: total minus the minutes
/// counted from work. Band and self-report numbers are compared with this (B1).
int leisureTarget(Plan p) {
  final t = movementTarget(p).weeklyMinutes - p.workCredit;
  return t < 0 ? 0 : t;
}

const kHigherGoalSource =
    'BloomBack rules B4/B5/C2 (updated 14/11): at 150-300 min a week BloomBack suggests keeping the rhythm; you may '
    'choose to move towards 300 min (HHS 2018 p. 63: people who reach 150 can work toward 300), for any goal card. '
    'Under 150 the default stays 150 (DHA 2026 sec. 9.2.1, WHO 2020). Never a goal lower than what you already do.';

const kStrengthSource =
    'DHA 2026 sec. 9.2.2 and HHS 2018 p. 63: muscle-strengthening activities on 2 or more days a week. '
    'BloomBack rules B4/C2 (14/11): offered to anyone already in the 150-300 min range, if they choose it.';

MoveTarget _split(int weekly, {bool holding = false}) {
  // Up to 5 days a week, sessions of at least 10 min (C2 table shape).
  final sessions = weekly >= 50 ? 5 : 3;
  final per = (weekly / sessions).ceil();
  return MoveTarget(weekly, per, sessions, holding: holding);
}

/// C3 example: "weekly target 70, you have 60 -> 10 short -> walk 5' x 2".
/// Returns (minutes per walk, walks) still to do this week, or null when met.
(int, int)? movementGapDose(int weeklyTarget, int doneThisWeek) {
  final gap = weeklyTarget - doneThisWeek;
  if (gap <= 0) return null;
  final per = gap <= 10 ? 5 : (gap <= 30 ? 10 : 15);
  return (per, (gap / per).ceil());
}

bool canStepUpMovement(Plan p) => !movementTarget(p).holding;
bool canStepUpSleep(Plan p) => p.sleepTargetMinutes < kSleepGuideline;

Plan stepUp(Plan p, int nowMinute) => Plan.fromJson(p.toJson())
  ..movementStep = (p.domains.contains(Domain.movement) && canStepUpMovement(p))
      ? p.movementStep + 1
      : p.movementStep
  ..sleepTargetMinutes = (p.domains.contains(Domain.sleep) && canStepUpSleep(p))
      ? (p.sleepTargetMinutes + p.sleepIncrement).clamp(0, kSleepGuideline)
      : p.sleepTargetMinutes
  ..stepStartMinute = nowMinute;

/// "Shrink": one step back, never below the start (C5).
Plan stepDown(Plan p, int nowMinute, int baseSleep) => Plan.fromJson(p.toJson())
  ..movementStep = p.movementStep > 0 ? p.movementStep - 1 : 0
  ..sleepTargetMinutes = (p.sleepTargetMinutes - p.sleepIncrement) < baseSleep
      ? (baseSleep < p.sleepTargetMinutes ? baseSleep : p.sleepTargetMinutes)
      : p.sleepTargetMinutes - p.sleepIncrement
  ..stepStartMinute = nowMinute;

/// What BB may gently suggest today (C5). Only one at a time.
enum Nudge { none, stepUp, difficulty, welcomeBack }

bool _did(CheckinStatus? s) => s == CheckinStatus.done || s == CheckinStatus.partial;

/// [byDay]: check-in per local day. [today]: local day. [stepStartDay]: day the
/// current step started. [firstDay]: user's first day.
Nudge nudgeFor({
  required Map<int, CheckinStatus> byDay,
  required int today,
  required int stepStartDay,
  required int firstDay,
  required bool canStepUp,
}) {
  // Lapse: two days in a row without doing it (not counting today), after the
  // user had started using check-ins.
  final everCheckedIn = byDay.entries.any((e) => e.key < today - 2 && _did(e.value));
  if (today - firstDay >= 3 &&
      everCheckedIn &&
      !_did(byDay[today - 1]) &&
      !_did(byDay[today - 2]) &&
      !_did(byDay[today])) {
    return Nudge.welcomeBack;
  }
  // Difficulty: >= 3 "partly" in the last 5 days.
  var partial = 0;
  for (var d = today - 4; d <= today; d++) {
    if (byDay[d] == CheckinStatus.partial) partial++;
  }
  if (partial >= 3) return Nudge.difficulty;
  // Steady: 5 days in a row done, or >= 5 of the last 7, after at least a week on this step.
  if (canStepUp && today - stepStartDay >= 7) {
    var done7 = 0, run = 0, bestRun = 0;
    for (var d = today - 6; d <= today; d++) {
      if (byDay[d] == CheckinStatus.done) {
        done7++;
        run++;
        if (run > bestRun) bestRun = run;
      } else {
        run = 0;
      }
    }
    if (done7 >= 5 || bestRun >= 5) return Nudge.stepUp;
  }
  return Nudge.none;
}

/// B4 end of week 1: if the measured week differs a lot from what was typed,
/// gently offer to adjust (never "you reported it wrong").
bool shouldOfferRecalibration(int selfWeekly, int measuredWeekly) {
  final diff = (selfWeekly - measuredWeekly).abs();
  return diff >= 30 && diff >= selfWeekly * 0.3;
}
