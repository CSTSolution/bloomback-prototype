// Core tests that run on the Mac (pio test -e native) with synthetic sensor data.
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <unity.h>

#include <string>
#include <vector>

#include "export.h"
#include "motion.h"
#include "reminders.h"
#include "sleep.h"

using namespace bb;

static const float kPi = 3.14159265f;

void setUp() {}
void tearDown() {}

static float noise(float amp) { return amp * ((rand() % 2001) / 1000.0f - 1.0f); }

// Walking: vertical bounce at the step frequency on top of gravity.
static uint32_t walk(StepCounter& sc, float seconds, float stepHz, float fs, uint32_t t0) {
  uint32_t t = t0;
  int n = (int)(seconds * fs);
  for (int i = 0; i < n; i++) {
    t = t0 + (uint32_t)(i * 1000.0f / fs);
    float s = 0.30f * sinf(2 * kPi * stepHz * i / fs);
    sc.add(t, 0.1f + noise(0.02f), 0.2f + noise(0.02f), 0.97f + s + noise(0.03f));
  }
  return t;
}

void test_walking_counts_steps() {
  srand(1);
  StepCounter sc;
  walk(sc, 60, 1.8f, 25, 0);  // 60 s at 1.8 steps/s = 108 steps
  TEST_ASSERT_INT_WITHIN(6, 108, (int)sc.total());
}

void test_walking_at_10hz_sampling() {
  srand(2);
  StepCounter sc;
  walk(sc, 60, 1.7f, 10, 0);  // low-power rate still counts
  TEST_ASSERT_INT_WITHIN(8, 102, (int)sc.total());
}

void test_still_and_noise_gives_no_steps() {
  srand(3);
  StepCounter sc;
  for (int i = 0; i < 25 * 120; i++) {
    sc.add(i * 40, noise(0.03f), noise(0.03f), 1.0f + noise(0.03f));
  }
  TEST_ASSERT_EQUAL_UINT32(0, sc.total());
}

void test_isolated_arm_moves_are_not_steps() {
  StepCounter sc;
  uint32_t t = 0;
  for (int k = 0; k < 10; k++) {  // one sharp move every 5 s
    for (int i = 0; i < 125; i++, t += 40) {
      float bump = (i >= 10 && i < 14) ? 0.8f : 0.0f;
      sc.add(t, 0.0f, 0.0f, 1.0f + bump);
    }
  }
  TEST_ASSERT_EQUAL_UINT32(0, sc.total());
}

void test_angle_tracker_minute() {
  AngleTracker at;
  // 1 minute, arm rotating slowly: z-angle goes 0 -> 30 degrees.
  for (int i = 0; i <= 25 * 60; i++) {
    float ang = 30.0f * i / (25 * 60) * kPi / 180;
    at.add(i * 40, cosf(ang), 0, sinf(ang));
  }
  uint16_t med, mx;
  TEST_ASSERT_TRUE(at.takeMinute(med, mx));
  TEST_ASSERT_INT_WITHIN(40, 250, med);  // about 2.5 degrees per 5 s epoch
  TEST_ASSERT_TRUE(mx >= med);
}

// 24 h of minutes: awake (big angle changes) except a still block.
static std::vector<MinuteRec> day(uint32_t start, int sleepFrom, int sleepLen, int wakeBlip) {
  std::vector<MinuteRec> v;
  srand(4);
  for (int i = 0; i < 1440; i++) {
    MinuteRec r{start + i, 0, 0, 0, 0};
    bool asleep = i >= sleepFrom && i < sleepFrom + sleepLen;
    if (asleep) {
      r.medDiff = rand() % 5;   // < 0.05 deg
      r.maxDiff = 50 + rand() % 200;
      if (wakeBlip > 0 && i >= sleepFrom + wakeBlip && i < sleepFrom + wakeBlip + 20) {
        r.medDiff = 600;  // 20-minute wake in the middle (bathroom)
        r.maxDiff = 3000;
      }
    } else {
      r.medDiff = 200 + rand() % 2000;
      r.maxDiff = r.medDiff + 1000;
      r.steps = (i % 60 < 10) ? 110 : 5;
    }
    v.push_back(r);
  }
  return v;
}

void test_sleep_window_night() {
  uint32_t start = 29000000;  // any minute
  auto v = day(start, 900, 420, 0);  // 7 h sleep starting at minute 900
  SleepWindow s = detectMainSleep(v.data(), v.size());
  TEST_ASSERT_TRUE(s.found);
  TEST_ASSERT_INT_WITHIN(5, (int)(start + 900), (int)s.startMinute);
  TEST_ASSERT_INT_WITHIN(5, (int)(start + 1320), (int)s.endMinute);
  TEST_ASSERT_INT_WITHIN(10, 420, s.sleepMinutes);
}

