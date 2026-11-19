// Plain data types shared by the band link, the store, analytics and rules.
// Field meanings match wearable/lib/bbcore/src/bb_types.h and docs/PROTOCOL.md.

/// One minute from the band (UTC unix minute).
class MinuteRec {
  final int minute; // UTC unix time / 60
  final int steps; // steps in this minute
  final int medDiff; // median arm-angle change between 5 s epochs, centi-degrees
  final int maxDiff; // largest arm-angle change between 5 s epochs, centi-degrees
  final int flags; // bit 0 = charging

  const MinuteRec(this.minute, this.steps, this.medDiff, this.maxDiff, this.flags);

  static const int charging = 1;
  bool get isCharging => (flags & charging) != 0;

  /// bb_types.h kModerateCadence: >= 100 steps/min is moderate
  /// (Tudor-Locke et al., Br J Sports Med 2018).
  static const int moderateCadence = 100;
  bool get isModerate => steps >= moderateCadence;
}

/// Check-in answer (rules C4): done / partly / not today.
enum CheckinStatus { done, partial, notToday }

/// Where a number came from (rules B1): band ("watch") or typed by the user.
enum DataSource { watch, selfReport }

extension DataSourceCode on DataSource {
  String get code => this == DataSource.watch ? 'watch' : 'self-report';
}

class Checkin {
  final int minute; // UTC unix minute
  final CheckinStatus status;
  final DataSource source; // watch = tapped on the band, selfReport = tapped in the app
  const Checkin(this.minute, this.status, this.source);
}

/// Work axes from rules B6.
enum WorkActivity { sitting, standingLight, moderate, heavy }

enum ShiftType { dayFixed, nightFixed, rotating, longOrSplit, irregular }

enum WorkPlace { indoor, outdoor, both }

/// A1 ④: city from a short list (no exact location, A3). Used for the region's
/// Ramadan dates and the heat season; never for tracking.
enum City { abuDhabi, alAin, dubai, sharjah, otherUae, other }

extension CityRegion on City {
  bool get inUae => this != City.other;
}

