// Rules C2 (proposal): sleep regularity. Bedtime spread (latest minus earliest
// bedtime in a week) comes down 30 min every 2 weeks until it is under 1 hour.
// BloomBack suggests each step; the user accepts or not.

const kSpreadGoal = 60; // under 1 hour (D1: compared with yourself, no official threshold)
const kSpreadUnder1h = 59; // the last target, shown as "under 1 h"
const kSpreadStep = 30; // set by BloomBack
const kSpreadStepDays = 14; // set by BloomBack
const kSpreadDeclineDays = 14; // "Not now" hides the offer this long (set by BloomBack)

const kSpreadSource =
    'CDC "About Sleep" and NHS: go to bed and get up at about the same times every day. '
    'BloomBack rules C2 (proposal) and D1: aim for a bedtime spread under 1 hour, compared with '
    'yourself (no official threshold). The step (30 min less every 2 weeks) is set by BloomBack, '
    'not from a guideline. Band numbers are compared with band numbers, your own answers with '
    'your own answers (B1).';

/// The next target below [from]: 30 min less, and "under 1 h" once that is 1 h or less.
int nextSpreadTarget(int from) {
  final n = from - kSpreadStep;
  return n <= kSpreadGoal ? kSpreadUnder1h : n;
}

class SpreadOffer {
  final int current; // measured or self-reported spread
  final int target; // suggested target for the next 2 weeks
  final bool first;
  const SpreadOffer(this.current, this.target, {this.first = false});
}

/// What to offer today, or null. [today], [targetSetDay], [declinedDay] are local day numbers.
SpreadOffer? spreadOffer({
  required int? currentSpread,
  required int? target,
  required int? targetSetDay,
  required int today,
  int? declinedDay,
}) {
  if (currentSpread == null) return null;
  if (declinedDay != null && today - declinedDay < kSpreadDeclineDays) return null;
  if (currentSpread < kSpreadGoal) return null; // already under 1 h: keep the rhythm
  if (target == null) return SpreadOffer(currentSpread, nextSpreadTarget(currentSpread), first: true);
  if (target <= kSpreadUnder1h) return null; // the last step is already set
  if (targetSetDay != null && today - targetSetDay < kSpreadStepDays) return null;
  return SpreadOffer(currentSpread, nextSpreadTarget(target));
}

/// Chi's screen 5 (14/11): the bedtime spread from work-day and day-off bedtimes (local minutes of day), the short
/// way round the clock. Rotating shifts: null, because C2 compares regularity only within the same shift type (the
/// band measures it per shift type instead).
int? spreadFromBedtimes(int workBedtime, int offBedtime, {required bool rotating}) {
  if (rotating) return null;
  final d = (workBedtime - offBedtime).abs() % 1440;
  return d > 720 ? 1440 - d : d;
}
