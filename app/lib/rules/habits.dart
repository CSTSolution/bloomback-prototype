// Rules C3: the habit list. BB only suggests habits from this list; nothing is
// made up. Titles live in l10n/strings.dart (by id); sources stay here.
// Filtered by the B6 work axes and ordered by the user's cards (C1 step 4).
import '../data/models.dart';

enum HabitArea { sleep, movement, calm }

enum HabitKind { main, support }

class Habit {
  final String id;
  final HabitArea area;
  final HabitKind kind;
  final List<String> cards; // goal card ids it fits ("Hợp với thẻ")
  final String source;
  final bool nightShift; // NIOSH shift-work habits
  final bool extraMovement; // extra exercise (dropped for outdoor work in summer)
  final bool heavy; // not suggested for heavy work (B6 axis 1)
  final bool ramadan;
  /// Usually done outdoors: never suggested 12:30-15:00 from 15 Jun to 15 Sep (C4).
  final bool outdoor;
  const Habit(this.id, this.area, this.kind, this.cards, this.source,
      {this.nightShift = false,
      this.extraMovement = false,
      this.heavy = false,
      this.ramadan = false,
      this.outdoor = false});
}

const _sleepCards = ['fallAsleep', 'wakeAtNight', 'wakeTooEarly', 'shiftSleep'];
const _dayCards = ['tiredOnWaking', 'sleepyAtWork', 'focus'];
const _moveCards = ['mood', 'calm', 'energy', 'weight', 'stronger', 'doctor'];

const kHabits = <Habit>[
  Habit('sameWake', HabitArea.sleep, HabitKind.main, [..._sleepCards, 'tiredOnWaking', 'doctor'], 'AASM Healthy Sleep Habits #1'),
  Habit('bedEarlier', HabitArea.sleep, HabitKind.main, [..._sleepCards, ..._dayCards, 'calm', 'doctor'], 'AASM Healthy Sleep Habits #2; AASM/SRS 2015 (7+ hours)'),
  Habit('bedWhenSleepy', HabitArea.sleep, HabitKind.support, ['fallAsleep'], 'AASM Healthy Sleep Habits #3'),
  Habit('up20', HabitArea.sleep, HabitKind.support, ['fallAsleep', 'wakeAtNight'], 'AASM Healthy Sleep Habits #4'),
  Habit('windDown', HabitArea.sleep, HabitKind.support, ['fallAsleep', 'calm'], 'AASM Healthy Sleep Habits #5; NHS "How to fall asleep faster and sleep better"'),
  Habit('bedForSleep', HabitArea.sleep, HabitKind.support, ['fallAsleep'], 'AASM Healthy Sleep Habits #6'),
  Habit('quietRoom', HabitArea.sleep, HabitKind.support, ['wakeAtNight'], 'AASM Healthy Sleep Habits #7; NHS'),
  Habit('dimLight', HabitArea.sleep, HabitKind.support, ['fallAsleep'], 'AASM Healthy Sleep Habits #8; NIOSH shift-work training module 8'),
  Habit('screensOff', HabitArea.sleep, HabitKind.support, ['fallAsleep', 'wakeAtNight'], 'AASM Healthy Sleep Habits #9; CDC "About Sleep"'),
  Habit('lightMeal', HabitArea.sleep, HabitKind.support, ['wakeAtNight'], 'AASM Healthy Sleep Habits #10'),
  Habit('noCaffeine', HabitArea.sleep, HabitKind.support, ['fallAsleep', 'wakeAtNight'], 'AASM Healthy Sleep Habits #12; CDC'),
  Habit('noAlcohol', HabitArea.sleep, HabitKind.support, ['wakeAtNight', 'wakeTooEarly'], 'AASM Healthy Sleep Habits #13'),
  Habit('lessFluid', HabitArea.sleep, HabitKind.support, ['wakeAtNight'], 'AASM Healthy Sleep Habits #14'),
  Habit('napBeforeShift', HabitArea.sleep, HabitKind.main, ['shiftSleep', 'sleepyAtWork'], 'NIOSH Training for Nurses on Shift Work and Long Work Hours, module 9', nightShift: true),
  Habit('homeToBed', HabitArea.sleep, HabitKind.main, ['shiftSleep', 'tiredOnWaking'], 'NIOSH Training for Nurses on Shift Work and Long Work Hours, module 9', nightShift: true),
  Habit('blackout', HabitArea.sleep, HabitKind.support, ['shiftSleep', 'wakeAtNight', 'tiredOnWaking'], 'NIOSH Training for Nurses on Shift Work and Long Work Hours, module 9', nightShift: true),
  Habit('briskWalk', HabitArea.movement, HabitKind.main, ['weight', 'stronger', 'mood', 'energy', 'doctor', 'calm'], 'DHA 2026 sec. 9.2.1; HHS 2018 ch. 7', extraMovement: true, outdoor: true),
  Habit('walkAfterMeal', HabitArea.movement, HabitKind.main, ['weight'], 'DHA 2026 sec. 9.1 (light activity also helps)', extraMovement: true, outdoor: true),
  Habit('stairs', HabitArea.movement, HabitKind.main, ['stronger', 'weight'], 'DHA 2026 sec. 12.2', extraMovement: true, heavy: true),
  Habit('indoorWalk', HabitArea.movement, HabitKind.main, _moveCards, 'HHS 2018 p. 92: move indoors when it is hot', extraMovement: true),
  Habit('walkAfterIftar', HabitArea.movement, HabitKind.main, _moveCards, 'BloomBack suggestion, based on brisk walking (DHA 2026 sec. 9.2.1)', extraMovement: true, ramadan: true, outdoor: true),
  Habit('strength', HabitArea.movement, HabitKind.main, ['stronger'], 'DHA 2026 sec. 9.2.2; HHS 2018 p. 63', extraMovement: true, heavy: true),
  Habit('standUp', HabitArea.movement, HabitKind.main, ['aches', 'focus'], 'DHA 2026 sec. 9.1 (limit long sitting)'),
  Habit('stretch', HabitArea.movement, HabitKind.support, ['aches', 'calm'], 'DHA 2026 sec. 12.2'),
  Habit('breathing', HabitArea.calm, HabitKind.support, ['calm'], 'NHS "Breathing exercises for stress"'),
];

