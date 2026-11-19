// BloomBack Band - cheap band firmware: ESP32-C3 + 0.42" OLED (72x40) + MPU6050.
// NOT yet run on real hardware (board not bought on 2026-11-13): compile-checked only.
//
// What it does (BloomBack rules in brackets):
//  - counts steps and moderate minutes, estimates the main sleep window (A1, source "watch")
//  - one-press daily check-in: Done / Partly / Not today (C4)
//  - at most 2 reminders a day, never in quiet hours (C4)
//  - keeps all data on the band; the phone app reads it over Bluetooth LE after pairing
//    with a passkey shown only on this screen. USB serial answers the same commands.
//    Protocol: docs/PROTOCOL.md (lib/bbproto). No cloud. (principle 7)
//
// One button (BOOT). Short press = next / wake, long press (0.7 s) = action:
//   Screen off:  any press wakes it
//   Home:        short = next page (time, steps, active, sleep, phone)
//                long  = check-in (on the phone page: unpair)
//   Check-in:    short = next answer, long = save
//   Reminder:    short = later, long = check-in
//   Unpair:      short = no, long = yes
#include <Arduino.h>
#include <Wire.h>
#include <esp_mac.h>
#include <esp_system.h>
#include <sys/time.h>
#include <time.h>

#include "ble.h"
#include "host.h"
#include "imu.h"
#include "motion.h"
#include "pins.h"
#include "reminders.h"
#include "settings.h"
#include "store.h"
#include "ui.h"

using namespace bb;

constexpr uint32_t kFifoReadMs = 2000;    // FIFO holds ~6.8 s at 25 Hz; read well before
constexpr uint32_t kLongPressMs = 700;
constexpr uint32_t kDebounceMs = 30;
#ifndef BB_SCREEN_ON_MS
#define BB_SCREEN_ON_MS 10000
#endif
constexpr uint32_t kScreenOnMs = BB_SCREEN_ON_MS;  // the demo board keeps its big screen on longer
constexpr uint32_t kRemindOnMs = 30000;
constexpr uint32_t kSavedMs = 1500;
constexpr uint32_t kFrameMs = 80;         // scrolling text

// ---------- state ----------
UiModel view;
bool dirty = true;
uint32_t screenSince = 0;
uint32_t lastFrameMs = 0;
char habitText[bbproto::kHabitMaxBytes + 1];

DaySummary today;
SleepWindow lastSleep;
bool needSummary = false;     // recompute today + last sleep (after time, config, delete)
uint32_t lastSleepTryMin = 0;

StepCounter steps;
AngleTracker angle;
uint32_t stepsThisMinute = 0;
uint32_t curMinute = 0;
uint32_t lastFifoMs = 0;
uint8_t remindSent = 0;
int32_t remindDay = -1;
int batteryPct = -1;

// ---------- hardware helpers ----------
bool charging() {
#ifdef BB_CHG_PIN
  return digitalRead(BB_CHG_PIN) == LOW;
#else
  return false;  // unknown: a band left on the desk can look like sleep (see README)
#endif
}

int readBattery() {
#ifdef BB_BAT_PIN
  uint32_t sum = 0;
  for (int i = 0; i < 8; i++) sum += analogReadMilliVolts(BB_BAT_PIN);
  int mv = (int)(sum / 8 * BB_BAT_DIVIDER);
  // LiPo resting voltage -> rough percent.
  static const int kMv[] = {3300, 3500, 3600, 3700, 3800, 3900, 4000, 4100, 4200};
  static const int kPct[] = {0, 5, 12, 30, 50, 65, 78, 90, 100};
  if (mv <= kMv[0]) return 0;
  for (int i = 1; i < 9; i++)
    if (mv < kMv[i]) return kPct[i - 1] + (kPct[i] - kPct[i - 1]) * (mv - kMv[i - 1]) / (kMv[i] - kMv[i - 1]);
  return 100;
#else
  return -1;
#endif
}

void vibrate() {
#ifdef BB_VIBE_PIN
  for (int i = 0; i < 2; i++) {
    digitalWrite(BB_VIBE_PIN, HIGH);
    delay(200);
    digitalWrite(BB_VIBE_PIN, LOW);
    delay(150);
  }
#endif
}

// ---------- sensing ----------
void onSample(uint32_t t, float ax, float ay, float az) {
  stepsThisMinute += steps.add(t, ax, ay, az);
  angle.add(t, ax, ay, az);
}

