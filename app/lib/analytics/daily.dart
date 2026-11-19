// Daily and weekly numbers from band minutes, the same rules as
// wearable/lib/bbcore (export.cpp summarizeSteps) and the firmware's summarize():
// steps and moderate minutes per local day; sleep for day D = main sleep in the
// 24 h ending at D's day end (default 18:00 local).
import '../data/models.dart';
import 'sleep.dart';

/// Local day number (days since 1970-01-01 in the user's time zone).
int localDay(int utcMinute, int tzMinutes) {
  final local = utcMinute + tzMinutes;
  return local >= 0 ? local ~/ 1440 : (local - 1439) ~/ 1440;
}

/// UTC unix minute of local midnight for [day].
int dayStartMinute(int day, int tzMinutes) => day * 1440 - tzMinutes;

class DaySummary {
  final int day; // local day number
  final int dayStartMinute; // UTC minute of local midnight
  final int steps;
  final int moderateMinutes; // minutes with >= 100 steps
  final int recordedMinutes; // minutes with data and not charging
  final SleepWindow sleep;

  const DaySummary({
    required this.day,
    required this.dayStartMinute,
    required this.steps,
    required this.moderateMinutes,
    required this.recordedMinutes,
    required this.sleep,
  });

  bool get hasData => recordedMinutes > 0 || sleep.found;
}

/// [recs] sorted by minute. Pass at least the day before [day] too, for sleep.
DaySummary summarizeDay(List<MinuteRec> recs, int day, int tzMinutes, int dayEnd) {
  final start = dayStartMinute(day, tzMinutes);
  var steps = 0, moderate = 0, recorded = 0;
  final sleepEnd = start + dayEnd;
  final win = <MinuteRec>[];
  for (final r in recs) {
    if (r.minute >= start && r.minute < start + 1440) {
      steps += r.steps;
      if (r.isModerate) moderate++;
      if (!r.isCharging) recorded++;
    }
    if (r.minute >= sleepEnd - 1440 && r.minute < sleepEnd) win.add(r);
  }
  return DaySummary(
    day: day,
    dayStartMinute: start,
    steps: steps,
    moderateMinutes: moderate,
    recordedMinutes: recorded,
    sleep: detectMainSleep(win),
  );
}

/// Summaries for every local day in [fromDay, toDay] (inclusive).
List<DaySummary> summarizeDays(
    List<MinuteRec> recs, int fromDay, int toDay, int tzMinutes, int dayEnd) {
  // Split once by day so each day only scans its own minutes plus the day before.
  final byDay = <int, List<MinuteRec>>{};
  for (final r in recs) {
    (byDay[localDay(r.minute, tzMinutes)] ??= []).add(r);
  }
  return [
    for (var d = fromDay; d <= toDay; d++)
      summarizeDay([...?byDay[d - 1], ...?byDay[d]], d, tzMinutes, dayEnd),
  ];
}

class WeekSummary {
  final int index; // 0 = the user's first week
  final int days; // days of this week that have passed so far (1-7)
  final int daysWithData;
  final int moderateMinutes; // total minutes with >= 100 steps
  final int? avgSleepMinutes; // mean over nights found, null if none
  final int? avgSteps; // mean over days with data
  final int? onsetSpreadMinutes; // latest minus earliest sleep onset (regularity)
  final int checkinsDoneOrPartial;

  const WeekSummary({
    required this.index,
    required this.days,
    required this.daysWithData,
    required this.moderateMinutes,
    required this.avgSleepMinutes,
    required this.avgSteps,
    required this.onsetSpreadMinutes,
    required this.checkinsDoneOrPartial,
  });
}

/// Weeks counted from the user's first local day (rules C6: week 1 -> now).
List<WeekSummary> summarizeWeeks(List<DaySummary> days, Map<int, CheckinStatus> checkinByDay,
    int firstDay, int today, int tzMinutes, int dayEnd) {
  final out = <WeekSummary>[];
  for (var w = 0; firstDay + w * 7 <= today; w++) {
    final from = firstDay + w * 7;
    final to = (from + 6) < today ? from + 6 : today;
    final ds = days.where((d) => d.day >= from && d.day <= to).toList();
    final withData = ds.where((d) => d.recordedMinutes > 60).toList();
    final nights = ds.where((d) => d.sleep.found).toList();
    final onsets = nights
        .map((d) => d.sleep.startMinute - (d.dayStartMinute + dayEnd - 1440))
        .toList()
      ..sort();
    var checks = 0;
    for (var d = from; d <= to; d++) {
      final c = checkinByDay[d];
      if (c == CheckinStatus.done || c == CheckinStatus.partial) checks++;
    }
    out.add(WeekSummary(
      index: w,
      days: to - from + 1,
      daysWithData: withData.length,
      moderateMinutes: ds.fold(0, (s, d) => s + d.moderateMinutes),
      avgSleepMinutes: nights.isEmpty
          ? null
          : nights.fold(0, (s, d) => s + d.sleep.sleepMinutes) ~/ nights.length,
      avgSteps:
          withData.isEmpty ? null : withData.fold(0, (s, d) => s + d.steps) ~/ withData.length,
      onsetSpreadMinutes: onsets.length < 2 ? null : onsets.last - onsets.first,
      checkinsDoneOrPartial: checks,
    ));
  }
  return out;
}

/// The latest check-in of each local day (one tap per day counts).
Map<int, CheckinStatus> checkinsByDay(List<Checkin> checkins, int tzMinutes) {
  final sorted = [...checkins]..sort((a, b) => a.minute.compareTo(b.minute));
  return {for (final c in sorted) localDay(c.minute, tzMinutes): c.status};
}

/// Moderate minutes in the 7 days ending today (rolling, for "this week").
int rollingModerate(List<DaySummary> days, int today) => days
    .where((d) => d.day > today - 7 && d.day <= today)
    .fold(0, (s, d) => s + d.moderateMinutes);
