// BloomBack Band: shared data types.
// Plain C++ (no Arduino), so the same code runs on the watch and in Mac tests.
#pragma once
#include <stddef.h>
#include <stdint.h>

namespace bb {

// One record per minute, kept on the watch only (12 bytes, ~17 KB a day).
struct MinuteRec {
  uint32_t minute;   // UTC unix time / 60
  uint16_t steps;    // steps counted in this minute
  uint16_t medDiff;  // median change of arm angle between 5 s epochs, centi-degrees
  uint16_t maxDiff;  // largest change of arm angle between 5 s epochs, centi-degrees
  uint16_t flags;    // see Flags
};

enum Flags : uint16_t {
  kCharging = 1,  // on the charger: not worn, never counted as sleep
};

// A minute with at least this many steps counts as moderate activity.
// Source: Tudor-Locke et al., Br J Sports Med 2018 ("How fast is fast enough?"):
// about 100 steps/min matches moderate intensity in adults.
constexpr uint16_t kModerateCadence = 100;

inline bool isModerate(const MinuteRec& r) { return r.steps >= kModerateCadence; }

}  // namespace bb
