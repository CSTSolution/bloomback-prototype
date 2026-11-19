// Main sleep period from wrist arm-angle data, adapted from the HDCZA method
// (van Hees et al. 2018, Sci Rep 8:12975) and the 5-degree / 5-minute sleep rule
// (van Hees et al. 2015, PLoS ONE 10:e0142533). It is an estimate, labelled
// "watch" as its source, and never used to diagnose anything.
#pragma once
#include "bb_types.h"

namespace bb {

struct SleepWindow {
  bool found = false;
  uint32_t startMinute = 0;  // UTC unix minute: estimated sleep onset (in bed, still)
  uint32_t endMinute = 0;    // UTC unix minute: estimated wake-up (exclusive)
  uint16_t sleepMinutes = 0; // minutes inside the window that look asleep
};

// recs must be sorted by minute. Missing minutes (watch off) break blocks.
// Looks at the whole array (callers pass the last 24 hours).
SleepWindow detectMainSleep(const MinuteRec* recs, size_t n);

}  // namespace bb
