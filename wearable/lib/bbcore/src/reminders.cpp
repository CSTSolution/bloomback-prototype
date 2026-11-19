#include "reminders.h"

namespace bb {

bool inQuiet(int m, const ReminderCfg& c) {
  if (c.quietStart == c.quietEnd) return false;
  if (c.quietStart < c.quietEnd) return m >= c.quietStart && m < c.quietEnd;
  return m >= c.quietStart || m < c.quietEnd;  // wraps past midnight
}

int dueReminder(int m, const ReminderCfg& c, uint8_t sentMask) {
  if (inQuiet(m, c)) return -1;
  for (int i = 0; i < 2; i++) {
    int t = c.times[i];
    if (t < 0 || (sentMask & (1 << i))) continue;
    int since = (m - t + 1440) % 1440;
    if (since < kReminderWindowMin) return i;
  }
  return -1;
}

}  // namespace bb
