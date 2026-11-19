// Reminder rules from BloomBack C4: at most 2 a day, never in quiet (sleep) hours,
// no catch-up nagging if one was missed.
#pragma once
#include <stdint.h>

namespace bb {

struct ReminderCfg {
  int16_t times[2] = {-1, -1};  // local minute of day (0..1439), -1 = off
  int16_t quietStart = 22 * 60; // local minute of day; may wrap past midnight
  int16_t quietEnd = 6 * 60;
};

constexpr int kReminderWindowMin = 30;  // a reminder only fires within 30 min of its time

bool inQuiet(int minuteOfDay, const ReminderCfg& cfg);

// Returns the reminder index (0 or 1) due now, or -1.
// sentMask: bit i set = reminder i already fired today.
int dueReminder(int minuteOfDay, const ReminderCfg& cfg, uint8_t sentMask);

}  // namespace bb
