// "Your day" (Chi, thread 0008, 18/11): a sleep plan around today's shift, the user's week of shifts, and what is
// coming up. Times come from the user's own answers (work-day / day-off sleep from onboarding, shift times from
// "My shifts"); the advice is NIOSH's own wording (training for nurses on shift work, modules 6 and 9), quoted in
// the "?". The clock times BloomBack adds itself (the nap 3 h before the shift, wind-down 1 h before bed) are
// labelled "BloomBack suggestion". A prototype: the week repeats by weekday.
import '../data/models.dart';
import 'habits.dart';

enum DayShift { night, day, off }

/// The usual week when the user has not set one. Fixed nights: Sunday to Thursday nights, Friday and Saturday off
/// (a sample week only, as in Chi's design and the demo band; Chi 19/11: never call it "the UAE weekend"); everyone
/// else: Monday to Friday days.
List<DayShift> defaultWeek(ShiftType shift) {
  const n = DayShift.night, d = DayShift.day, o = DayShift.off;
  return shift == ShiftType.nightFixed ? [n, n, n, n, o, o, n] : [d, d, d, d, d, o, o];
}

/// The user's week, Monday first (7 entries).
List<DayShift> weekOf(Settings st, Profile p) {
  final w = st.shiftWeek;
  if (w != null && w.length == 7) return [for (final x in w) DayShift.values.byName(x)];
  return defaultWeek(p.shift);
}

/// Monday = 0 … Sunday = 6.
int weekdayIndex(DateTime d) => d.weekday - 1;

DayShift shiftOn(Settings st, Profile p, DateTime d) => weekOf(st, p)[weekdayIndex(d)];

/// A change of shift type within the last 2 days (today counts): for the first two days on the new type BloomBack
/// keeps to sleep steps only (the first-nights rule, rules C4 / B6). Only once the user has set their week.
bool inFirstDaysOfNewShift(Settings st, Profile p, DateTime today) {
  if (st.shiftWeek == null) return false;
  final t = shiftOn(st, p, today);
  if (t == DayShift.off) return false;
  // working days of the same type just before today (days off skipped), until a different type shows
  var same = 0;
  for (var back = 1; back <= 6; back++) {
    final prev = shiftOn(st, p, today.subtract(Duration(days: back)));
    if (prev == DayShift.off) continue;
    // today is the 1st (same == 0) or 2nd (same == 1) day on the new type
    if (prev != t) return same < kNewShiftSleepOnlyDays;
    same++;
  }
  return false;
}

const kNewShiftSleepOnlyDays = 2;

// ---------------------------------------------------------------------------
// NIOSH wording (read on the original pages by Chi's agent, 16 and 18 Nov 2026)
// ---------------------------------------------------------------------------

const kNioshNap =
    'NIOSH Training for Nurses on Shift Work and Long Work Hours, module 9 '
    '(cdc.gov/niosh/work-hour-training-for-nurses/longhours/mod9/05.html): "If it is possible to take a nap before '
    'returning to work, do so. This can increase your overall sleep time and may help you to stay alert during the '
    'night." The time, 3 hours before your shift, is a BloomBack suggestion.';
const kNioshLight =
    'NIOSH Training for Nurses on Shift Work and Long Work Hours, module 9 (…/mod9/06.html), Light: "You can be more '
    'alert if you increase your light exposure during the first half of the shift." "…reduce your light exposure '
    'during the second half of the shift."';
const kNioshCoffee =
    'NIOSH Training for Nurses on Shift Work and Long Work Hours, module 6 (…/mod6/11.html): "If you drink a cup of '
    'coffee near the end of a night shift, there can still be enough caffeine in your system to cause restlessness or '
    'waking while you are trying to sleep the morning after your shift."';
const kNioshHome =
    'NIOSH Training for Nurses on Shift Work and Long Work Hours, module 9 (…/mod9/05.html): "Go directly to bed when '
    'you arrive home." "Be sure that your sleep environment is very dark … or wear an eye mask while sleeping."';