#ifdef BB_DEMO_STEPS
// DEMO ONLY (env cyd, until the MPU6050 is plugged in): with no motion sensor, make walking-pace steps so the
// screens, sync and app can be shown end to end. Walks 10 min at ~105 steps/min, then rests 10 min. The screen
// says "demo steps" while this runs; with a sensor present it never runs.
void demoSteps(uint32_t now) {
  static uint32_t last = 0;
  if (now - last < 2000) return;
  last = now;
  const bool walking = (now / 600000UL) % 2 == 0;
  stepsThisMinute += walking ? 3 + (now / 2000) % 2 + ((now / 6000) % 3 == 0 ? 1 : 0) : ((now / 2000) % 15 == 0 ? 1 : 0);
  dirty = true;
}
#endif

void serviceImu() {
  lastFifoMs = millis();
  if (imu::ok()) imu::drain(onSample);
#ifdef BB_DEMO_STEPS
  else demoSteps(lastFifoMs);
#endif
}

// Called during long flash reads and BLE sends so the FIFO never overflows.
void sensorTick() {
  if (millis() - lastFifoMs >= kFifoReadMs) serviceImu();
}

void discardMinute() {
  uint16_t a, b;
  angle.takeMinute(a, b);
  stepsThisMinute = 0;
}

void closeMinute(uint32_t minute) {
  MinuteRec r{};
  r.minute = minute;
  r.steps = (uint16_t)min<uint32_t>(stepsThisMinute, 65535);
  angle.takeMinute(r.medDiff, r.maxDiff);
  r.flags = charging() ? kCharging : 0;
  stepsThisMinute = 0;
  pending.push_back(r);
  today.steps += r.steps;
  if (isModerate(r)) today.moderateMinutes++;
  if (pending.size() >= 10) flushPending();
}

// ---------- clock (no RTC: only the app sets it) ----------
void setClock(uint32_t utc) {
  timeval tv = {(time_t)utc, 0};
  settimeofday(&tv, nullptr);
  uint32_t m = nowMinute();
  if (!clockValid || curMinute == 0 || (m > curMinute ? m - curMinute : curMinute - m) > 1) {
    discardMinute();  // the minute in progress has no trustworthy time
    curMinute = m;
  }
  clockValid = true;
}

// ---------- protocol host ----------
// A time/config/sync command just ran: big screens show "Syncing" for a moment.
void linkActivity() {
  view.syncMs = millis() | 1;
  dirty = true;
}

struct C3Host : StoreHost {
  int battery() override { return batteryPct; }
  void setTime(uint32_t utc, int16_t tz) override {
    cfg.tzMin = tz;
    saveSettings();
    setClock(utc);
    needSummary = true;
    linkActivity();
  }
  void visitMinutes(uint32_t since, bbproto::RecordVisitor& v) override {
    linkActivity();
    StoreHost::visitMinutes(since, v);
  }

 protected:
  void onSettingsChanged() override {
    needSummary = true;
    linkActivity();
  }
  void onDeleted() override { needSummary = true; }
};

C3Host host;

struct SerialWriter : Writer {
  void write(const char* s) override { Serial.print(s); }
};
SerialWriter serialWriter;
bbproto::LineReader serialReader;

// USB lines go to the protocol, except "screen" (demo mirror, USB only: its answer is longer than a BLE line).
char usbLine[bbproto::kMaxLine + 2];
size_t usbLen = 0;