Habit habitById(String id) => kHabits.firstWhere((h) => h.id == id);

/// MoHRE midday break season, 15 Jun - 15 Sep (rules B6 axis 3, C4).
bool isHotSeason(DateTime localDate) {
  final md = localDate.month * 100 + localDate.day;
  return md >= 615 && md <= 915;
}

/// Why a habit was left out (for the "Why?" sheet and tests).
enum HabitFilterReason { outdoorHeat, heavyWork, ramadanOff, notNightShift }

class HabitFilterResult {
  final List<Habit> habits; // allowed, best first
  final Map<String, HabitFilterReason> removed;
  const HabitFilterResult(this.habits, this.removed);
}

/// The habit list filtered by the B6 axes and ordered for the user's cards and areas.
HabitFilterResult filterHabits({
  required Profile profile,
  required Set<Domain> domains,
  required DateTime today,
  bool ramadanMode = false,
}) {
  final hot = isHotSeason(today);
  final night = profile.shift == ShiftType.nightFixed || profile.shift == ShiftType.rotating;
  final outdoor = profile.place == WorkPlace.outdoor || profile.place == WorkPlace.both;
  final removed = <String, HabitFilterReason>{};
  final scored = <(Habit, int)>[];

  for (final h in kHabits) {
    if (h.ramadan && !ramadanMode) {
      removed[h.id] = HabitFilterReason.ramadanOff;
      continue;
    }
    // Outdoor work in the hot season: no extra movement (MoHRE; HHS 2018 p. 92).
    if (outdoor && hot && (h.extraMovement || h.id == 'standUp')) {
      removed[h.id] = HabitFilterReason.outdoorHeat;
      continue;
    }
    // Heavy work: rest, sleep and stretching first; no extra heavy exercise (B6 axis 1).
    if (profile.activity == WorkActivity.heavy && h.heavy) {
      removed[h.id] = HabitFilterReason.heavyWork;
      continue;
    }
    // NIOSH shift-work habits only for night/rotating shifts or the shift-sleep card.
    if (h.nightShift && !night && !profile.goalIds.contains('shiftSleep')) {
      removed[h.id] = HabitFilterReason.notNightShift;
      continue;
    }

    var score = 0;
    final inArea = (h.area == HabitArea.sleep && domains.contains(Domain.sleep)) ||
        (h.area == HabitArea.movement && domains.contains(Domain.movement)) ||
        (h.area == HabitArea.calm && profile.goalIds.contains('calm'));
    if (inArea) score += 100;
    if (h.kind == HabitKind.main) score += 20;
    if (h.cards.contains(profile.mainGoalId)) score += 30;
    score += 10 * h.cards.where((c) => profile.goalIds.contains(c)).length;
    if (night && h.nightShift) score += 25;
    if (hot && h.id == 'indoorWalk') score += 15;
    // Long or split shifts: small tasks that fit in the break (B6 axis 2).
    if (profile.shift == ShiftType.longOrSplit && (h.id == 'stretch' || h.id == 'standUp')) score += 15;
    if (!hot && h.id == 'indoorWalk') score -= 15;
    switch (profile.activity) {
      case WorkActivity.sitting:
        if (h.id == 'standUp' || h.id == 'briskWalk') score += 15;
      case WorkActivity.standingLight:
        if (h.id == 'stretch' || h.id == 'briskWalk') score += 15;
      case WorkActivity.moderate:
        break;
      case WorkActivity.heavy:
        if (h.area == HabitArea.sleep || h.id == 'stretch') score += 15;
        if (h.extraMovement) score -= 20;
    }
    scored.add((h, score));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return HabitFilterResult([for (final s in scored) s.$1], removed);
}

/// C3 #15, #16, #14 (NIOSH Training for Nurses on Shift Work, module 9): the
/// night-shift sleep habits, in the order Chi's screen 11 shows them.
const kNightShiftSleepHabits = ['homeToBed', 'blackout', 'napBeforeShift'];

/// C1 step 4: three habits to choose from, the gap-closing main habit first.
/// Fixed night shift with sleep chosen: the NIOSH night-shift habits come first
/// (straight to bed, blackout, nap before the shift), then the general AASM ones.
List<Habit> suggestHabits({
  required Profile profile,
  required Set<Domain> domains,
  required DateTime today,
}) {
  final r = filterHabits(profile: profile, domains: domains, today: today);
  final allowed = r.habits;
  final out = <Habit>[];
  void add(String id) {
    if (out.length >= 3) return;
    final h = allowed.where((x) => x.id == id).firstOrNull;
    if (h != null && !out.contains(h)) out.add(h);
  }

  final night = profile.shift == ShiftType.nightFixed || profile.shift == ShiftType.rotating;
  final sleep = domains.contains(Domain.sleep);
  if (sleep) add(night ? kNightShiftSleepHabits.first : 'bedEarlier');
  if (domains.contains(Domain.movement)) {
    // Heavy work: recovery and stretching first, no extra heavy exercise (B6 axis 1).
    if (profile.activity == WorkActivity.heavy) add('stretch');
    add(isHotSeason(today) ? 'indoorWalk' : 'briskWalk');
  }
  if (sleep && profile.shift == ShiftType.nightFixed) {
    for (final id in kNightShiftSleepHabits.skip(1)) {
      add(id);
    }
  }
  for (final h in allowed) {
    if (out.length >= 3) break;
    final inArea = (h.area == HabitArea.sleep && sleep) ||
        (h.area == HabitArea.movement && domains.contains(Domain.movement)) ||
        h.area == HabitArea.calm;
    if (inArea && !out.contains(h)) out.add(h);
  }
  return out;
}
