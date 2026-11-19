// 0.42" OLED (72x40) screens for the ESP32-C3 band.
#pragma once
#include <stdint.h>

enum class Screen { Off, Home, Checkin, Saved, Remind, Pairing, Unpair };
enum Page { kPageTime, kPageSteps, kPageActive, kPageSleep, kPagePhone, kPageCount };

struct UiModel {
  Screen screen = Screen::Home;
  int page = kPageTime;
  int choice = 0;              // check-in answer: 0 done, 1 partly, 2 not today
  bool timeValid = false;
  int nowMod = 0;              // local minute of the day
  uint32_t steps = 0;
  uint16_t active = 0;         // minutes with >= 100 steps today
  bool sleepFound = false;
  int sleepStartMod = 0, sleepEndMod = 0;
  uint16_t sleepMinutes = 0;
  int battery = -1;
  bool bleConnected = false, bleSecure = false;
  int bonds = 0;
  uint32_t passkey = 0;
  const char* habit = "";
  const char* message = "";    // Saved screen text
  bool imuOk = true;
  bool demoSteps = false;      // env cyd without a sensor: steps are simulated (shown on screen)
  uint32_t syncMs = 0;         // millis() of the last time/config/sync command (0 = none yet): "Syncing" on big screens
};

namespace ui {
bool begin();             // Wire must already be started
void draw(const UiModel& m, uint32_t ms);
void power(bool on);
bool animated(const UiModel& m);  // true if the screen scrolls text (redraw often)
void dumpScreen();        // USB demo mirror: prints the frame buffer as one SCREEN line

#ifdef BB_TOUCH
// Boards with a touch screen (env cyd). The screen code knows what is where, so it turns a pen tap into
// one of these; main.cpp acts on it with the same state changes as the button.
enum class TapKind : uint8_t { None, Wake, Touch, Short, Long, Page, Checkin, Choice, Back };
struct Tap {
  TapKind kind = TapKind::None;
  int arg = 0;  // Page: which page; Choice: which answer
};
Tap pollTap(const UiModel& m, uint32_t ms);  // reads the panel; at most one Tap per pen-down
void injectTap(int x, int y);                // USB test command `tap x y` (screen pixels)
void recalibrate();                          // USB command `touchcal`: start the 4-corner touch setup
void settle();                               // finish running animations (for `preview` screenshots)
void setOwner(const char* name);             // USB command `owner <name>`: demo greeting ("Welcome, Chi"); "" clears
// USB command `frame`: draw screen m as it looks t ms after it opened (Screen::Off = the boot splash), with
// the "Syncing" strip syncAge ms old (-1 = none). For frame-by-frame screen recordings (tools/cydvideo.py).
void drawAt(const UiModel& m, uint32_t t, int32_t syncAge);
#endif
}  // namespace ui