const kNioshDaysOff =
    'NIOSH Training for Nurses on Shift Work and Long Work Hours, module 9 (…/mod9/03.html), a compromise sleep '
    'schedule for night workers: "On days off, try to stay up until the middle of the night (3-4 a.m.), and sleep '
    'until noon or 1 p.m. That way, your body always has some hours of sleep that are the same every 24-hour period".';
const kPlanSleepSource =
    'Your plan: the sleep times you gave when you started (More › What we use). With a band, the line under it is the '
    "band's estimate from wrist movement (van Hees et al. 2015, 2018), not a medical sleep test.";
const kNewShiftSource =
    'BloomBack suggestion (rules B6/C4, the first-nights rule): for the first two days on a new shift type, BloomBack '
    'keeps to sleep steps only.';
const kWindDownSource = 'AASM Healthy Sleep Habits #5 (relax before bed) and #9 (screens off at least 30 min before '
    'sleep). The time, 1 hour before your bedtime, is a BloomBack suggestion.';
const kWakeSource = 'AASM Healthy Sleep Habits #1: get up at the same time every day, weekends too.';
const kBedSource = 'AASM Healthy Sleep Habits #7: keep the bedroom quiet, relaxing and cool.';

enum DayRowKind { mainSleep, nap, shiftStart, coffee, homeToBed, wake, step, windDown, bedtime, dayOff }

class DayRow {
  final DayRowKind kind;
  /// Minutes from today's local midnight; may be ≥ 1440 for tomorrow morning; null = no clock time ("late").
  final int? at;
  /// For a row that lasts (main sleep): minutes from midnight it ends.
  final int? until;
  final String source;
  /// The row is the user's small step today.
  final bool isStep;
  const DayRow(this.kind, this.at, this.source, {this.until, this.isStep = false});
}

class YourDay {
  final DayShift today;
  final List<DayRow> rows;
  const YourDay(this.today, this.rows);
}

int _mod(int m) => ((m % 1440) + 1440) % 1440;

/// Today's timeline for [p] on [now], with the week in [st] and today's small step [habitId].
YourDay buildYourDay({required Profile p, required Settings st, required DateTime now, required String habitId}) {
  final date = DateTime(now.year, now.month, now.day);
  final today = shiftOn(st, p, date);
  final yesterday = shiftOn(st, p, date.subtract(const Duration(days: 1)));
  final rows = <DayRow>[];
  // Main sleep: after a night at work, the work-day window; otherwise the day-off window (or the work-day one).
  final workSleep = (p.selfSleepStart ?? 23 * 60, p.selfWakeTime ?? 7 * 60);
  final offSleep = (p.selfOffSleepStart ?? workSleep.$1, p.selfOffWakeTime ?? workSleep.$2);
  switch (today) {
    case DayShift.night:
      final (s, w) = yesterday == DayShift.night ? workSleep : offSleep;
      rows.add(DayRow(DayRowKind.mainSleep, _mod(s), kPlanSleepSource, until: _mod(w)));
      final start = st.nightShiftStart, end = st.nightShiftEnd;
      rows.add(DayRow(DayRowKind.nap, _mod(start - 180), kNioshNap, isStep: habitId == 'napBeforeShift'));
      rows.add(DayRow(DayRowKind.shiftStart, start, kNioshLight));
      rows.add(const DayRow(DayRowKind.coffee, null, kNioshCoffee));
      rows.add(DayRow(DayRowKind.homeToBed, end < start ? end + 1440 : end, kNioshHome,
          isStep: habitId == 'homeToBed' || habitId == 'blackout'));
    case DayShift.day:
      final (s, w) = workSleep;
      rows.add(DayRow(DayRowKind.wake, _mod(w), kWakeSource, isStep: habitId == 'sameWake'));
      // a movement step sits at its reminder (after work: 17:30), or 30 min after the day shift
      if (!_sleepHabit(habitId)) {
        rows.add(DayRow(DayRowKind.step, st.reminder1 >= 0 ? st.reminder1 : st.dayShiftEnd + 30, '', isStep: true));
      }
      final bed = s < 12 * 60 ? s + 1440 : s; // after midnight = tonight
      rows.add(DayRow(DayRowKind.windDown, bed - 60, kWindDownSource,
          isStep: habitId == 'windDown' || habitId == 'screensOff' || habitId == 'dimLight'));
      rows.add(DayRow(DayRowKind.bedtime, bed, kBedSource, isStep: habitId == 'bedEarlier' || habitId == 'quietRoom'));
    case DayShift.off:
      final (s, w) = offSleep;
      final bed = s < 12 * 60 ? s + 1440 : s;
      if (weekOf(st, p).contains(DayShift.night)) {
        // a night worker's day off: NIOSH's compromise schedule
        if (yesterday == DayShift.night) {
          rows.add(DayRow(DayRowKind.mainSleep, _mod(workSleep.$1), kPlanSleepSource, until: _mod(workSleep.$2)));
        }
        rows.add(const DayRow(DayRowKind.dayOff, null, kNioshDaysOff));
      } else {
        rows.add(DayRow(DayRowKind.wake, _mod(w), kWakeSource, isStep: habitId == 'sameWake'));
      }
      rows.add(DayRow(DayRowKind.bedtime, bed, kBedSource));
  }
  // the day-off tip sits after the morning sleep, before the evening
  int key(DayRow r) => r.kind == DayRowKind.dayOff ? 12 * 60 : (r.at ?? _lateAt(rows));
  rows.sort((a, b) => key(a).compareTo(key(b)));
  return YourDay(today, rows);
}