void test_short_wake_is_joined() {
  uint32_t start = 29000000;
  auto v = day(start, 600, 400, 200);  // 20-min wake in the middle: one window
  SleepWindow s = detectMainSleep(v.data(), v.size());
  TEST_ASSERT_TRUE(s.found);
  TEST_ASSERT_INT_WITHIN(5, (int)(start + 600), (int)s.startMinute);
  TEST_ASSERT_INT_WITHIN(5, (int)(start + 1000), (int)s.endMinute);
  TEST_ASSERT_TRUE(s.sleepMinutes < 390);
}

void test_charging_is_not_sleep() {
  uint32_t start = 29000000;
  auto v = day(start, 900, 420, 0);
  for (int i = 900; i < 1320; i++) v[i].flags = kCharging;  // watch on the charger
  SleepWindow s = detectMainSleep(v.data(), v.size());
  TEST_ASSERT_FALSE(s.found);
}

void test_reminders() {
  ReminderCfg c;
  c.times[0] = 8 * 60;
  c.times[1] = 18 * 60;
  c.quietStart = 22 * 60;
  c.quietEnd = 6 * 60;
  TEST_ASSERT_EQUAL(0, dueReminder(8 * 60 + 5, c, 0));
  TEST_ASSERT_EQUAL(-1, dueReminder(8 * 60 + 5, c, 1));       // already sent
  TEST_ASSERT_EQUAL(-1, dueReminder(9 * 60, c, 0));           // missed: no catch-up
  TEST_ASSERT_EQUAL(1, dueReminder(18 * 60, c, 1));
  TEST_ASSERT_TRUE(inQuiet(23 * 60, c));
  TEST_ASSERT_TRUE(inQuiet(2 * 60, c));
  c.times[0] = 23 * 60;                                       // set inside quiet hours
  TEST_ASSERT_EQUAL(-1, dueReminder(23 * 60, c, 0));
  // Night-shift quiet hours in the day (Ravi): 08:00-15:00.
  c.quietStart = 8 * 60;
  c.quietEnd = 15 * 60;
  TEST_ASSERT_TRUE(inQuiet(10 * 60, c));
  TEST_ASSERT_FALSE(inQuiet(23 * 60, c));
}

struct StrWriter : Writer {
  std::string s;
  void write(const char* x) override { s += x; }
};

void test_format_local() {
  char out[40];
  // 2026-11-13 00:00 UTC = unix 1794528000 s
  formatLocal(1794528000u / 60, 7 * 60, out, sizeof out);
  TEST_ASSERT_EQUAL_STRING("2026-11-13T07:00:00+07:00", out);
  formatLocal(1794528000u / 60, 4 * 60, out, sizeof out);  // Abu Dhabi
  TEST_ASSERT_EQUAL_STRING("2026-11-13T04:00:00+04:00", out);
}

void test_exports() {
  uint32_t start = 1794528000u / 60;
  auto v = day(start, 900, 420, 0);
  DaySummary d;
  d.dayStartMinute = start;
  summarizeSteps(v.data(), v.size(), d);
  d.sleep = detectMainSleep(v.data(), v.size());
  TEST_ASSERT_TRUE(d.moderateMinutes > 100);
  Checkin c{start + 600, kPartial};
  StrWriter w;
  exportFhir(&d, 1, &c, 1, 240, "Test Band", w);
  TEST_ASSERT_NOT_NULL(strstr(w.s.c_str(), "\"55423-8\""));
  TEST_ASSERT_NOT_NULL(strstr(w.s.c_str(), "\"93832-4\""));
  TEST_ASSERT_NOT_NULL(strstr(w.s.c_str(), "\"code\":\"watch\""));
  TEST_ASSERT_NOT_NULL(strstr(w.s.c_str(), "\"partial\""));
  TEST_ASSERT_EQUAL_STRING("]}\n", w.s.c_str() + w.s.size() - 3);
  // Balanced braces = no truncated entry.
  int depth = 0;
  for (char ch : w.s) depth += (ch == '{') - (ch == '}');
  TEST_ASSERT_EQUAL(0, depth);

  StrWriter csv;
  exportCsv(v.data(), 3, 240, csv);
  TEST_ASSERT_NOT_NULL(strstr(csv.s.c_str(), "2026-11-13T04:00:00+04:00,"));
}

int main() {
  UNITY_BEGIN();
  RUN_TEST(test_walking_counts_steps);
  RUN_TEST(test_walking_at_10hz_sampling);
  RUN_TEST(test_still_and_noise_gives_no_steps);
  RUN_TEST(test_isolated_arm_moves_are_not_steps);
  RUN_TEST(test_angle_tracker_minute);
  RUN_TEST(test_sleep_window_night);
  RUN_TEST(test_short_wake_is_joined);
  RUN_TEST(test_charging_is_not_sleep);
  RUN_TEST(test_reminders);
  RUN_TEST(test_format_local);
  RUN_TEST(test_exports);
  return UNITY_END();
}
