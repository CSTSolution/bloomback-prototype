// Rules B6 (3 work axes), C4 (heat, Ramadan, reminders) and C5 (Lapse Radar):
// what today's environment changes. Pure Dart, no network: the heat season and
// the Ramadan dates come from the calendar, not from a weather or prayer-time API.
// Everything here only changes which approved habit is shown and when reminders
// ring. It never changes a level, a target or a plan.
import '../data/models.dart';
import 'goals.dart';
import 'habits.dart';
import 'levels.dart';
import 'reminders.dart';
import 'shift_week.dart';

// ---------------------------------------------------------------------------
// B6 axis 1: movement at work
// ---------------------------------------------------------------------------

/// Share of the confirmed moderate minutes at work that count toward the 150 min.
/// Chi Q7 (13 Nov): 100 %, only minutes the user confirms as moderate (talk test).
const kWorkCreditPercent = 100;

const kWorkCreditSource =
    'WHO 2020 guidelines (Bull et al., BJSM 2020): "Physical activity accrued at work, leisure, '
    'home or during transportation count towards the recommended amounts." BloomBack rules B6 '
    'axis 1 (decided by Chi, Q7): for moderate work, all the minutes at work that you confirm '
    'as moderate count toward the 150 min. Moderate = the HHS 2018 talk test: you can talk, but '
    'not sing. Shown apart from band and self-reported numbers (B1).';

const kHeavyWorkSource =
    'BloomBack rules B6 axis 1 (WHO GPAQ work activity): heavy work - sleep, recovery and '
    'stretching first; no extra heavy exercise. DHA 2026 sec. 12.2 (stretching).';

/// Minutes per week counted from work: only for "moderate" work (B6 axis 1), all of
/// the minutes the user confirmed as moderate (Q7).
int workCredit(Profile p) => p.activity == WorkActivity.moderate
    ? (p.workBriskMinutes.clamp(0, 2000) * kWorkCreditPercent / 100).round()
    : 0;

/// Current weekly moderate minutes for B4: self-reported outside work + work credit.
int currentWeeklyMovement(Profile p) => p.selfWalkMinutes + workCredit(p);

/// C1 step 1: the suggested starting area. Heavy work suggests sleep first (B6 axis 1).
Domain suggestedStartDomain(Profile p) {
  if (p.activity == WorkActivity.heavy) return Domain.sleep;
  return switch (goalById(p.mainGoalId).start) {
    StartArea.sleep => Domain.sleep,
    StartArea.movement => Domain.movement,
    StartArea.both =>
      sleepGapIsBigger(p.selfSleepMinutes, currentWeeklyMovement(p)) ? Domain.sleep : Domain.movement,
  };
}

// ---------------------------------------------------------------------------
// C4 heat (B6 axis 3): 15 Jun - 15 Sep, no outdoor movement 12:30-15:00
// ---------------------------------------------------------------------------

const kMiddayFrom = 12 * 60 + 30;
const kMiddayTo = 15 * 60;
const kAfterSunset = 19 * 60 + 30; // UAE summer sunset is about 19:10
const kEarlyMorning = 6 * 60;

bool inMidday(int minuteOfDay) => minuteOfDay >= kMiddayFrom && minuteOfDay < kMiddayTo;

const kHeatSource =
    'BloomBack rules C4 (proposal): 15 Jun - 15 Sep, no outdoor movement suggestion 12:30-15:00 '
    'for anyone; early morning, after sunset or indoors instead (habit 20). MoHRE (UAE) midday '
    'break 15 Jun - 15 Sep, 12:30-15:00; HHS 2018 p. 92: when it is hot, be active early in the '
    'day, move indoors, go easier and drink enough water. A reminder that falls at midday moves '
    'to 19:30 (else 06:00): BloomBack sets these times.';

const kOutdoorHeatSource =
    'BloomBack rules B6 axis 3: outdoor work, 15 Jun - 15 Sep - no extra movement is suggested; '
    'rest, water and sleep come first. MoHRE (UAE) midday break; HHS 2018 p. 92.';

/// Days until the next 15 Jun (0 on the day itself).
int daysToHotSeason(DateTime today) {
  var start = DateTime(today.year, 6, 15);
  if (daysBetween(today, start) < 0) start = DateTime(today.year + 1, 6, 15);
  return daysBetween(today, start);
}

// ---------------------------------------------------------------------------
// C4 Ramadan / habit 21: fasting mode
// ---------------------------------------------------------------------------

class RamadanDates {
  final int hijriYear;
  final DateTime from; // first expected fasting day
  final DateTime to; // last expected fasting day
  const RamadanDates(this.hijriYear, this.from, this.to);
}

