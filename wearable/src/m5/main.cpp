// BloomBack Band - firmware for M5StickC Plus2 (ESP32 + 1.14" screen + IMU + RTC + buzzer).
//
// What it does (BloomBack rules in brackets):
//  - counts steps and moderate minutes, estimates the main sleep window (A1 habits, source "watch")
//  - one-tap daily check-in: Done / Partly / Not today (C4)
//  - at most 2 reminders a day, never in quiet hours (C4)
//  - keeps all data on the watch; the user downloads it over the watch's own Wi-Fi,
//    protected by a password shown only on the watch screen. No cloud. (principle 7)
//  - USB serial speaks the band protocol (docs/PROTOCOL.md, lib/bbproto): info, time,
//    config, sync, export json|csv, delete yes. (BLE is only on the ESP32-C3 band.)
//
// Buttons: A = big front button, B = right side button.
//   Screen off: A or B wakes it.
//   Home:   A = check-in      B = next page      hold B = share (download)
//   Check-in: B = change answer, A = save
//   Share:  hold B = stop sharing
#include <LittleFS.h>
#include <M5Unified.h>
#include <Preferences.h>
#include <WebServer.h>
#include <WiFi.h>
#include <sys/time.h>
#include <time.h>

#include <algorithm>
#include <vector>

#include "bbproto.h"
#include "export.h"
#include "host.h"
#include "motion.h"
#include "reminders.h"
#include "settings.h"
#include "sleep.h"
#include "store.h"

using namespace bb;

// Settings (NVS), the clock helpers and the minute files are in src/common/.

// ---------- time ----------
bool timeValid() { return clockValid; }

void systemTimeFromRtc() {
  auto dt = M5.Rtc.getDateTime();
  tm t = {};
  t.tm_year = dt.date.year - 1900;
  t.tm_mon = dt.date.month - 1;
  t.tm_mday = dt.date.date;
  t.tm_hour = dt.time.hours;
  t.tm_min = dt.time.minutes;
  t.tm_sec = dt.time.seconds;
  time_t epoch = mktime(&t);  // TZ is UTC0, so this is UTC
  timeval tv = {epoch, 0};
  settimeofday(&tv, nullptr);
  clockValid = time(nullptr) > (time_t)bbproto::kMinValidUtc;
}

void setClock(time_t utc) {
  timeval tv = {utc, 0};
  settimeofday(&tv, nullptr);
  M5.Rtc.setDateTime(gmtime(&utc));
  clockValid = true;
}

// ---------- live numbers for the screen ----------
DaySummary today;
SleepWindow lastSleep;
bool needSummary = false;  // recompute today/lastSleep (after time, config or delete)

// ---------- sensing ----------
StepCounter steps;
AngleTracker angle;
uint32_t stepsThisMinute = 0;
uint32_t curMinute = 0;
uint32_t lastSampleMs = 0;
const uint32_t kSampleMs = 40;  // 25 Hz

bool charging() {
  return M5.Power.isCharging() == m5::Power_Class::is_charging_t::is_charging;
}