bool _sleepHabit(String id) => habitById(id).area == HabitArea.sleep;

/// "late" (the coffee row) sits just before the end of the night shift.
int _lateAt(List<DayRow> rows) {
  final home = rows.where((r) => r.kind == DayRowKind.homeToBed).firstOrNull;
  return (home?.at ?? 30 * 60) - 1;
}

/// Is [row] already behind us at [nowMin] (minutes from today's midnight)?
bool rowPassed(DayRow row, List<DayRow> rows, int nowMin) {
  if (row.kind == DayRowKind.dayOff) return false;
  final end = row.until != null && row.at != null
      ? (row.until! < row.at! ? row.until! + 1440 : row.until!)
      : (row.at ?? _lateAt(rows));
  return nowMin >= end;
}

// ---------------------------------------------------------------------------
// Coming up (My shifts)
// ---------------------------------------------------------------------------

enum ComingKind { daysOffAfterNights, newShiftType }

class ComingUp {
  final ComingKind kind;
  final List<DateTime> days;
  final DayShift? to;
  const ComingUp(this.kind, this.days, {this.to});
}

/// From tomorrow to the end of next 7 days: days off right after nights, and a change of shift type.
List<ComingUp> comingUp(Settings st, Profile p, DateTime now) {
  final out = <ComingUp>[];
  final base = DateTime(now.year, now.month, now.day);
  DayShift on(int i) => shiftOn(st, p, base.add(Duration(days: i)));
  var lastWork = <DayShift>[for (var b = 0; b <= 6; b++) on(-b)].firstWhere((x) => x != DayShift.off, orElse: () => DayShift.off);
  for (var i = 1; i <= 7; i++) {
    final t = on(i);
    if (t == DayShift.off && on(i - 1) == DayShift.night) {
      final days = <DateTime>[];
      for (var j = i; j <= 7 && on(j) == DayShift.off; j++) {
        days.add(base.add(Duration(days: j)));
      }
      out.add(ComingUp(ComingKind.daysOffAfterNights, days));
    }
    if (t != DayShift.off) {
      if (lastWork != DayShift.off && t != lastWork) {
        out.add(ComingUp(ComingKind.newShiftType, [base.add(Duration(days: i))], to: t));
      }
      lastWork = t;
    }
  }
  return out;
}
