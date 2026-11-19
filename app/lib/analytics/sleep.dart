// Main sleep period from wrist arm-angle data: a faithful Dart port of
// wearable/lib/bbcore/src/sleep.cpp. Keep the two in step.
//
// Adapted from the HDCZA method (van Hees et al. 2018, Sci Rep 8:12975) and the
// 5-degree / 5-minute sleep rule (van Hees et al. 2015, PLoS ONE 10:e0142533).
// It is an estimate, labelled "watch" as its source, and never used to diagnose.
import '../data/models.dart';

class SleepWindow {
  final bool found;
  final int startMinute; // UTC unix minute: estimated sleep onset
  final int endMinute; // UTC unix minute: estimated wake-up (exclusive)
  final int sleepMinutes; // minutes inside the window that look asleep

  const SleepWindow({
    this.found = false,
    this.startMinute = 0,
    this.endMinute = 0,
    this.sleepMinutes = 0,
  });

  static const none = SleepWindow();
}

const _kRollingMin = 5; // rolling median width (minutes)
const _kPercentile = 10; // HDCZA: 10th percentile ...
const _kMultiplier = 15; // ... times 15
const _kThrMin = 13; // clamp, centi-degrees (0.13 deg) - our choice
const _kThrMax = 50; // clamp, centi-degrees (0.50 deg) - our choice
const _kMinBlock = 30; // HDCZA: blocks longer than 30 min
const _kMaxGap = 60; // HDCZA: join blocks less than 60 min apart
const _kSleepAngle = 500; // 5 degrees, centi-degrees
const _kSleepRun = 5; // ... held for at least 5 minutes

/// [recs] must be sorted by minute. Missing minutes (band off) break blocks.
/// Looks at the whole list (callers pass the 24 hours ending at the day end).
SleepWindow detectMainSleep(List<MinuteRec> recs) {
  final n = recs.length;
  if (n < _kMinBlock) return SleepWindow.none;

  // 1. Rolling 5-minute median of the per-minute angle change.
  final roll = List<int>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final lo = i >= 2 ? i - 2 : 0;
    final hi = (i + 2) < n - 1 ? i + 2 : n - 1;
    final w = <int>[for (var j = lo; j <= hi; j++) recs[j].medDiff]..sort();
    assert(w.length <= _kRollingMin);
    roll[i] = w[w.length ~/ 2];
  }

  // 2. Threshold: 10th percentile x 15, clamped.
  final sorted = List<int>.of(roll)..sort();
  var thr = sorted[(sorted.length * _kPercentile) ~/ 100] * _kMultiplier;
  if (thr < _kThrMin) thr = _kThrMin;
  if (thr > _kThrMax) thr = _kThrMax;

  // 3. Blocks of consecutive, worn, below-threshold minutes longer than 30 min.
  final blocks = <(int, int)>[]; // [a, b) indexes
  var i = 0;
  while (i < n) {
    final ok = roll[i] < thr && !recs[i].isCharging;
    if (!ok) {
      i++;
      continue;
    }
    final a = i;
    i++;
    while (i < n &&
        roll[i] < thr &&
        !recs[i].isCharging &&
        recs[i].minute == recs[i - 1].minute + 1) {
      i++;
    }
    if (i - a > _kMinBlock) blocks.add((a, i));
  }
  if (blocks.isEmpty) return SleepWindow.none;

  // 4. Join blocks whose gap is under 60 minutes (by clock time).
  final joined = <(int, int)>[blocks.first];
  for (var k = 1; k < blocks.length; k++) {
    final last = joined.last;
    final gap = recs[blocks[k].$1].minute - recs[last.$2 - 1].minute - 1;
    if (gap < _kMaxGap) {
      joined[joined.length - 1] = (last.$1, blocks[k].$2);
    } else {
      joined.add(blocks[k]);
    }
  }

  // 5. Longest joined block is the main sleep period.
  var best = joined.first;
  for (final b in joined) {
    final len = recs[b.$2 - 1].minute - recs[b.$1].minute;
    final bestLen = recs[best.$2 - 1].minute - recs[best.$1].minute;
    if (len > bestLen) best = b;
  }

  // 6. Sleep minutes inside the window: no arm-angle change over 5 deg for >= 5 min.
  var run = 0;
  var sleepMin = 0;
  for (var k = best.$1; k < best.$2; k++) {
    final still = recs[k].maxDiff <= _kSleepAngle && !recs[k].isCharging;
    if (k > best.$1 && recs[k].minute != recs[k - 1].minute + 1) run = 0;
    if (still) {
      run++;
      if (run == _kSleepRun) {
        sleepMin += _kSleepRun;
      } else if (run > _kSleepRun) {
        sleepMin++;
      }
    } else {
      run = 0;
    }
  }
  return SleepWindow(
    found: true,
    startMinute: recs[best.$1].minute,
    endMinute: recs[best.$2 - 1].minute + 1,
    sleepMinutes: sleepMin,
  );
}
