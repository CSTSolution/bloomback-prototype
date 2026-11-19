#include "sleep.h"

#include <algorithm>
#include <vector>

namespace bb {

namespace {
constexpr int kRollingMin = 5;        // rolling median width (minutes)
constexpr int kPercentile = 10;       // HDCZA: 10th percentile ...
constexpr int kMultiplier = 15;       // ... times 15
constexpr uint16_t kThrMin = 13;      // clamp, centi-degrees (0.13 deg) - our choice
constexpr uint16_t kThrMax = 50;      // clamp, centi-degrees (0.50 deg) - our choice
constexpr int kMinBlock = 30;         // HDCZA: blocks longer than 30 min
constexpr int kMaxGap = 60;           // HDCZA: join blocks less than 60 min apart
constexpr uint16_t kSleepAngle = 500; // 5 degrees, centi-degrees
constexpr int kSleepRun = 5;          // ... held for at least 5 minutes
}  // namespace

SleepWindow detectMainSleep(const MinuteRec* recs, size_t n) {
  SleepWindow out;
  if (n < (size_t)kMinBlock) return out;

  // 1. Rolling 5-minute median of the per-minute angle change.
  std::vector<uint16_t> roll(n);
  for (size_t i = 0; i < n; i++) {
    size_t lo = i >= 2 ? i - 2 : 0;
    size_t hi = std::min(n - 1, i + 2);
    uint16_t w[kRollingMin];
    int k = 0;
    for (size_t j = lo; j <= hi; j++) w[k++] = recs[j].medDiff;
    std::sort(w, w + k);
    roll[i] = w[k / 2];
  }

  // 2. Threshold: 10th percentile x 15, clamped.
  std::vector<uint16_t> sorted(roll);
  std::sort(sorted.begin(), sorted.end());
  uint32_t thr = (uint32_t)sorted[(sorted.size() * kPercentile) / 100] * kMultiplier;
  if (thr < kThrMin) thr = kThrMin;
  if (thr > kThrMax) thr = kThrMax;

  // 3. Blocks of consecutive, worn, below-threshold minutes longer than 30 min.
  struct Block { size_t a, b; };  // [a, b) indexes
  std::vector<Block> blocks;
  size_t i = 0;
  while (i < n) {
    bool ok = roll[i] < thr && !(recs[i].flags & kCharging);
    if (!ok) { i++; continue; }
    size_t a = i;
    i++;
    while (i < n && roll[i] < thr && !(recs[i].flags & kCharging) &&
           recs[i].minute == recs[i - 1].minute + 1) {
      i++;
    }
    if ((int)(i - a) > kMinBlock) blocks.push_back({a, i});
  }
  if (blocks.empty()) return out;

  // 4. Join blocks whose gap is under 60 minutes (by clock time).
  std::vector<Block> joined;
  joined.push_back(blocks[0]);
  for (size_t k = 1; k < blocks.size(); k++) {
    Block& last = joined.back();
    uint32_t gap = recs[blocks[k].a].minute - recs[last.b - 1].minute - 1;
    if ((int)gap < kMaxGap) {
      last.b = blocks[k].b;
    } else {
      joined.push_back(blocks[k]);
    }
  }

  // 5. Longest joined block is the main sleep period.
  Block best = joined[0];
  for (const Block& b : joined) {
    uint32_t len = recs[b.b - 1].minute - recs[b.a].minute;
    uint32_t bestLen = recs[best.b - 1].minute - recs[best.a].minute;
    if (len > bestLen) best = b;
  }
  out.found = true;
  out.startMinute = recs[best.a].minute;
  out.endMinute = recs[best.b - 1].minute + 1;

  // 6. Sleep minutes inside the window: no arm-angle change over 5 deg for >= 5 min.
  int run = 0;
  uint16_t sleepMin = 0;
  for (size_t k = best.a; k < best.b; k++) {
    bool still = recs[k].maxDiff <= kSleepAngle && !(recs[k].flags & kCharging);
    if (k > best.a && recs[k].minute != recs[k - 1].minute + 1) run = 0;
    if (still) {
      run++;
      if (run == kSleepRun) sleepMin += kSleepRun;
      else if (run > kSleepRun) sleepMin++;
    } else {
      run = 0;
    }
  }
  out.sleepMinutes = sleepMin;
  return out;
}

}  // namespace bb