/// Expected dates from the Umm al-Qura calendar (Chi's screen 17: 1 Ramadan 1448 =
/// Mon 8 Feb 2027, last fasting day Mon 8 Mar, Eid about 9 Mar). APPROXIMATE: the
/// official dates follow the moon sighting and may differ by a day.
final kRamadanTable = <RamadanDates>[
  RamadanDates(1448, DateTime(2027, 2, 8), DateTime(2027, 3, 8)),
];

/// The next (or current) expected Ramadan for the user's region, or null if none is known.
/// Every listed city uses the UAE dates; "Other" gets the same dates, labelled as
/// possibly a day different where the user lives.
RamadanDates? suggestedRamadan(DateTime today, City? city) {
  // No city: no place-based dates (Chi, thread 0004 fix 10); the user can still pick dates or set a city in More.
  if (city == null) return null;
  for (final r in kRamadanTable) {
    if (daysBetween(today, r.to) >= 0) return r;
  }
  return null;
}

const kFastingSource =
    'BloomBack rules C4 (decided): BloomBack suggests the dates for your region; you confirm or '
    'pick other dates; fasting mode then turns on by itself: walk after iftar (habit 21, as brisk '
    'walking, DHA 2026 sec. 9.2.1), sleep around suhoor, no vigorous activity while fasting. The '
    'expected Ramadan 1448 dates (8 Feb - 8 Mar 2027, Umm al-Qura calendar) may differ by a '
    'day from the official dates; confirm them. '
    'Reminders move to 19:30 (after iftar) or 21:30 (sleep before suhoor): BloomBack sets these '
    'times. Only "fasting mode on, from - to" is stored, never a religion (rules A3).';

const kAfterIftar = 19 * 60 + 30;
const kSleepBeforeSuhoor = 21 * 60 + 30;

// ---------------------------------------------------------------------------
// B6 axis 2: shift types
// ---------------------------------------------------------------------------

const kNightsHeadsUpDays = 2; // Lapse Radar: a day or two before
const kNightsSleepOnlyDays = 2; // first 2 days on nights: sleep habits only

const kNightsSource =
    'BloomBack rules B6 axis 2 (proposal, waiting for Chi): rotating shifts - Lapse Radar gives a '
    'heads-up before the switch to nights (C5); for the first 2 days after switching to nights '
    'only sleep habits are suggested. The 2 days are set by BloomBack (no official number). '
    'Sleep habits from NIOSH Training for Nurses on Shift Work and Long Work Hours, module 9. '
    'Night work as in ILO Convention 171.';

const kLongShiftSource =
    'BloomBack rules B6 axis 2: long (12 h+) or split shifts - smaller tasks tied to the break. '
    'Splitting each walk into 2 shorter parts in your breaks is set by BloomBack; the weekly '
    'total stays the same. HHS 2018 p. 62: some activity is better than none.';

const kIrregularSource =
    'BloomBack rules B6 axis 2: irregular hours - reminders follow your check-ins, not fixed '
    'clock times. BloomBack sets the timing: one reminder a set time (3 h by default) after you '
    'last checked in or opened the app, if today is not checked in yet, and one the next day '
    'around the time of your last check-in. Never in quiet hours.';

/// Days from [today] to the next switch to nights (negative once it has passed), or null.
int? daysToNights(Profile p, DateTime today) {
  if (p.shift != ShiftType.rotating) return null;
  final d = parseDateKey(p.nextNightsDate);
  return d == null ? null : daysBetween(today, d);
}

/// The first 2 days after switching to nights (the switch day and the next).
bool inFirstNights(Profile p, DateTime today) {
  final d = daysToNights(p, today);
  return d != null && d <= 0 && d > -kNightsSleepOnlyDays;
}

/// Long or split shift: a session of [perSession] minutes as (parts, minutes per part).
(int, int) breakSplit(int perSession) =>
    perSession >= 10 ? (2, (perSession / 2).ceil()) : (1, perSession);

// ---------------------------------------------------------------------------
// Today's habit and reminder times
// ---------------------------------------------------------------------------

/// Why today's habit differs from the plan's main habit.
enum HabitChange { none, firstNights, outdoorHeat, heavyWork, fasting, notAllowed }

class DayRules {
  final DateTime date;
  final bool hot;
  final bool fasting;
  final bool firstNights;
  final String habitId; // today's habit (the plan's main habit unless [change])
  final HabitChange change;
  final List<int> reminderTimes; // local minutes of the day, max 2, none in quiet hours
  final int quietStart;
  final int quietEnd;
  final bool movedForHeat; // a reminder moved out of 12:30-15:00
  final bool movedForFasting;

  const DayRules({
    required this.date,
    required this.hot,
    required this.fasting,
    required this.firstNights,
    required this.habitId,
    required this.change,
    required this.reminderTimes,
    required this.quietStart,
    required this.quietEnd,
    this.movedForHeat = false,
    this.movedForFasting = false,
  });

