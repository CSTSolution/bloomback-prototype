// Rules C4 reminders, a port of wearable/lib/bbcore/src/reminders.cpp:
// at most 2 a day, never in quiet (sleep) hours, no catch-up nagging.
import '../data/models.dart';

const kReminderWindowMin = 30; // a reminder only fires within 30 min of its time

bool inQuiet(int minuteOfDay, int quietStart, int quietEnd) {
  if (quietStart == quietEnd) return false;
  if (quietStart < quietEnd) return minuteOfDay >= quietStart && minuteOfDay < quietEnd;
  return minuteOfDay >= quietStart || minuteOfDay < quietEnd; // wraps past midnight
}

/// Reminder index (0 or 1) due now, or -1. sentMask bit i = reminder i already sent today.
int dueReminder(int minuteOfDay, Settings s, int sentMask) {
  if (inQuiet(minuteOfDay, s.quietStart, s.quietEnd)) return -1;
  final times = [s.reminder1, s.reminder2];
  for (var i = 0; i < 2; i++) {
    final t = times[i];
    if (t < 0 || (sentMask & (1 << i)) != 0) continue;
    final since = (minuteOfDay - t + 1440) % 1440;
    if (since < kReminderWindowMin) return i;
  }
  return -1;
}

/// The reminder times that will actually be scheduled (max 2, none in quiet hours).
List<int> activeReminderTimes(Settings s) => [s.reminder1, s.reminder2]
    .where((t) => t >= 0 && !inQuiet(t, s.quietStart, s.quietEnd))
    .take(2)
    .toList();

/// Suggested usual sleep for onboarding screen 5 (A1), as (fall asleep, wake up)
/// minutes of the day, from the shift picked on screen 4. Only a starting point:
/// the user sets their own times. Fixed nights: day sleep after the shift, as in
/// Chi's screen 5 (08:30 to 14:00, persona Ravi, C7).
(int, int) suggestedSleepTimes(ShiftType shift) => switch (shift) {
      ShiftType.nightFixed => (8 * 60 + 30, 14 * 60),
      ShiftType.rotating => (23 * 60 + 30, 5 * 60 + 30),
      ShiftType.dayFixed || ShiftType.longOrSplit || ShiftType.irregular => (23 * 60, 6 * 60),
    };

/// When a habit is done, seen from the shift (its C3 cue "After I ..."): the
/// reminder should come at that moment, not at a fixed time of day (C4).
enum HabitMoment { afterShift, beforeShift, afterWork, anyTime }

HabitMoment habitMoment(String? habitId) => switch (habitId) {
      // NIOSH module 9: "go directly to bed when you arrive home"; blackout for day sleep.
      'homeToBed' || 'blackout' => HabitMoment.afterShift,
      'napBeforeShift' => HabitMoment.beforeShift,
      // the habits whose cue is "After I finish work, ..." (l10n habitAnchor)
      'briskWalk' || 'stairs' || 'strength' || 'indoorWalk' => HabitMoment.afterWork,
      _ => HabitMoment.anyTime,
    };

/// Day work: a habit done "after I finish work" is reminded at the end of the work day (Chi's design 20b,
/// thread 0004 fix 6: "After work · reminder 17:30"), not at 07:30.
const kAfterWorkReminder = 17 * 60 + 30;

/// Fixed nights (C7: 22:00-07:00): end of the shift, before the quiet hours start
/// at 08:00 (Chi's screen 11 "Remind me at 07:30").
const kNightShiftEndReminder = 7 * 60 + 30;

/// Fixed nights: after the day sleep (quiet hours end 15:00), before the shift.
const kNightShiftStartReminder = 16 * 60;

/// Suggested reminder times and quiet hours for the shift type (B6 axis 2, C4, C7)
/// and, on fixed nights, for the moment of the chosen habit ([habitId]): an
/// after-shift habit is reminded at the end of the shift, a before-shift nap
/// before the shift. The user can change or turn off any of them.
Settings suggestedReminderSettings(ShiftType shift, Settings current, {String? habitId}) {
  final s = Settings.fromJson(current.toJson());
  switch (shift) {
    case ShiftType.nightFixed:
      // Quiet hours in the day (day sleep).
      s.quietStart = 8 * 60;
      s.quietEnd = 15 * 60;
      switch (habitMoment(habitId)) {
        case HabitMoment.afterShift:
          // One reminder at the right moment: when the shift ends.
          s.reminder1 = kNightShiftEndReminder;
          s.reminder2 = -1;
        case HabitMoment.beforeShift:
          s.reminder1 = kNightShiftStartReminder;
          s.reminder2 = -1;
        case HabitMoment.anyTime || HabitMoment.afterWork:
          // Small step at the start of the user's day, a nudge at the end of the shift.
          s.reminder1 = kNightShiftStartReminder;
          s.reminder2 = 6 * 60 + 30;
      }
    case ShiftType.irregular:
      // Reminders follow check-ins, not fixed times (rules/environment.dart
      // reminderSchedule); these fixed times are not used while the shift is irregular.
      s.quietStart = 22 * 60;
      s.quietEnd = 6 * 60;
      s.reminder1 = 19 * 60;
      s.reminder2 = -1;
    case ShiftType.dayFixed:
    case ShiftType.rotating:
    case ShiftType.longOrSplit: // reminder 2 moves to the break when one is set (environment.dart)
      s.quietStart = 22 * 60;
      s.quietEnd = 6 * 60;
      if (shift == ShiftType.dayFixed && habitMoment(habitId) == HabitMoment.afterWork) {
        // one reminder, at the moment of the habit's cue
        s.reminder1 = kAfterWorkReminder;
        s.reminder2 = -1;
      } else {
        s.reminder1 = 7 * 60 + 30;
        s.reminder2 = 18 * 60 + 30;
      }
  }
  return s;
}
