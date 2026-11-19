// Demo scenarios for the video and the web demo (Settings > Debug, demo band only).
// Each one resets the app's data to a ready-made state through the normal paths:
// delete my data -> onboarding result (profile, plan from initialPlan(), reminder
// settings) -> pair the demo band -> sync. The band history and its check-ins come
// from FakeBand over the same protocol lines as a real band. Synthetic data only,
// persona Ravi from the rules PDF (C7); never a real person's data.
import '../analytics/daily.dart';
import '../data/models.dart';
import '../rules/habits.dart';
import '../rules/plan.dart';
import '../rules/reminders.dart';

/// Titles and one-line descriptions: S.scenarioTitle / S.scenarioDescription.
enum DemoScenario { fresh, week3, welcomeBack, hardLately, nightsSoon }

/// What a scenario puts in the app. null profile = Fresh start (onboarding).
class ScenarioSetup {
  final Profile? profile;
  final Plan? plan;
  final Settings? settings;

  /// Demo band: where its data starts (UTC minute) and its check-ins per local day
  /// (0 done, 1 partly, 2 not today, -1 none).
  final int? bandFirstMinute;
  final Map<int, int> checkinScript;

  const ScenarioSetup({
    this.profile,
    this.plan,
    this.settings,
    this.bandFirstMinute,
    this.checkinScript = const {},
  });
}

/// Ravi's motivation sentence, Chi's exact text (screens 8, 14 and 20), kept word
/// for word like a user's own (B5).
const kRaviMotivation = 'So I still have energy to video-call my kids';

/// Builds [sc] for the moment [now] (local time). [base] keeps the device's
/// settings that are not part of the scenario (the demo band switch).
ScenarioSetup buildScenario(DemoScenario sc, DateTime now, {Settings? base}) {
  if (sc == DemoScenario.fresh) return const ScenarioSetup();
  final nowMinute = now.toUtc().millisecondsSinceEpoch ~/ 60000;
  final tz = now.timeZoneOffset.inMinutes;
  final today = localDay(nowMinute, tz);

  // (days since onboarding, band history days, check-ins from the oldest band day
  // to yesterday: D done, P partly, N not today, - none). Today is always left
  // open so the check-in can be shown live.
  final (startDays, historyDays, pattern) = switch (sc) {
    // 6 band days before the plan (baseline), then 15 days; 5 of the last 7 done.
    DemoScenario.week3 => (15, 21, '------' 'PD-DDPDN' 'DDDPDDD'),
    // Checked in from day 1, then nothing for the last 2 days (and not yet today).
    DemoScenario.welcomeBack => (10, 14, '----' 'DDPDDDPD' '--'),
    // "Partly" 3 times in the last 5 days (2 days ago done, so no lapse).
    DemoScenario.hardLately => (12, 14, '--' 'DDPDDND' 'DPPDP'),
    // Started 6 days ago, mostly done; nights start the day after tomorrow.
    DemoScenario.nightsSoon => (6, 14, '--------' 'DDPDDD'),
    DemoScenario.fresh => throw StateError('unreachable'),
  };
  assert(pattern.length == historyDays);

  final rotating = sc == DemoScenario.nightsSoon;
  final start = nowMinute - startDays * 1440;
  final profile = Profile(
    goalIds: const ['tiredOnWaking', 'shiftSleep'],
    mainGoalId: 'tiredOnWaking',
    motivation: kRaviMotivation,
    activity: WorkActivity.standingLight,
    shift: rotating ? ShiftType.rotating : ShiftType.nightFixed,
    place: WorkPlace.indoor,
    selfSleepMinutes: 330,
    selfWalkMinutes: 60,
    startMinute: start,
    heightCm: 172,
    weightKg: 74,
    city: City.abuDhabi,
    selfBedtimeSpreadMinutes: 60,
    // Chi's screen 5 for fixed nights (and "Your day", thread 0008): day sleep 08:30-14:00, nights off 01:00-08:00
    selfSleepStart: 8 * 60 + 30,
    selfWakeTime: 14 * 60,
    selfOffSleepStart: 60,
    selfOffWakeTime: 8 * 60,
    nextNightsDate: rotating ? dateKey(DateTime(now.year, now.month, now.day + 2)) : null,
  );
  // C1 step 4, as onboarding does it: the suggested habits for sleep, the first
  // as the main habit and the others kept as backups (swap, first nights).
  final startDate = DateTime.fromMillisecondsSinceEpoch(start * 60000);
  final habits = suggestHabits(profile: profile, domains: {Domain.sleep}, today: startDate);
  final plan = initialPlan(
    profile: profile,
    domains: {Domain.sleep},
    mainHabitId: habits.first.id,
    backupHabitIds: [for (final h in habits.skip(1)) h.id],
    nowMinute: start,
  );
  // Reminder at the habit's moment (fixed nights, straight to bed: 07:30), as onboarding.
  final settings = suggestedReminderSettings(profile.shift, base ?? Settings(), habitId: plan.mainHabitId);

  final firstBandDay = today - historyDays;
  final script = <int, int>{
    for (var i = 0; i < pattern.length; i++)
      firstBandDay + i: switch (pattern[i]) { 'D' => 0, 'P' => 1, 'N' => 2, _ => -1 },
    today: -1,
  };
  return ScenarioSetup(
    profile: profile,
    plan: plan,
    settings: settings,
    bandFirstMinute: nowMinute - historyDays * 1440,
    checkinScript: script,
  );
}