/// Local calendar date as "YYYY-MM-DD" (no time, no zone).
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseDateKey(String? k) {
  if (k == null || k.isEmpty) return null;
  final p = k.split('-');
  if (p.length != 3) return null;
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole calendar days from [a] to [b] (b - a), safe across DST.
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Which area the user chose to work on (C1 step 1). The user decides.
enum Domain { sleep, movement }

/// Everything the user told BB during onboarding. Only what the rules need (A1, A3).
class Profile {
  List<String> goalIds; // 1-3 card ids from rules/goals.dart
  String mainGoalId;
  String motivation; // optional, kept word for word (B5)
  WorkActivity activity;
  ShiftType shift;
  WorkPlace place;
  int selfSleepMinutes; // self-reported sleep per 24 h
  int selfWalkMinutes; // self-reported moderate minutes per week
  bool askDoctorFirst; // B3: shown as a note only, never blocks
  int startMinute; // UTC unix minute when onboarding finished
  // A1 ①: required on day 1. Null only for profiles saved before 13 Nov.
  int? heightCm;
  int? weightKg;
  // A1 ④: required on day 1. Null only for profiles saved before 13 Nov.
  City? city;
  /// B6 axis 1 / C2 (moderate work): brisk minutes per week at work, optional.
  int workBriskMinutes;
  /// A1 ② bedtime regularity: self-reported spread between the earliest and the
  /// latest bedtime in a usual week (C2 "độ lệch giờ ngủ"). Null = not asked.
  int? selfBedtimeSpreadMinutes;
  /// B6 axis 2, rotating shift: date of the next switch to nights ("YYYY-MM-DD").
  String? nextNightsDate;
  /// A1 ② as asked on Chi's screen 5: usual fall-asleep and wake-up time (local
  /// minute of day). selfSleepMinutes is computed from them (+ naps) over 24 h.
  int? selfSleepStart;
  int? selfWakeTime;
  /// Chi's screen 5 (14/11): fall-asleep and wake-up time on days off. selfSleepStart/selfWakeTime are the work
  /// days; the bedtime spread (C2) is computed from the two bedtimes, never asked.
  int? selfOffSleepStart;
  int? selfOffWakeTime;
  /// A1 ③ "How often do you exercise, outside of work?": days a week x minutes.
  /// selfWalkMinutes = days x minutes.
  int? exerciseDays;
  int? exerciseMinutes;

  Profile({
    required this.goalIds,
    required this.mainGoalId,
    this.motivation = '',
    required this.activity,
    required this.shift,
    required this.place,
    required this.selfSleepMinutes,
    required this.selfWalkMinutes,
    this.askDoctorFirst = false,
    required this.startMinute,
    this.heightCm,
    this.weightKg,
    this.city,
    this.workBriskMinutes = 0,
    this.selfBedtimeSpreadMinutes,
    this.nextNightsDate,
    this.selfSleepStart,
    this.selfWakeTime,
    this.selfOffSleepStart,
    this.selfOffWakeTime,
    this.exerciseDays,
    this.exerciseMinutes,
  });

  Map<String, dynamic> toJson() => {
        'goals': goalIds,
        'main': mainGoalId,
        'motivation': motivation,
        'activity': activity.name,
        'shift': shift.name,
        'place': place.name,
        'sleep': selfSleepMinutes,
        'walk': selfWalkMinutes,
        'doctor': askDoctorFirst,
        'start': startMinute,
        'height': heightCm,
        'weight': weightKg,
        'city': city?.name,
        'workBrisk': workBriskMinutes,
        'spread': selfBedtimeSpreadMinutes,
        'nextNights': nextNightsDate,
        'sleepStart': selfSleepStart,
        'wake': selfWakeTime,
        'offStart': selfOffSleepStart,
        'offWake': selfOffWakeTime,
        'exDays': exerciseDays,
        'exMin': exerciseMinutes,
      };

  static Profile fromJson(Map<String, dynamic> j) => Profile(
        goalIds: (j['goals'] as List).cast<String>(),
        mainGoalId: j['main'] as String,
        motivation: (j['motivation'] ?? '') as String,
        activity: WorkActivity.values.byName(j['activity'] as String),
        shift: ShiftType.values.byName(j['shift'] as String),
        place: WorkPlace.values.byName(j['place'] as String),
        selfSleepMinutes: j['sleep'] as int,
        selfWalkMinutes: j['walk'] as int,
        askDoctorFirst: (j['doctor'] ?? false) as bool,
        startMinute: j['start'] as int,
        heightCm: j['height'] as int?,
        weightKg: j['weight'] as int?,
        city: j['city'] == null ? null : City.values.byName(j['city'] as String),
        workBriskMinutes: (j['workBrisk'] ?? 0) as int,
        selfBedtimeSpreadMinutes: j['spread'] as int?,
        nextNightsDate: j['nextNights'] as String?,
        selfSleepStart: j['sleepStart'] as int?,
        selfWakeTime: j['wake'] as int?,
        selfOffSleepStart: j['offStart'] as int?,
        selfOffWakeTime: j['offWake'] as int?,
        exerciseDays: j['exDays'] as int?,
        exerciseMinutes: j['exMin'] as int?,
      );

  Profile copy() => Profile.fromJson(toJson());
}

/// The plan the user accepted (C1 steps 1-4, C2). Every change is the user's choice.
class Plan {
  Set<Domain> domains;
  int movementStep; // index into the movement ladder (rules/plan.dart)
  int movementBaseWeekly; // weekly minutes the "has a base" ladder starts from
  int movementIncrement; // +10 or +15 min/week for users with a base
  int sleepTargetMinutes; // this step's sleep target per 24 h
  int sleepIncrement; // 15 or 30 min per step
  String mainHabitId;
  List<String> backupHabitIds;
  int stepStartMinute; // when the current step started (for "1-2 weeks per step")
  /// Weekly movement goal: 150 (guideline). 300 only if the user chose the higher
  /// goal on the "Manage weight and waist" card (B5, C2).
  int movementGoal;
  /// Minutes per week counted from work (B6 axis 1), included in movementBaseWeekly.
  int workCredit;
  /// C2 sleep regularity: accepted bedtime-spread target (59 = "under 1 h"), or null.
  int? spreadTargetMinutes;
  int? spreadStepStartMinute;
  /// C1 step 5 (Gardner, Lally & Wardle 2012): "After I [cueAnchor], I will [cueAction]."
  /// The user's own words; null = the habit's default sentence.
  String? cueAnchor;
  String? cueAction;
  /// Screen 10b / 20b (rules B4/C2, 14/11), only when already at 150 min or more:
  /// 'keep' (suggested), 'to300' or 'strength'. null = under 150 (the step-up path).
  String? moveChoice;

  Plan({
    required this.domains,
    this.movementStep = 0,
    this.movementBaseWeekly = 0,
    this.movementIncrement = 10,
    required this.sleepTargetMinutes,
    this.sleepIncrement = 30,
    required this.mainHabitId,
    this.backupHabitIds = const [],
    required this.stepStartMinute,
    this.movementGoal = 150,
    this.workCredit = 0,
    this.spreadTargetMinutes,
    this.spreadStepStartMinute,
    this.cueAnchor,
    this.cueAction,
    this.moveChoice,
  });

  Map<String, dynamic> toJson() => {
        'domains': domains.map((d) => d.name).toList(),
        'mStep': movementStep,
        'mBase': movementBaseWeekly,
        'mInc': movementIncrement,
        'sTarget': sleepTargetMinutes,
        'sInc': sleepIncrement,
        'habit': mainHabitId,
        'backup': backupHabitIds,
        'stepStart': stepStartMinute,
        'mGoal': movementGoal,
        'workCredit': workCredit,
        'spreadTarget': spreadTargetMinutes,
        'spreadStart': spreadStepStartMinute,
        'cueAnchor': cueAnchor,
        'cueAction': cueAction,
        'mChoice': moveChoice,
      };

  static Plan fromJson(Map<String, dynamic> j) => Plan(
        domains: (j['domains'] as List).map((e) => Domain.values.byName(e as String)).toSet(),
        movementStep: j['mStep'] as int,
        movementBaseWeekly: j['mBase'] as int,
        movementIncrement: j['mInc'] as int,
        sleepTargetMinutes: j['sTarget'] as int,
        sleepIncrement: j['sInc'] as int,
        mainHabitId: j['habit'] as String,
        backupHabitIds: (j['backup'] as List).cast<String>(),
        stepStartMinute: j['stepStart'] as int,
        movementGoal: (j['mGoal'] ?? 150) as int,
        workCredit: (j['workCredit'] ?? 0) as int,
        spreadTargetMinutes: j['spreadTarget'] as int?,
        spreadStepStartMinute: j['spreadStart'] as int?,
        cueAnchor: j['cueAnchor'] as String?,
        cueAction: j['cueAction'] as String?,
        moveChoice: j['mChoice'] as String?,
      );
}

/// Phone + band settings (C4). Times are local minutes of the day, -1 = off.
class Settings {
  int reminder1;
  int reminder2;
  int quietStart;
  int quietEnd;
  int dayEnd; // sleep for day D = main sleep in the 24 h ending D dayEnd (firmware "de")
  bool useFakeBand;
  String? bandId; // remote id of the bonded band
  String? bandName;
  /// Long (12 h+) or split shift: usual break, local minute of day, -1 = not set (B6 axis 2).
  int breakMinute;
  /// Irregular hours: a reminder comes this long after the last check-in or app open.
  int irregularGapMinutes;
  /// C5 "Move": a one-day change of one reminder. movedDate "YYYY-MM-DD" or null.
  String? movedDate;
  int movedIndex;
  int movedTime;
  /// After Done or Partly (Chi, thread 0007): 'off' (default), 'chime' or 'song'.
  String sound;
  /// Built-in chime id (sound/after_sound.dart kChimes).
  String chime;
  /// The song the user picked, copied into the app's own folder; never uploaded. Null = none.
  String? songPath;
  String? songName;
  /// Daily health-knowledge questions: 0 = off, 1 (default), 2 or 3 a day.
  int quizPerDay;
  /// BloomBack music (sound 'music'): the track after Done (sound/after_sound.dart kMusic).
  String musicTrack;
  /// Music while doing a timed small step (Chi, thread 0007, 16/11): 'off' (default), 'music' or 'song'.
  String stepMusic;
  /// Timer minutes the user chose, by habit id (Chi, thread 0007, 17/11: BloomBack suggests, the user decides).
  Map<String, int> stepMins;
  /// "My shifts this week" (Chi, thread 0008): 7 entries Monday first, 'night' / 'day' / 'off'; null = the usual week.
  List<String>? shiftWeek;
  /// Shift times, local minute of day (My shifts › Edit times).
  int nightShiftStart;
  int nightShiftEnd;
  int dayShiftStart;
  int dayShiftEnd;

  Settings({
    this.reminder1 = 8 * 60,
    this.reminder2 = 20 * 60,
    this.quietStart = 22 * 60,
    this.quietEnd = 6 * 60,
    this.dayEnd = 18 * 60,
    this.useFakeBand = true,
    this.bandId,
    this.bandName,
    this.breakMinute = -1,
    this.irregularGapMinutes = 180,
    this.movedDate,
    this.movedIndex = 0,
    this.movedTime = -1,
    this.sound = 'off',
    this.chime = 'bell',
    this.songPath,
    this.songName,
    this.quizPerDay = 1,
    this.musicTrack = 'morning',
    this.stepMusic = 'off',
    Map<String, int>? stepMins,
    this.shiftWeek,
    this.nightShiftStart = 22 * 60,
    this.nightShiftEnd = 6 * 60,
    this.dayShiftStart = 7 * 60,
    this.dayShiftEnd = 15 * 60,
  }) : stepMins = stepMins ?? {};

  Map<String, dynamic> toJson() => {
        'r1': reminder1,
        'r2': reminder2,
        'qs': quietStart,
        'qe': quietEnd,
        'de': dayEnd,
        'fake': useFakeBand,
        'bandId': bandId,
        'bandName': bandName,
        'break': breakMinute,
        'gap': irregularGapMinutes,
        'movedDate': movedDate,
        'movedIndex': movedIndex,
        'movedTime': movedTime,
        'sound': sound,
        'chime': chime,
        'songPath': songPath,
        'songName': songName,
        'quiz': quizPerDay,
        'musicTrack': musicTrack,
        'stepMusic': stepMusic,
        'stepMins': stepMins,
        'shiftWeek': shiftWeek,
        'nightStart': nightShiftStart,
        'nightEnd': nightShiftEnd,
        'dayStart': dayShiftStart,
        'dayEndShift': dayShiftEnd,
      };

  static Settings fromJson(Map<String, dynamic> j) => Settings(
        reminder1: j['r1'] as int,
        reminder2: j['r2'] as int,
        quietStart: j['qs'] as int,
        quietEnd: j['qe'] as int,
        dayEnd: (j['de'] ?? 18 * 60) as int,
        useFakeBand: (j['fake'] ?? true) as bool,
        bandId: j['bandId'] as String?,
        bandName: j['bandName'] as String?,
        breakMinute: (j['break'] ?? -1) as int,
        irregularGapMinutes: (j['gap'] ?? 180) as int,
        movedDate: j['movedDate'] as String?,
        movedIndex: (j['movedIndex'] ?? 0) as int,
        movedTime: (j['movedTime'] ?? -1) as int,
        sound: (j['sound'] ?? 'off') as String,
        chime: (j['chime'] ?? 'bell') as String,
        songPath: j['songPath'] as String?,
        songName: j['songName'] as String?,
        quizPerDay: (j['quiz'] ?? 1) as int,
        musicTrack: (j['musicTrack'] ?? 'morning') as String,
        stepMusic: (j['stepMusic'] ?? 'off') as String,
        stepMins: {for (final e in ((j['stepMins'] as Map?) ?? const {}).entries) e.key as String: e.value as int},
        shiftWeek: (j['shiftWeek'] as List?)?.cast<String>(),
        nightShiftStart: (j['nightStart'] ?? 22 * 60) as int,
        nightShiftEnd: (j['nightEnd'] ?? 6 * 60) as int,
        dayShiftStart: (j['dayStart'] ?? 7 * 60) as int,
        dayShiftEnd: (j['dayEndShift'] ?? 15 * 60) as int,
      );
}

/// Where a health number came from (B1: label the source and the date).
enum MarkerSource { selfReport, checkup }

/// A1 ① optional numbers, offered after week 1 (B1 "ask gradually"). Null = "Don't know".
/// Used only for the D2 "ask a doctor" note; they never change levels or plans (core rule 6).
class Biomarkers {
  int? waistCm;
  int? systolic;
  int? diastolic;
  int? restingHr;
  double? glucose; // fasting
  bool glucoseMgDl; // unit of [glucose]: mg/dL, else mmol/L
  double? hba1c; // %
  MarkerSource source;
  /// Per-number source where it differs from [source] (keys: bp, waist, hr, glucose).
  Map<String, MarkerSource> sources;
  int measuredMinute; // UTC unix minute of the day measured

  Biomarkers({
    this.waistCm,
    this.systolic,
    this.diastolic,
    this.restingHr,
    this.glucose,
    this.glucoseMgDl = false,
    this.hba1c,
    this.source = MarkerSource.selfReport,
    Map<String, MarkerSource>? sources,
    required this.measuredMinute,
  }) : sources = sources ?? {};

  bool get isEmpty =>
      waistCm == null && systolic == null && diastolic == null && restingHr == null && glucose == null && hba1c == null;

  Map<String, dynamic> toJson() => {
        'waist': waistCm,
        'sys': systolic,
        'dia': diastolic,
        'hr': restingHr,
        'glu': glucose,
        'mgdl': glucoseMgDl,
        'a1c': hba1c,
        'src': source.name,
        if (sources.isNotEmpty) 'srcs': {for (final e in sources.entries) e.key: e.value.name},
        'at': measuredMinute,
      };

  static Biomarkers fromJson(Map<String, dynamic> j) => Biomarkers(
        waistCm: j['waist'] as int?,
        systolic: j['sys'] as int?,
        diastolic: j['dia'] as int?,
        restingHr: j['hr'] as int?,
        glucose: (j['glu'] as num?)?.toDouble(),
        glucoseMgDl: (j['mgdl'] ?? false) as bool,
        hba1c: (j['a1c'] as num?)?.toDouble(),
        source: MarkerSource.values.byName((j['src'] ?? 'selfReport') as String),
        sources: {
          for (final e in ((j['srcs'] as Map<String, dynamic>?) ?? const {}).entries)
            e.key: MarkerSource.values.byName(e.value as String),
        },
        measuredMinute: j['at'] as int,
      );
}

/// C4 Ramadan / habit #21. Only "fasting mode on, from - to" is stored: never a
/// religion or a reason (A3, core rule 7). Dates are local, inclusive.
class FastingMode {
  final String from; // "YYYY-MM-DD"
  final String to;
  const FastingMode(this.from, this.to);

  bool covers(DateTime localDate) {
    final f = parseDateKey(from)!, t = parseDateKey(to)!;
    final d = dateOnly(localDate);
    return !d.isBefore(f) && !d.isAfter(t);
  }

  Map<String, dynamic> toJson() => {'on': true, 'from': from, 'to': to};

  static FastingMode? fromJson(Map<String, dynamic>? j) =>
      j == null || j['on'] != true ? null : FastingMode(j['from'] as String, j['to'] as String);
}
