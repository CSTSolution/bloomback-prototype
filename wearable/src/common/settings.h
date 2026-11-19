// Band settings kept in NVS (Preferences), shared by every board.
#pragma once
#include <Arduino.h>

#include "bbproto.h"
#include "reminders.h"

struct BandSettings {
  bb::ReminderCfg rem;          // times/quiet hours as the app sent them (-1 = off)
  int16_t tzMin = 7 * 60;       // set by the app with `time`
  int16_t dayEnd = 18 * 60;     // sleep for day D = main sleep in the 24 h ending D dayEnd
  String habit = "Go to bed 15 min earlier";
};

extern BandSettings cfg;

void loadSettings();
void saveSettings();

// Reminder rules to use right now: quiet hours with a -1 end are "no quiet hours".
bb::ReminderCfg activeReminders();

void settingsToProto(bbproto::Settings& s);
void settingsFromProto(const bbproto::Settings& s);