  Habit get habit => habitById(habitId);

  /// Outdoor-type movement habit in the hot season: show the "not at midday" note.
  bool get heatNote => hot && habit.outdoor;
}

/// Today's habit: the plan's main habit, unless the environment rules say otherwise.
/// Replacements come only from the user's own backups or the approved list (C3).
(String, HabitChange) effectiveHabit({
  required Profile profile,
  required Plan plan,
  required DateTime date,
  bool fasting = false,
  bool firstNights = false,
}) {
  final r = filterHabits(profile: profile, domains: plan.domains, today: date, ramadanMode: fasting);
  final allowed = {for (final h in r.habits) h.id};
  String? backup(bool Function(Habit) ok) =>
      plan.backupHabitIds.where((id) => allowed.contains(id) && ok(habitById(id))).firstOrNull;
  String firstSleep() =>
      r.habits.firstWhere((h) => h.area == HabitArea.sleep && h.kind == HabitKind.main).id;
  bool isSleep(Habit h) => h.area == HabitArea.sleep;

  final main = habitById(plan.mainHabitId);
  if (firstNights && !isSleep(main)) {
    return (
      backup(isSleep) ?? (allowed.contains('napBeforeShift') ? 'napBeforeShift' : firstSleep()),
      HabitChange.firstNights
    );
  }
  if (!allowed.contains(main.id)) {
    final reason = r.removed[main.id];
    if (reason == HabitFilterReason.outdoorHeat) {
      // Rest, water and sleep first: a sleep backup, else the best sleep habit.
      return (backup(isSleep) ?? firstSleep(), HabitChange.outdoorHeat);
    }
    final b = backup((h) => !(fasting && h.extraMovement && !h.ramadan)) ?? firstSleep();
    return (b, reason == HabitFilterReason.heavyWork ? HabitChange.heavyWork : HabitChange.notAllowed);
  }
  if (fasting && main.extraMovement && !main.ramadan && allowed.contains('walkAfterIftar')) {
    return ('walkAfterIftar', HabitChange.fasting);
  }
  return (main.id, HabitChange.none);
}

/// One day's rules: today's habit, quiet hours and the (at most 2) reminder times.
DayRules dayRules({
  required Profile profile,
  required Plan plan,
  required Settings settings,
  FastingMode? fasting,
  required DateTime date,
}) {
  // The UAE heat season needs a place; without a city there is no heat-day hint (Chi, thread 0004 fix 10).
  final hot = profile.city != null && isHotSeason(date);
  final fast = fasting?.covers(date) ?? false;
  // the first two days of a new shift type: rotating's next-nights date, or a change in My shifts (thread 0008)
  final firstNights = inFirstNights(profile, date) || inFirstDaysOfNewShift(settings, profile, date);
  final (habitId, change) =
      effectiveHabit(profile: profile, plan: plan, date: date, fasting: fast, firstNights: firstNights);
  final habit = habitById(habitId);

  var qs = settings.quietStart, qe = settings.quietEnd;
  var times = <int>[-1, -1];
  var movedHeat = false, movedFast = false;
  if (profile.shift != ShiftType.irregular) {
    times = [settings.reminder1, settings.reminder2];
    if (firstNights) {
      final n = suggestedReminderSettings(ShiftType.nightFixed, settings);
      times = [n.reminder1, n.reminder2];
      qs = n.quietStart;
      qe = n.quietEnd;
    } else if (profile.shift == ShiftType.longOrSplit && settings.breakMinute >= 0 && times[1] >= 0) {
      times[1] = settings.breakMinute; // the "right moment" reminder comes in the break
    }
    if (fast && times[1] >= 0) {
      final t = habit.area == HabitArea.movement ? kAfterIftar : kSleepBeforeSuhoor;
      if (!inQuiet(t, qs, qe)) {
        movedFast = times[1] != t;
        times[1] = t;
      }
    }
  }
  // C5 "Move": the user moved one reminder for this day only.
  if (settings.movedDate == dateKey(date) && settings.movedTime >= 0) {
    times[settings.movedIndex.clamp(0, 1)] = settings.movedTime;
  }
  // C4 heat: never an outdoor movement reminder 12:30-15:00 (applies to every shift).
  if (hot && habit.outdoor) {
    for (var i = 0; i < times.length; i++) {
      if (times[i] >= 0 && inMidday(times[i])) {
        movedHeat = true;
        times[i] = !inQuiet(kAfterSunset, qs, qe)
            ? kAfterSunset
            : (!inQuiet(kEarlyMorning, qs, qe) ? kEarlyMorning : -1);
      }
    }
  }
  final out = <int>[];
  for (final t in times) {
    if (t >= 0 && !inQuiet(t, qs, qe) && !out.contains(t)) out.add(t);
  }
  return DayRules(
    date: dateOnly(date),
    hot: hot,
    fasting: fast,
    firstNights: firstNights,
    habitId: habitId,
    change: change,
    reminderTimes: out.take(2).toList(),
    quietStart: qs,
    quietEnd: qe,
    movedForHeat: movedHeat,
    movedForFasting: movedFast,
  );
}

