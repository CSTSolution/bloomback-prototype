// Rules B4: where the user is now. Pure Dart.

/// Movement: 4 levels by weekly moderate minutes (HHS 2018 ch. 2, pp. 20-21).
enum MoveLevel { inactive, insufficient, active, highlyActive }

/// Sleep: 2 levels per 24 h (AASM/SRS 2015, CDC "About Sleep").
enum SleepLevel { short, enough }

const kMoveGuideline = 150; // min/week moderate (DHA 2026 9.2.1, WHO 2020, HHS 2018)
const kMoveUpper = 300;
const kSleepGuideline = 7 * 60; // min per 24 h

const kMoveLevelSource =
    'HHS Physical Activity Guidelines for Americans, 2nd ed. 2018, ch. 2 pp. 20-21; '
    'same 150-300 min bands as DHA Physical Activity Guideline 2026 sec. 9.2.1 and WHO 2020.';
const kSleepLevelSource =
    'AASM/SRS consensus (Watson et al., Sleep 2015;38:843): at least 7 hours; '
    'CDC "About Sleep": adults 18-60 need 7 or more hours.';

MoveLevel moveLevel(int weeklyModerateMinutes) {
  if (weeklyModerateMinutes <= 0) return MoveLevel.inactive;
  if (weeklyModerateMinutes < kMoveGuideline) return MoveLevel.insufficient;
  if (weeklyModerateMinutes <= kMoveUpper) return MoveLevel.active;
  return MoveLevel.highlyActive;
}

SleepLevel sleepLevel(int sleepMinutesPer24h) =>
    sleepMinutesPer24h < kSleepGuideline ? SleepLevel.short : SleepLevel.enough;

/// C1 step 1 for cards that touch both areas: suggest the area further from
/// the guideline (relative gap). Returns true for sleep.
bool sleepGapIsBigger(int sleepMinutes, int weeklyMoveMinutes) {
  final sleepGap = (kSleepGuideline - sleepMinutes).clamp(0, kSleepGuideline) / kSleepGuideline;
  final moveGap = (kMoveGuideline - weeklyMoveMinutes).clamp(0, kMoveGuideline) / kMoveGuideline;
  return sleepGap >= moveGap;
}