#ifdef BB_TOUCH
void refreshView();
// USB-only helpers for the touch-screen demo board, used to test and to take screenshots without a pen:
//   tap <x> <y>                     a tap at screen pixel x,y
//   touchcal                        start the 4-corner touch setup
//   owner <first name>              demo greeting on the screen ("Welcome, Chi"); `owner` alone clears it
//   preview <screen> <page> <choice>  draw that screen once (finished animations) and print it like `screen`
//   frame <screen> <page> <choice> <t_ms> [sync_age_ms]   one frame of a recording (tools/cydvideo.py)
//   baud <115200|460800|921600>     USB speed for recordings
bool usbDemoCommand(char* line, size_t n) {
  const char keep = line[n];  // the line end: put it back if the line is not ours (the protocol needs it)
  line[n] = '\0';
  int a = 0, b = 0, c = 0;
  if (sscanf(line, "tap %d %d", &a, &b) == 2) {
    ui::injectTap(a, b);
    Serial.println("OK tap");
    return true;
  }
  if (strcmp(line, "touchcal") == 0) {
    ui::recalibrate();
    dirty = true;
    Serial.println("OK touchcal");
    return true;
  }
  if (strncmp(line, "owner", 5) == 0 && (line[5] == ' ' || line[5] == '\0')) {
    // Demo preset: a first name for the greeting. Kept on this board only; the protocol never carries it.
    ui::setOwner(line[5] ? line + 6 : "");
    dirty = true;
    Serial.println("OK owner");
    return true;
  }
  int t = 0, sync = -1;
  if (sscanf(line, "frame %d %d %d %d %d", &a, &b, &c, &t, &sync) >= 4) {
    // One frame of a screen recording: screen a (0 = boot splash), page b, choice c, t ms after it opened.
    refreshView();
    UiModel m = view;
    m.screen = (Screen)constrain(a, 0, 6);
    m.page = constrain(b, 0, kPageCount - 1);
    m.choice = constrain(c, 0, 2);
    m.passkey = 123456;
    if (m.screen == Screen::Saved) m.message = "Saved";
    ui::drawAt(m, (uint32_t)max(t, 0), sync);
    ui::dumpScreen();
    dirty = true;
    return true;
  }
  if (sscanf(line, "baud %d", &a) == 1 && (a == 115200 || a == 460800 || a == 921600)) {
    Serial.println("OK baud");  // faster USB for recordings; a reset goes back to 115200
    Serial.flush();
    Serial.updateBaudRate(a);
    return true;
  }
  if (sscanf(line, "preview %d %d %d", &a, &b, &c) >= 1) {
    refreshView();
    UiModel m = view;
    m.screen = (Screen)constrain(a, 1, 6);
    m.page = constrain(b, 0, kPageCount - 1);
    m.choice = constrain(c, 0, 2);
    m.passkey = 123456;
    if (m.screen == Screen::Saved) m.message = "Saved";
    const uint32_t ms = millis();
    ui::draw(m, ms);
    ui::settle();
    ui::draw(m, ms);
    ui::dumpScreen();
    dirty = true;
    return true;
  }
  line[n] = keep;
  return false;
}
#endif

void pollSerial() {
  while (Serial.available()) {
    char c = (char)Serial.read();
    if (usbLen < sizeof usbLine) usbLine[usbLen++] = c;
    if (c != '\n' && usbLen < sizeof usbLine) continue;
    size_t n = usbLen;
    while (n && (usbLine[n - 1] == '\n' || usbLine[n - 1] == '\r')) n--;
    if (n == 6 && memcmp(usbLine, "screen", 6) == 0) {
      ui::dumpScreen();
#ifdef BB_TOUCH
    } else if (n < sizeof usbLine && usbDemoCommand(usbLine, n)) {
      // tap / touchcal / preview: handled
#endif
    } else {
      serialReader.feed(usbLine, usbLen, host, serialWriter);
    }
    usbLen = 0;
  }
}

// ---------- screen ----------
void show(Screen s) {
  if (view.screen == Screen::Off && s != Screen::Off) ui::power(true);
  if (s == Screen::Off) ui::power(false);
  view.screen = s;
  screenSince = millis();
  dirty = true;
}

void refreshView() {
  view.timeValid = clockValid;
  view.nowMod = clockValid ? minuteOfDay(nowMinute()) : 0;
  view.steps = today.steps + stepsThisMinute;  // live, not only at the end of each minute
  view.active = today.moderateMinutes;
  view.sleepFound = lastSleep.found;
  view.sleepStartMod = minuteOfDay(lastSleep.startMinute);
  view.sleepEndMod = minuteOfDay(lastSleep.endMinute);
  view.sleepMinutes = lastSleep.sleepMinutes;
  view.battery = batteryPct;
  view.bleConnected = ble::connected();
  view.bleSecure = ble::secure();
  view.bonds = ble::bondCount();
  view.passkey = ble::passkey();
  strncpy(habitText, cfg.habit.c_str(), sizeof habitText - 1);
  habitText[sizeof habitText - 1] = '\0';
  bbproto::cleanUtf8(habitText, bbproto::kHabitMaxChars);
  view.habit = habitText;
  view.imuOk = imu::ok();
#ifdef BB_DEMO_STEPS
  view.demoSteps = !view.imuOk;
  // DEMO ONLY, on the screen only (nothing is stored or synced): with no motion sensor there can be no
  // sleep estimate, so show a sample night next to the DEMO tag. A real estimate replaces it.
  if (view.demoSteps && !view.sleepFound && clockValid) {
    view.sleepFound = true;
    view.sleepStartMod = 23 * 60 + 20;
    view.sleepEndMod = 6 * 60 + 5;
    view.sleepMinutes = 385;
  }
#endif
}

