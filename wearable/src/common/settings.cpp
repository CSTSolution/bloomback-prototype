#include "settings.h"

#include <Preferences.h>

BandSettings cfg;

static Preferences prefs;

void loadSettings() {
  prefs.begin("bb", true);
  cfg.rem.times[0] = prefs.getShort("r1", 8 * 60);
  cfg.rem.times[1] = prefs.getShort("r2", 20 * 60);
  cfg.rem.quietStart = prefs.getShort("qs", 22 * 60);
  cfg.rem.quietEnd = prefs.getShort("qe", 6 * 60);
  cfg.tzMin = prefs.getShort("tz", 7 * 60);
  cfg.dayEnd = prefs.getShort("de", 18 * 60);
  cfg.habit = prefs.getString("habit", cfg.habit);
  prefs.end();
}

void saveSettings() {
  prefs.begin("bb", false);
  prefs.putShort("r1", cfg.rem.times[0]);
  prefs.putShort("r2", cfg.rem.times[1]);
  prefs.putShort("qs", cfg.rem.quietStart);
  prefs.putShort("qe", cfg.rem.quietEnd);
  prefs.putShort("tz", cfg.tzMin);
  prefs.putShort("de", cfg.dayEnd);
  prefs.putString("habit", cfg.habit);
  prefs.end();
}

bb::ReminderCfg activeReminders() {
  bb::ReminderCfg r = cfg.rem;
  if (r.quietStart < 0 || r.quietEnd < 0) r.quietStart = r.quietEnd = 0;  // equal = no quiet
  return r;
}

void settingsToProto(bbproto::Settings& s) {
  s.r1 = cfg.rem.times[0];
  s.r2 = cfg.rem.times[1];
  s.qs = cfg.rem.quietStart;
  s.qe = cfg.rem.quietEnd;
  s.de = cfg.dayEnd;
  s.tz = cfg.tzMin;
  strncpy(s.habit, cfg.habit.c_str(), sizeof s.habit - 1);
  s.habit[sizeof s.habit - 1] = '\0';
  bbproto::cleanUtf8(s.habit, bbproto::kHabitMaxChars);
}

void settingsFromProto(const bbproto::Settings& s) {
  cfg.rem.times[0] = s.r1;
  cfg.rem.times[1] = s.r2;
  cfg.rem.quietStart = s.qs;
  cfg.rem.quietEnd = s.qe;
  cfg.dayEnd = s.de;
  cfg.tzMin = s.tz;
  cfg.habit = s.habit;
}