class ReminderEvent {
  final DateTime at; // local wall-clock time
  final String habitId;
  final bool first; // the "today's small step" reminder of the day
  const ReminderEvent(this.at, this.habitId, {this.first = false});
}

/// Reminders for the next [days] days, each day's from its own rules (season,
/// fasting dates, the first nights), so nothing depends on a daily repeat.
/// Irregular hours: keyed to the last check-in or app open, not fixed times.
List<ReminderEvent> reminderSchedule({
  required Profile profile,
  required Plan plan,
  required Settings settings,
  FastingMode? fasting,
  required DateTime now,
  int days = 7,
  DateTime? lastActive,
  DateTime? lastCheckin,
  bool checkedInToday = false,
}) {
  final out = <ReminderEvent>[];
  DayRules rulesFor(DateTime d) =>
      dayRules(profile: profile, plan: plan, settings: settings, fasting: fasting, date: d);

  for (var i = 0; i < days; i++) {
    final date = DateTime(now.year, now.month, now.day + i);
    final r = rulesFor(date);
    for (var k = 0; k < r.reminderTimes.length; k++) {
      final t = r.reminderTimes[k];
      final at = DateTime(date.year, date.month, date.day, t ~/ 60, t % 60);
      if (at.isAfter(now)) out.add(ReminderEvent(at, r.habitId, first: k == 0));
    }
  }

  if (profile.shift == ShiftType.irregular) {
    final cands = <DateTime>[
      if (lastActive != null && !checkedInToday)
        lastActive.add(Duration(minutes: settings.irregularGapMinutes)),
      if (lastCheckin != null) lastCheckin.add(const Duration(days: 1)),
    ];
    for (final at in cands) {
      if (!at.isAfter(now) || daysBetween(now, at) >= days) continue;
      final r = rulesFor(at);
      final m = at.hour * 60 + at.minute;
      if (inQuiet(m, r.quietStart, r.quietEnd)) continue;
      if (r.hot && r.habit.outdoor && inMidday(m)) continue;
      final sameDay = out.where((e) => daysBetween(e.at, at) == 0).toList();
      if (sameDay.length >= 2) continue;
      if (sameDay.any((e) => e.at.difference(at).inMinutes.abs() < 60)) continue;
      out.add(ReminderEvent(at, r.habitId, first: sameDay.isEmpty));
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

// ---------------------------------------------------------------------------
// C5 Lapse Radar: heads-up before a change
// ---------------------------------------------------------------------------

enum RadarKind { nightsSoon, nextNightsUnknown, ramadanSoon, heatSoon }

class RadarItem {
  final RadarKind kind;
  final int days; // days until the change (0 = today)
  final String key; // for "hide" (e.g. "ramadan-2027-02-08")
  final DateTime? from;
  final DateTime? to;
  const RadarItem(this.kind, this.days, this.key, {this.from, this.to});
}

const kRamadanHeadsUpDays = 14;
const kHeatHeadsUpDays = 7;

List<RadarItem> lapseRadar({required Profile profile, FastingMode? fasting, required DateTime today}) {
  final out = <RadarItem>[];
  final dn = daysToNights(profile, today);
  if (dn != null && dn >= 1 && dn <= kNightsHeadsUpDays) {
    out.add(RadarItem(RadarKind.nightsSoon, dn, 'nights-${profile.nextNightsDate}'));
  }
  if (profile.shift == ShiftType.rotating && (dn == null || dn <= -kNightsSleepOnlyDays)) {
    out.add(RadarItem(RadarKind.nextNightsUnknown, 0, 'nextNights-${profile.nextNightsDate ?? ''}'));
  }
  final ram = suggestedRamadan(today, profile.city);
  if (ram != null && fasting == null) {
    final d = daysBetween(today, ram.from);
    if (d <= kRamadanHeadsUpDays) {
      out.add(RadarItem(RadarKind.ramadanSoon, d < 0 ? 0 : d, 'ramadan-${dateKey(ram.from)}',
          from: ram.from, to: ram.to));
    }
  }
  final dh = daysToHotSeason(today);
  if (dh >= 1 && dh <= kHeatHeadsUpDays) {
    out.add(RadarItem(RadarKind.heatSoon, dh, 'heat-${today.year}'));
  }
  return out;
}