void saved(const char* msg) {
  view.message = msg;
  show(Screen::Saved);
}

// ---------- button ----------
bool btnDown = false;
bool longFired = false;
uint32_t btnSince = 0;

void onShort() {
  switch (view.screen) {
    case Screen::Off:
      view.page = kPageTime;
      show(Screen::Home);
      break;
    case Screen::Home:
      view.page = (view.page + 1) % kPageCount;
      show(Screen::Home);
      break;
    case Screen::Checkin:
      view.choice = (view.choice + 1) % 3;
      show(Screen::Checkin);
      break;
    case Screen::Remind:
    case Screen::Saved:
      show(Screen::Home);
      break;
    case Screen::Unpair:
      view.page = kPagePhone;
      show(Screen::Home);
      break;
    case Screen::Pairing:
      break;  // the code stays until the phone finishes or gives up
  }
}

void onLong() {
  switch (view.screen) {
    case Screen::Off:
      view.page = kPageTime;
      show(Screen::Home);
      break;
    case Screen::Home:
      if (view.page == kPagePhone) {
        if (ble::bondCount() > 0 || ble::connected()) show(Screen::Unpair);
      } else {
        view.choice = 0;
        show(Screen::Checkin);
      }
      break;
    case Screen::Remind:
      view.choice = 0;
      show(Screen::Checkin);
      break;
    case Screen::Checkin:
      if (clockValid) {
        addCheckin(nowMinute(), (uint8_t)view.choice);
        saved("Saved");
      } else {
        saved("Time not set");  // nothing is recorded before the app sets the clock
      }
      break;
    case Screen::Unpair:
      ble::unpairAll();
      saved("Unpaired");
      break;
    case Screen::Saved:
    case Screen::Pairing:
      break;
  }
}

void pollButton(uint32_t ms) {
  bool down = digitalRead(BB_BTN) == LOW;
  if (down && !btnDown) {
    btnDown = true;
    longFired = false;
    btnSince = ms;
  } else if (down && !longFired && ms - btnSince >= kLongPressMs) {
    longFired = true;
    onLong();
  } else if (!down && btnDown) {
    btnDown = false;
    if (!longFired && ms - btnSince >= kDebounceMs) onShort();
  }
}

#ifdef BB_TOUCH
// Pen taps on boards with a touch screen (env cyd). The screen code says what was tapped; the state
// changes are the same ones the button makes.
void pollTouch(uint32_t ms) {
  const ui::Tap t = ui::pollTap(view, ms);
  switch (t.kind) {
    case ui::TapKind::None:
      return;
    case ui::TapKind::Wake:
      view.page = kPageTime;
      show(Screen::Home);
      break;
    case ui::TapKind::Short:
      onShort();
      break;
    case ui::TapKind::Long:
      onLong();
      break;
    case ui::TapKind::Page:
      view.page = constrain(t.arg, 0, kPageCount - 1);
      show(Screen::Home);
      break;
    case ui::TapKind::Checkin:
      view.choice = 0;
      show(Screen::Checkin);
      break;
    case ui::TapKind::Choice:
      view.choice = constrain(t.arg, 0, 2);
      show(Screen::Checkin);
      break;
    case ui::TapKind::Back:
      show(Screen::Home);
      break;
    case ui::TapKind::Touch:
      if (view.screen != Screen::Off) screenSince = ms;  // any touch keeps the screen on
      dirty = true;
      break;
  }
}
#endif