void sampleImu() {
  float ax, ay, az;
  if (!M5.Imu.getAccel(&ax, &ay, &az)) return;
  uint32_t t = millis();
  stepsThisMinute += steps.add(t, ax, ay, az);
  angle.add(t, ax, ay, az);
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

// ---------- screen + UI ----------
enum class Ui { Off, Home, Checkin, Share, Remind };
Ui ui = Ui::Home;
int homePage = 0;
int checkinChoice = 0;
uint32_t uiSince = 0;
uint8_t remindSent = 0;
int32_t remindDay = -1;

WebServer server(80);
bool sharing = false;
String apSsid, apPass;

const char* kChoice[] = {"Done", "Partly", "Not today"};

void screenOn() {
  M5.Display.wakeup();
  M5.Display.setBrightness(80);
  uiSince = millis();
}

void screenOff() {
  M5.Display.setBrightness(0);
  M5.Display.sleep();
  ui = Ui::Off;
}

void hhmm(uint32_t utcMin, char* out) {
  int m = minuteOfDay(utcMin);
  sprintf(out, "%02d:%02d", m / 60, m % 60);
}

void draw() {
  auto& d = M5.Display;
  d.startWrite();
  d.fillScreen(TFT_BLACK);
  d.setTextColor(TFT_WHITE, TFT_BLACK);
  d.setTextSize(2);
  d.setCursor(6, 6);
  char a[8], b[8];
  switch (ui) {
    case Ui::Home:
      if (!timeValid()) {
        d.println("BloomBack");
        d.setTextSize(1);
        d.println("\n Time not set.");
        d.println(" Hold B to share, then open");
        d.println(" http://192.168.4.1 on a phone.");
        break;
      }
      hhmm(nowMinute(), a);
      d.printf("%s  %d%%\n", a, M5.Power.getBatteryLevel());
      d.setTextSize(2);
      if (homePage == 0) {
        d.printf(" Steps %lu\n", (unsigned long)today.steps);
        d.printf(" Active %u min\n", today.moderateMinutes);
      } else {
        if (lastSleep.found) {
          hhmm(lastSleep.startMinute, a);
          hhmm(lastSleep.endMinute, b);
          d.printf(" Sleep %s-%s\n", a, b);
          d.printf(" ~%uh%02u asleep\n", lastSleep.sleepMinutes / 60, lastSleep.sleepMinutes % 60);
        } else {
          d.println(" Sleep: no data");
        }
      }
      d.setTextSize(1);
      d.setCursor(6, 120);
      d.print("A check-in  B next  hold B share");
      break;
    case Ui::Checkin:
    case Ui::Remind:
      d.setTextSize(1);
      d.println(ui == Ui::Remind ? "Reminder" : "Today's habit");
      d.setTextSize(2);
      d.println(cfg.habit);
      d.println();
      if (ui == Ui::Checkin) {
        d.setTextColor(TFT_GREENYELLOW, TFT_BLACK);
        d.printf("> %s\n", kChoice[checkinChoice]);
        d.setTextColor(TFT_WHITE, TFT_BLACK);
        d.setTextSize(1);
        d.setCursor(6, 120);
        d.print("B change   A save");
      } else {
        d.setTextSize(1);
        d.setCursor(6, 120);
        d.print("A check-in   B later");
      }
      break;
    case Ui::Share:
      d.println("Download");
      d.setTextSize(1);
      d.printf("\n Wi-Fi: %s\n", apSsid.c_str());
      d.setTextSize(2);
      d.printf(" Pass: %s\n", apPass.c_str());
      d.setTextSize(1);
      d.println("\n Open http://192.168.4.1");
      d.setCursor(6, 120);
      d.print("hold B to stop");
      break;
    case Ui::Off:
      break;
  }
  d.endWrite();
}

// ---------- download over the watch's own Wi-Fi ----------
struct WebWriter : Writer {
  String buf;
  void write(const char* s) override {
    buf += s;
    if (buf.length() > 1024) flush();
  }
  void flush() {
    if (buf.length()) server.sendContent(buf);
    buf = "";
  }
};

const char kPage[] PROGMEM = R"HTML(<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>BloomBack Band</title>
<style>body{font-family:system-ui;margin:16px;max-width:520px}button,a.b{display:block;width:100%;
padding:12px;margin:8px 0;font-size:16px;text-align:center;border-radius:8px;border:1px solid #888;
background:#f4f1ea;color:#222;text-decoration:none}input{font-size:16px;width:100%;padding:6px}
small{color:#666}</style></head><body>
<h2>BloomBack Band</h2><p id="s">Loading…</p>
<p><small>Your data stays on this watch. It leaves only when you press download here.</small></p>
<a class="b" href="/export.json">Download summary (FHIR JSON)</a>
<a class="b" href="/export.csv">Download minute data (CSV)</a>
<h3>Settings</h3><form method="post" action="/config">
Habit<input name="habit" id="habit"><br>
Reminder 1 (HH:MM, empty = off)<input name="r1" id="r1"><br>
Reminder 2<input name="r2" id="r2"><br>
Quiet from<input name="qs" id="qs"> to<input name="qe" id="qe">
<button>Save settings</button></form>
<form method="post" action="/delete" onsubmit="return confirm('Delete all data on the watch? This cannot be undone.')">
<input type="hidden" name="confirm" value="yes"><button>Delete all data on the watch</button></form>
<script>
const t=v=>v<0?"":String(Math.floor(v/60)).padStart(2,"0")+":"+String(v%60).padStart(2,"0");
fetch("/settime?utc="+Math.floor(Date.now()/1000)+"&tz="+(-new Date().getTimezoneOffset()))
.then(()=>fetch("/status")).then(r=>r.json()).then(j=>{
s.textContent=`Today: ${j.steps} steps, ${j.active} active min. Days stored: ${j.days}. Battery ${j.battery}%.`;
habit.value=j.habit;r1.value=t(j.r1);r2.value=t(j.r2);qs.value=t(j.qs);qe.value=t(j.qe);});
</script></body></html>)HTML";

int16_t parseHHMM(const String& s) {
  int c = s.indexOf(':');
  if (s.length() == 0 || c < 0) return -1;
  int h = s.substring(0, c).toInt(), m = s.substring(c + 1).toInt();
  if (h < 0 || h > 23 || m < 0 || m > 59) return -1;
  return h * 60 + m;
}

void handleStatus() {
  String j = "{\"steps\":" + String(today.steps) + ",\"active\":" + String(today.moderateMinutes) +
             ",\"days\":" + String(storedDays().size()) +
             ",\"battery\":" + String(M5.Power.getBatteryLevel()) + ",\"r1\":" +
             String(cfg.rem.times[0]) + ",\"r2\":" + String(cfg.rem.times[1]) +
             ",\"qs\":" + String(cfg.rem.quietStart) + ",\"qe\":" + String(cfg.rem.quietEnd) +
             ",\"habit\":\"";
  String h = cfg.habit;
  h.replace("\\", "");
  h.replace("\"", "'");
  j += h + "\"}";
  server.send(200, "application/json", j);
}

void handleExportJson() {
  flushPending();
  server.sendHeader("Content-Disposition", "attachment; filename=bloomback-watch.json");
  server.setContentLength(CONTENT_LENGTH_UNKNOWN);
  server.send(200, "application/fhir+json", "");
  WebWriter w;
  exportFhirAll(w, BB_DEVICE_NAME);
  w.flush();
  server.sendContent("");
}

void handleExportCsv() {
  flushPending();
  server.sendHeader("Content-Disposition", "attachment; filename=bloomback-watch-minutes.csv");
  server.setContentLength(CONTENT_LENGTH_UNKNOWN);
  server.send(200, "text/csv", "");
  WebWriter w;
  bool header = true;
  for (int32_t d : storedDays()) {
    std::vector<MinuteRec> recs;
    readDay(d, recs);
    WebWriter tmp;
    exportCsv(recs.data(), recs.size(), cfg.tzMin, tmp);
    String s = tmp.buf;
    if (!header) s = s.substring(s.indexOf('\n') + 1);  // one header line only
    header = false;
    w.write(s.c_str());
    w.flush();
  }
  w.flush();
  server.sendContent("");
}

void startShare() {
  char pass[9];
  snprintf(pass, sizeof pass, "%08lu", (unsigned long)(esp_random() % 100000000UL));
  uint64_t mac = ESP.getEfuseMac();  // works while Wi-Fi is still off
  char ssid[24];
  snprintf(ssid, sizeof ssid, "BloomBack-%04X", (unsigned)((mac >> 32) & 0xFFFF));
  apSsid = ssid;
  apPass = pass;
  WiFi.mode(WIFI_AP);
  WiFi.softAP(apSsid.c_str(), apPass.c_str());
  server.on("/", [] { server.send_P(200, "text/html", kPage); });
  server.on("/status", handleStatus);
  server.on("/settime", [] {
    long utc = server.arg("utc").toInt();
    if (utc > 1767225600) {
      setClock((time_t)utc);
      if (server.hasArg("tz")) cfg.tzMin = (int16_t)server.arg("tz").toInt();
      saveSettings();
      curMinute = nowMinute();
      needSummary = true;
    }
    server.send(200, "text/plain", "ok");
  });
  server.on("/export.json", handleExportJson);
  server.on("/export.csv", handleExportCsv);
  server.on("/config", HTTP_POST, [] {
    if (server.hasArg("habit") && server.arg("habit").length()) {
      String h = server.arg("habit").substring(0, 120);
      char buf[128];
      strncpy(buf, h.c_str(), sizeof buf - 1);
      buf[sizeof buf - 1] = '\0';
      bbproto::cleanUtf8(buf, bbproto::kHabitMaxChars);  // same 24-character limit as `config`
      if (buf[0]) cfg.habit = buf;
    }
    cfg.rem.times[0] = parseHHMM(server.arg("r1"));
    cfg.rem.times[1] = parseHHMM(server.arg("r2"));
    int16_t qs = parseHHMM(server.arg("qs")), qe = parseHHMM(server.arg("qe"));
    if (qs >= 0 && qe >= 0) {
      cfg.rem.quietStart = qs;
      cfg.rem.quietEnd = qe;
    }
    saveSettings();
    needSummary = true;
    server.sendHeader("Location", "/");
    server.send(303);
  });
  server.on("/delete", HTTP_POST, [] {
    if (server.arg("confirm") == "yes") {
      deleteAllData();
      needSummary = true;
    }
    server.sendHeader("Location", "/");
    server.send(303);
  });
  server.begin();
  sharing = true;
  ui = Ui::Share;
  screenOn();
}

void stopShare() {
  server.stop();
  WiFi.softAPdisconnect(true);
  WiFi.mode(WIFI_OFF);
  sharing = false;
  ui = Ui::Home;
  screenOn();
}

// ---------- USB serial: the line protocol in docs/PROTOCOL.md (lib/bbproto) ----------
struct SerialWriter : Writer {
  void write(const char* s) override { Serial.print(s); }
};

struct M5Host : StoreHost {
  int battery() override { return M5.Power.getBatteryLevel(); }
  void setTime(uint32_t utc, int16_t tz) override {
    setClock((time_t)utc);
    cfg.tzMin = tz;
    saveSettings();
    curMinute = nowMinute();
    needSummary = true;
  }

 protected:
  void onSettingsChanged() override { needSummary = true; }
  void onDeleted() override { needSummary = true; }
};

M5Host host;
bbproto::LineReader serialReader;
SerialWriter serialWriter;

void pollSerial() {
  char buf[64];
  size_t n = 0;
  while (Serial.available() && n < sizeof buf) buf[n++] = (char)Serial.read();
  if (n) serialReader.feed(buf, n, host, serialWriter);
}

// ---------- main ----------
void setup() {
  auto c = M5.config();
  M5.begin(c);
  setCpuFrequencyMhz(80);
  setenv("TZ", "UTC0", 1);
  tzset();
  Serial.begin(115200);
  M5.Display.setRotation(1);
  storeBegin();
  loadSettings();
  systemTimeFromRtc();
  WiFi.mode(WIFI_OFF);
  if (timeValid()) {
    curMinute = nowMinute();
    int32_t day = localDay(curMinute);
    pruneOldDays(day);
    today = summarize(day);
    lastSleep = today.sleep;
  }
  screenOn();
  draw();
}

void loop() {
  M5.update();
  uint32_t ms = millis();

  if (ms - lastSampleMs >= kSampleMs) {
    lastSampleMs = ms;
    sampleImu();
  }

  if (timeValid() && needSummary) {
    needSummary = false;
    flushPending();
    int32_t day = localDay(nowMinute());
    today = summarize(day);
    lastSleep = today.sleep;
    if (ui != Ui::Off) draw();
  }

  if (timeValid()) {
    uint32_t m = nowMinute();
    if (curMinute == 0) curMinute = m;
    if (m != curMinute) {
      int32_t oldDay = localDay(curMinute);
      closeMinute(curMinute);
      curMinute = m;
      int32_t day = localDay(m);
      if (day != oldDay) {  // new local day
        flushPending();
        pruneOldDays(day);
        today = summarize(day);
      }
      if (minuteOfDay(m) == cfg.dayEnd || !lastSleep.found) {
        flushPending();
        lastSleep = summarize(day).sleep;
      }
      if (day != remindDay) {
        remindDay = day;
        remindSent = 0;
      }
      int r = dueReminder(minuteOfDay(m), activeReminders(), remindSent);
      if (r >= 0 && ui != Ui::Share) {
        remindSent |= (1 << r);
        ui = Ui::Remind;
        screenOn();
        M5.Speaker.tone(2000, 120);
        delay(180);
        M5.Speaker.tone(2600, 120);
      }
      if (ui != Ui::Off) draw();
    }
  }

  pollSerial();

  bool a = M5.BtnA.wasPressed(), b = M5.BtnB.wasPressed(), bHold = M5.BtnB.wasHold();
  if (a || b || bHold) {
    switch (ui) {
      case Ui::Off:
        ui = Ui::Home;
        screenOn();
        break;
      case Ui::Home:
        if (bHold) startShare();
        else if (a) { ui = Ui::Checkin; checkinChoice = 0; }
        else if (b) homePage = (homePage + 1) % 2;
        break;
      case Ui::Checkin:
        if (b) checkinChoice = (checkinChoice + 1) % 3;
        if (a) {
          if (timeValid()) addCheckin(nowMinute(), (uint8_t)checkinChoice);
          ui = Ui::Home;
        }
        break;
      case Ui::Remind:
        if (a) { ui = Ui::Checkin; checkinChoice = 0; }
        else ui = Ui::Home;
        break;
      case Ui::Share:
        if (bHold) stopShare();
        break;
    }
    uiSince = ms;
    if (ui != Ui::Off) draw();
  }

  if (sharing) {
    server.handleClient();
    if (ms - uiSince > 15 * 60 * 1000UL) stopShare();  // stop sharing after 15 min idle
  } else if (ui != Ui::Off && ms - uiSince > 15000) {
    screenOff();
  }
  delay(2);
}