// ---------- main ----------
void setup() {
  setCpuFrequencyMhz(80);  // lowest speed that keeps Bluetooth LE running
  setenv("TZ", "UTC0", 1);
  tzset();
  Serial.begin(115200);
  pinMode(BB_BTN, INPUT_PULLUP);
#ifdef BB_VIBE_PIN
  pinMode(BB_VIBE_PIN, OUTPUT);
  digitalWrite(BB_VIBE_PIN, LOW);
#endif
#ifdef BB_CHG_PIN
  pinMode(BB_CHG_PIN, INPUT_PULLUP);
#endif
#ifdef BB_BAT_PIN
  analogReadResolution(12);  // default attenuation reads up to ~2.5-3.1 V on the C3
#endif

  Wire.begin(BB_SDA, BB_SCL, BB_I2C_HZ);
  ui::begin();
  if (!imu::begin()) Serial.println("MPU6050 not found on I2C");

  storeBegin();
  loadSettings();
  storeTick = sensorTick;
  batteryPct = readBattery();

  // No battery-backed clock: after power-on the time is unknown until the app sends
  // `time`. After a software reset or crash the ESP32 keeps counting, so keep that.
  esp_reset_reason_t why = esp_reset_reason();
  if (why != ESP_RST_POWERON && why != ESP_RST_BROWNOUT && why != ESP_RST_UNKNOWN &&
      time(nullptr) > (time_t)bbproto::kMinValidUtc) {
    clockValid = true;
    curMinute = nowMinute();
    needSummary = true;
  }

  uint8_t mac[6];
  esp_read_mac(mac, ESP_MAC_BT);
  char name[20];
  snprintf(name, sizeof name, "BloomBack-%02X%02X", mac[4], mac[5]);
  ble::begin(name, sensorTick);
  Serial.printf("%s %s fw %s\n", name, BB_BOARD, bbproto::kFirmwareVersion);

  view.screen = Screen::Off;
  show(Screen::Home);
  lastFifoMs = millis();
}

void loop() {
  uint32_t ms = millis();
  pollButton(ms);
#ifdef BB_TOUCH
  pollTouch(ms);
#endif

  if (ms - lastFifoMs >= kFifoReadMs) serviceImu();

  if (clockValid && needSummary) {
    needSummary = false;
    flushPending();
    int32_t day = localDay(nowMinute());
    pruneOldDays(day);
    today = summarize(day);
    lastSleep = today.sleep;
    lastSleepTryMin = nowMinute();
    dirty = true;
  }

  if (clockValid) {
    uint32_t m = nowMinute();
    if (m != curMinute) {
      serviceImu();  // samples up to now belong to the closing minute
      int32_t oldDay = localDay(curMinute);
      closeMinute(curMinute);
      curMinute = m;
      int32_t day = localDay(m);
      if (day != oldDay) {  // new local day
        flushPending();
        pruneOldDays(day);
        today = summarize(day);
      }
      if (minuteOfDay(m) == cfg.dayEnd || (!lastSleep.found && m - lastSleepTryMin >= 30)) {
        flushPending();
        lastSleep = summarize(day).sleep;
        lastSleepTryMin = m;
      }
      if (day != remindDay) {
        remindDay = day;
        remindSent = 0;
      }
      int r = dueReminder(minuteOfDay(m), activeReminders(), remindSent);
      if (r >= 0 && view.screen != Screen::Pairing) {
        remindSent |= (uint8_t)(1 << r);
        show(Screen::Remind);
        vibrate();
      }
      batteryPct = readBattery();
      dirty = true;
    }
  } else {
    discardMinute();  // clock not set: nothing is recorded
  }

  pollSerial();
  ble::poll(host);

  // Pairing: show the passkey big until the phone is done.
  if (ble::pairing() && view.screen != Screen::Pairing) {
    show(Screen::Pairing);
  } else if (!ble::pairing() && view.screen == Screen::Pairing) {
    saved(ble::secure() ? "Paired" : "Not paired");
  }
  static bool wasSecure = false;
  if (ble::secure() != wasSecure) {
    wasSecure = ble::secure();
    dirty = true;
  }

  // Screen timeouts.
  ms = millis();
  uint32_t on = ms - screenSince;
  switch (view.screen) {
    case Screen::Home:
    case Screen::Checkin:
    case Screen::Unpair:
      if (on > kScreenOnMs) show(Screen::Off);
      break;
    case Screen::Remind:
      if (on > kRemindOnMs) show(Screen::Off);
      break;
    case Screen::Saved:
      if (on > kSavedMs) show(Screen::Home);
      break;
    case Screen::Pairing:
    case Screen::Off:
      break;
  }

  if (view.screen != Screen::Off) {
    bool frame = ui::animated(view) && ms - lastFrameMs >= kFrameMs;
    if (dirty || frame) {
      refreshView();
      ui::draw(view, ms);
      lastFrameMs = ms;
      dirty = false;
    }
  }

  // No light sleep yet (see README "Power"): the Arduino core is built without
  // power management, so Bluetooth advertising would stop. The idle task waits for
  // interrupts between ticks.
  delay(view.screen == Screen::Off && !btnDown ? 40 : 15);
}
