// Screens for the demo board (env `cyd`): ESP32 + 2.4" 320x240 colour touch display (ESP32-2432S024 family,
// ST7789, XPT2046 resistive touch on the display's SPI bus). Same interface as the 0.42" OLED screens
// (../c3/ui.h), so the band firmware (main, BLE, motion, storage) is the same; only the drawing differs.
//
// Look: the phone app's light theme (app/lib/ui/theme.dart) and its sprout logo (app/design/AppIcon.png).
// A top bar (logo, link state, small DEMO tag while steps are simulated), five pages with a tab bar at the
// bottom (Today, Steps, Active, Sleep, Phone), and full-screen dialogs (check-in, pairing code, reminder).
// Everything can be used with the pen or with the BOOT button (press = next, hold = action).
//
// Drawing goes to a 4-bit sprite (16 exact palette colours, 38 KB) and is pushed in one go: no flicker.
// Icons are 1-bit bitmaps from tools/cyd_icons.py. Text is ASCII: Vietnamese habit names lose their marks.
#include "../c3/ui.h"

#include <Arduino.h>
#include <Preferences.h>
#include <TFT_eSPI.h>
#include <Wire.h>
#include <esp_mac.h>

#include "icons.h"

#ifndef BB_ROTATION
#define BB_ROTATION 1  // landscape; 3 if the picture is upside down
#endif

namespace {

constexpr int W = 320, H = 240;
constexpr int kBarH = 34;                      // top bar
constexpr int kNavY = 192, kNavH = H - kNavY;  // tab bar

// Palette index = colour. The values are the app theme's, plus the logo's green and gold.
enum : uint8_t { BG, CARD, LINE, GREEN, GREEN_L, GREEN_B, INK, MUTED, SUN, ACCENT, GOLD, DATA, GREY, GREEN_D, ACCENT_L, BLACK };
constexpr uint16_t c565(uint32_t rgb) {
  return (uint16_t)(((rgb >> 8) & 0xF800) | ((rgb >> 5) & 0x07E0) | ((rgb >> 3) & 0x001F));
}
uint16_t kPalette[16] = {
    c565(0xF4FAF5), c565(0xFFFFFF), c565(0xDCE7E0), c565(0x278552), c565(0xE3F4E9), c565(0xC9E8D4),
    c565(0x1E2A24), c565(0x66746C), c565(0xFDF0D2), c565(0x9A6A12), c565(0xE2B957), c565(0x3E7CB1),
    c565(0xE6ECE8), c565(0x1D6A40), c565(0xFCF1D6), c565(0x000000)};

TFT_eSPI tft;
TFT_eSprite fb(&tft);
bool haveFb = false;
bool screenOn = true;
char bandName[20] = "BloomBack";
char owner[17] = "";  // demo preset (USB `owner Chi`): a first name for the greeting, kept in NVS on this board

// "Good afternoon, Chi" if a name is set and it fits maxW in the small font, else "Hi, Chi"; "" without a name.
const char* greeting(int nowMod, int maxW, char* buf, size_t n);

// ---------- what can be tapped on the frame now on screen ----------
struct Hit {
  int16_t x, y, w, h;
  ui::TapKind kind;
  int8_t arg;
};
constexpr int kInternalCal = 100;  // Touch + this arg = start the touch setup
Hit hits[16];
int nHits = 0;
Hit pressHit = {0, 0, 0, 0, ui::TapKind::None, 0};
uint32_t pressMs = 0;

void hit(int x, int y, int w, int h, ui::TapKind k, int arg = 0) {
  if (nHits < 16) hits[nHits++] = {(int16_t)x, (int16_t)y, (int16_t)w, (int16_t)h, k, (int8_t)arg};
}

// ---------- animation state ----------
uint32_t splashUntil = 0;
Screen lastScreen = Screen::Off;
int lastPage = -1;
uint32_t changeMs = 0;  // when the screen or page last changed
float navX = -1;        // sliding highlight of the tab bar
bool navMoving = false;
bool frozen = false;    // drawAt(): a recording frame, do not advance the live step bars
uint8_t strip[24];      // steps per 5 s, newest last (the "last 2 minutes" bars)
bool stripInit = false;
uint32_t stripMs = 0, stripBase = 0;

float ease(float t) {  // fast start, soft landing
  if (t <= 0) return 0;
  if (t >= 1) return 1;
  const float u = 1 - t;
  return 1 - u * u * u;
}

// ---------- drawing helpers ----------
void txt(const char* s, int x, int y, const GFXfont* f, uint8_t c, uint8_t datum = TL_DATUM) {
  fb.setFreeFont(f);
  fb.setTextColor(c);
  fb.setTextDatum(datum);
  fb.drawString(s, x, y);
}

void sm(const char* s, int x, int y, uint8_t c, uint8_t datum = TL_DATUM) {  // small 16 px font
  fb.setTextFont(2);
  fb.setTextColor(c);
  fb.setTextDatum(datum);
  fb.drawString(s, x, y);
}

void ic(const unsigned char* bm, int x, int y, int size, uint8_t c) { fb.drawXBitmap(x, y, bm, size, size, c); }

void card(int x, int y, int w, int h, uint8_t fill = CARD, uint8_t border = LINE) {
  fb.fillRoundRect(x, y, w, h, 8, fill);
  fb.drawRoundRect(x, y, w, h, 8, border);
}

void hhmm(int mod, char* out) {  // out: at least 8 bytes
  mod = ((mod % 1440) + 1440) % 1440;
  snprintf(out, 8, "%02d:%02d", mod / 60, mod % 60);
}

void commas(uint32_t v, char* out, size_t n) {
  if (v >= 1000) snprintf(out, n, "%lu,%03lu", (unsigned long)(v / 1000), (unsigned long)(v % 1000));
  else snprintf(out, n, "%lu", (unsigned long)v);
}

// Copies s into buf, shortened with ".." until it fits maxW in the font f.
const char* fit(const char* s, const GFXfont* f, int maxW, char* buf, size_t n) {
  fb.setFreeFont(f);
  strncpy(buf, s, n - 1);
  buf[n - 1] = '\0';
  size_t len = strlen(buf);
  while (len > 3 && fb.textWidth(buf) > maxW) {
    len--;
    buf[len] = '\0';
    buf[len - 1] = '.';
    buf[len - 2] = '.';
  }
  return buf;
}

const char* habitOr(const UiModel& m, const char* fallback) { return m.habit && *m.habit ? m.habit : fallback; }

const char* greeting(int nowMod, int maxW, char* buf, size_t n) {
  buf[0] = '\0';
  if (!owner[0]) return buf;
  const int h = (((nowMod % 1440) + 1440) % 1440) / 60;
  const char* part = h >= 5 && h < 12 ? "Good morning" : (h >= 12 && h < 18 ? "Good afternoon" : (h >= 18 && h < 22 ? "Good evening" : "Hello"));
  snprintf(buf, n, "%s, %s", part, owner);
  fb.setTextFont(2);
  if (fb.textWidth(buf) > maxW) snprintf(buf, n, "Hi, %s", owner);
  return buf;
}

// A habit name (up to 24 characters) centred on x in the largest of two fonts that fits maxW.
void habitTitle(const UiModel& m, int cx, int y, int maxW) {
  const char* s = habitOr(m, "Your small step");
  fb.setFreeFont(&FreeSansBold12pt7b);
  const GFXfont* f = fb.textWidth(s) <= maxW ? &FreeSansBold12pt7b : &FreeSansBold9pt7b;
  char buf[40];
  txt(fit(s, f, maxW, buf, sizeof buf), cx, y, f, INK, TC_DATUM);
}

// The same name in a narrow box: one bold line if it fits, else two small lines broken at a space.
void habitBox(const UiModel& m, int x, int y, int maxW) {
  if (!(m.habit && *m.habit)) {
    sm("Set it in the app", x, y + 2, MUTED);
    return;
  }
  fb.setFreeFont(&FreeSansBold9pt7b);
  if (fb.textWidth(m.habit) <= maxW) {
    txt(m.habit, x, y, &FreeSansBold9pt7b, INK);
    return;
  }
  char a[40];
  strncpy(a, m.habit, sizeof a - 1);
  a[sizeof a - 1] = '\0';
  fb.setTextFont(2);
  int cut = -1;
  for (int i = (int)strlen(a) - 1; i > 0; i--) {
    if (a[i] != ' ') continue;
    a[i] = '\0';
    const bool fits = fb.textWidth(a) <= maxW;
    a[i] = ' ';
    if (fits) {
      cut = i;
      break;
    }
  }
  if (cut < 0) {
    sm(a, x, y - 2, INK);
    return;
  }
  a[cut] = '\0';
  sm(a, x, y - 6, INK);
  sm(a + cut + 1, x, y + 10, INK);
}

bool isPressed(int x, int y, uint32_t ms) { return ms - pressMs < 220 && pressHit.x == x && pressHit.y == y; }

void button(int x, int y, int w, int h, const char* label, bool primary, ui::TapKind k, int arg, uint32_t ms,
            const unsigned char* icon24 = nullptr) {
  const bool down = isPressed(x, y, ms);
  if (primary) {
    fb.fillRoundRect(x, y, w, h, 10, down ? GREEN_D : GREEN);
  } else {
    fb.fillRoundRect(x, y, w, h, 10, down ? GREEN_L : CARD);
    fb.drawRoundRect(x, y, w, h, 10, GREEN_B);
  }
  const GFXfont* f = &FreeSansBold9pt7b;
  fb.setFreeFont(f);
  const int tw = fb.textWidth(label);
  int x0 = x + (w - tw - (icon24 ? 30 : 0)) / 2;
  if (icon24) {
    ic(icon24, x0, y + (h - 24) / 2, 24, primary ? CARD : GREEN);
    x0 += 30;
  }
  txt(label, x0, y + h / 2 - 1, f, primary ? CARD : GREEN, ML_DATUM);
  hit(x, y, w, h, k, arg);
}

void logo(int x, int y, int size, const unsigned char* leaf, const unsigned char* moon) {
  ic(moon, x, y, size, GOLD);
  ic(leaf, x, y, size, GREEN);
}

// ---------- top bar ----------
bool syncing(const UiModel& m, uint32_t ms) { return m.syncMs && ms - m.syncMs < 2600; }
bool justSynced(const UiModel& m, uint32_t ms) { return m.syncMs && ms - m.syncMs >= 2600 && ms - m.syncMs < 5400; }

void topBar(const UiModel& m, uint32_t ms) {
  fb.fillRect(0, 0, W, kBarH, SUN);
  logo(8, 3, 28, ic_logo_leaf28, ic_logo_moon28);
  txt("BloomBack", 42, kBarH / 2, &FreeSansBold9pt7b, GREEN, ML_DATUM);
  hit(0, 0, 140, kBarH, ui::TapKind::Page, kPageTime);

  int x = W - 8;
  const bool onToday = m.screen == Screen::Home && m.page == kPageTime;
  if (m.timeValid && !onToday) {  // Today shows the time large
    char t[8];
    hhmm(m.nowMod, t);
    txt(t, x, kBarH / 2, &FreeSansBold9pt7b, INK, MR_DATUM);
    fb.setFreeFont(&FreeSansBold9pt7b);
    x -= fb.textWidth(t) + 10;
  }
  x -= 16;
  if (syncing(m, ms)) {
    static const unsigned char* const kSpin[4] = {ic_sync0_16, ic_sync1_16, ic_sync2_16, ic_sync3_16};
    ic(kSpin[(ms / 110) % 4], x, 9, 16, GREEN);
  } else {
    ic(ic_bt16, x, 9, 16, m.bleSecure ? GREEN : (m.bleConnected ? ACCENT : (m.bonds ? MUTED : GREEN_B)));
  }
  x -= 10;
  if (m.demoSteps) {  // steps are simulated until a motion sensor is fitted: say so, quietly
    fb.setTextFont(1);
    const int w = fb.textWidth("DEMO") + 10;
    x -= w;
    fb.drawRoundRect(x, 10, w, 14, 4, ACCENT);
    fb.setTextColor(ACCENT);
    fb.setTextDatum(TL_DATUM);
    fb.drawString("DEMO", x + 5, 13);
  }
}

// ---------- tab bar ----------
void navBar(const UiModel& m, uint32_t) {
  static const char* const kLabel[kPageCount] = {"Today", "Steps", "Active", "Sleep", "Phone"};
  const int tw = W / kPageCount;
  fb.fillRect(0, kNavY, W, kNavH, CARD);
  fb.drawFastHLine(0, kNavY, W, LINE);
  const float target = m.page * tw + tw / 2;
  if (navX < 0) navX = target;
  navX += (target - navX) * 0.5f;
  navMoving = fabsf(target - navX) >= 1.0f;
  if (!navMoving) navX = target;
  fb.fillRoundRect((int)navX - 25, kNavY + 3, 50, 28, 14, GREEN_L);
  for (int i = 0; i < kPageCount; i++) {
    const int x = i * tw;
    const uint8_t c = i == m.page ? GREEN : MUTED;
    const int ix = x + (tw - 24) / 2, iy = kNavY + 5;
    switch (i) {
      case kPageTime: ic(ic_home24, ix, iy, 24, c); break;
      case kPageSteps:
        ic(ic_foot_l24, ix, iy, 24, c);
        ic(ic_foot_r24, ix, iy, 24, c);
        break;
      case kPageActive: ic(ic_timer24, ix, iy, 24, c); break;
      case kPageSleep: ic(ic_moon24, ix, iy, 24, c); break;
      default: ic(ic_phone24, ix, iy, 24, c); break;
    }
    sm(kLabel[i], x + tw / 2, kNavY + 31, c, TC_DATUM);
    hit(x, kNavY, tw, kNavH, ui::TapKind::Page, i);
  }
}

// ---------- pages ----------
void pageHeader(const char* title) { sm(title, 70, 44, MUTED); }

void pageToday(const UiModel& m, uint32_t ms) {
  if (!m.timeValid) {  // no clock yet: nothing is recorded until the app connects
    char w[40];
    card(12, 42, 296, 108);
    ic(ic_phone40, 28, 54, 40, GREEN);
    if (owner[0]) {
      snprintf(w, sizeof w, "Welcome, %s", owner);
      txt(w, 80, 56, &FreeSansBold9pt7b, INK);
      sm("Open the BloomBack app to set", 80, 80, MUTED);
      sm("the clock and start", 80, 98, MUTED);
    } else {
      txt("Open the BloomBack app", 80, 56, &FreeSansBold9pt7b, INK);
      sm("The band starts once your", 80, 80, MUTED);
      sm("phone sets its clock", 80, 98, MUTED);
    }
    for (int i = 0; i < 3; i++) fb.fillCircle(84 + i * 14, 130, 3, (int)((ms / 350) % 3) == i ? GREEN : GREEN_B);
    return;
  }
  char t[8], buf[40];
  hhmm(m.nowMod, t);
  txt(t, 14, 44, &FreeSansBold24pt7b, INK);
  if (owner[0]) {
    sm(greeting(m.nowMod, 128, buf, sizeof buf), 12, 84, GREEN);
  } else {
    sm(m.bleSecure ? "phone connected" : (m.bleConnected ? "connecting" : (m.bonds ? "phone paired" : "no phone yet")),
       16, 84, m.bleSecure ? GREEN : MUTED);
  }

  card(142, 42, 166, 58);
  sm("Your small step", 152, 46, MUTED);
  habitBox(m, 152, 70, 148);
  hit(142, 42, 166, 58, ui::TapKind::Checkin);

  button(12, 106, 296, 38, "Check in", true, ui::TapKind::Checkin, 0, ms, ic_check24);

  const int y = 152, h = 34, w = 94, gap = 7;
  for (int i = 0; i < 3; i++) {
    const int x = 12 + i * (w + gap);
    card(x, y, w, h);
    if (i == 0) {
      ic(ic_foot_l24, x + 6, y + 5, 24, GREEN);
      ic(ic_foot_r24, x + 6, y + 5, 24, GREEN);
      commas(m.steps, buf, sizeof buf);
    } else if (i == 1) {
      ic(ic_timer24, x + 6, y + 5, 24, GREEN);
      snprintf(buf, sizeof buf, "%u min", (unsigned)m.active);
    } else {
      ic(ic_moon24, x + 6, y + 5, 24, GOLD);
      if (m.sleepFound) snprintf(buf, sizeof buf, "%uh%02u", m.sleepMinutes / 60, m.sleepMinutes % 60);
      else snprintf(buf, sizeof buf, "--");
    }
    txt(buf, x + 36, y + h / 2 - 1, &FreeSansBold9pt7b, INK, ML_DATUM);
    hit(x, y, w, h, ui::TapKind::Page, kPageSteps + i);
  }
}

void pageSteps(const UiModel& m, uint32_t ms) {
  const uint32_t recent = strip[23] + (m.steps >= stripBase ? m.steps - stripBase : 0);
  const bool walking = recent >= 4;
  const bool left = (ms / 330) % 2 == 0;  // the two prints take turns while walking
  ic(ic_foot_l40, 16, 44, 40, !walking || left ? GREEN : GREEN_B);
  ic(ic_foot_r40, 16, 44, 40, !walking || !left ? GREEN : GREEN_B);
  pageHeader("Steps today");
  char buf[16];
  const float g = ease((ms - changeMs) / 600.0f);  // count up when the page opens
  commas((uint32_t)(m.steps * g + 0.5f), buf, sizeof buf);
  txt(buf, 70, 62, &FreeSansBold24pt7b, INK);
  sm(walking ? "walking now" : "resting", 70, 104, walking ? GREEN : MUTED);

  card(12, 126, 296, 60);
  sm("last 2 minutes", 22, 129, MUTED);
  for (int i = 0; i < 24; i++) {
    const int x = 22 + i * 12;
    int bh = strip[i] * 3;
    if (bh > 30) bh = 30;
    if (bh < 2) fb.fillRect(x, 178, 9, 2, GREY);
    else fb.fillRoundRect(x, 180 - bh, 9, bh, 2, DATA);
  }
}

void pageActive(const UiModel& m, uint32_t) {
  ic(ic_timer40, 16, 44, 40, GREEN);
  pageHeader("Active minutes today");
  char buf[16];
  snprintf(buf, sizeof buf, "%u", (unsigned)m.active);
  txt(buf, 70, 62, &FreeSansBold24pt7b, INK);
  sm("minutes at a brisk pace", 70, 104, MUTED);
  card(12, 126, 296, 60, GREEN_L, GREEN_B);
  sm("Brisk = about 100 steps a minute or more", 22, 133, INK);
  sm("Source: Tudor-Locke et al., BJSM 2018", 22, 157, MUTED);
}

void pageSleep(const UiModel& m, uint32_t) {
  ic(ic_moon40, 16, 44, 40, GOLD);
  pageHeader("Last sleep");
  char buf[24];
  if (m.sleepFound) {
    char s[8], e[8];
    hhmm(m.sleepStartMod, s);
    hhmm(m.sleepEndMod, e);
    snprintf(buf, sizeof buf, "%uh %02um", m.sleepMinutes / 60, m.sleepMinutes % 60);
    txt(buf, 70, 62, &FreeSansBold24pt7b, INK);
    snprintf(buf, sizeof buf, "%s to %s", s, e);
    sm(buf, 70, 104, MUTED);
  } else {
    txt("No sleep yet", 70, 66, &FreeSansBold18pt7b, INK);
    sm("Wear the band tonight", 70, 104, MUTED);
  }
  card(12, 126, 296, 60, ACCENT_L, SUN);
  sm("An estimate from wrist movement,", 22, 133, INK);
  sm("not a diagnosis. Source: van Hees et al.", 22, 157, MUTED);
}

void pagePhone(const UiModel& m, uint32_t ms);  // below: needs the touch state

// ---------- dialogs ----------
void screenCheckin(const UiModel& m, uint32_t ms) {
  static const char* const kChoice[3] = {"Done", "Partly", "Not today"};
  static const unsigned char* const kIcon[3] = {ic_done32, ic_partly32, ic_later32};
  static const uint8_t kTint[3] = {GREEN, ACCENT, MUTED};
  sm("Today's small step", W / 2, 40, MUTED, TC_DATUM);
  habitTitle(m, W / 2, 58, 296);
  for (int i = 0; i < 3; i++) {
    const int x = 12 + i * 102, y = 86, w = 92, h = 80;
    const bool on = i == m.choice % 3;
    card(x, y, w, h, on ? (uint8_t)GREEN : (uint8_t)CARD, on ? (uint8_t)GREEN : (uint8_t)LINE);
    ic(kIcon[i], x + (w - 32) / 2, y + 12, 32, on ? CARD : kTint[i]);
    sm(kChoice[i], x + w / 2, y + 54, on ? CARD : INK, TC_DATUM);
    hit(x, y, w, h, ui::TapKind::Choice, i);
  }
  button(12, 178, 110, 48, "Back", false, ui::TapKind::Back, 0, ms, ic_back24);
  button(134, 178, 174, 48, "Save", true, ui::TapKind::Long, 0, ms, ic_check24);
}

void screenSaved(const UiModel& m, uint32_t ms) {
  const uint32_t t = ms - changeMs;
  const char* msg = m.message && *m.message ? m.message : "Saved";
  const bool good = !strcmp(msg, "Saved") || !strcmp(msg, "Paired");
  const int cx = W / 2, cy = 108;
  fb.fillCircle(cx, cy, (int)(8 + 56 * ease(t / 350.0f)), good ? GREEN_L : GREY);
  if (good) {  // the sprout grows from the ground up
    const int rows = (int)(96 * ease((t > 150 ? t - 150 : 0) / 550.0f));
    if (rows > 0) {
      const int r0 = 96 - rows;
      fb.drawXBitmap(cx - 48, cy - 48 + r0, ic_logo_moon96 + r0 * 12, 96, rows, GOLD);
      fb.drawXBitmap(cx - 48, cy - 48 + r0, ic_logo_leaf96 + r0 * 12, 96, rows, GREEN);
    }
  } else {
    ic(ic_later32, cx - 16, cy - 16, 32, MUTED);
  }
  if (t > 300) txt(msg, cx, 200, &FreeSansBold18pt7b, good ? GREEN : INK, MC_DATUM);
  hit(0, kBarH, W, H - kBarH, ui::TapKind::Short);
}

void screenPairing(const UiModel& m, uint32_t ms) {
  const int cx = W / 2;
  const int pulse = (ms / 70) % 16;  // a ring leaving the Bluetooth sign
  fb.drawCircle(cx, 60, 20 + pulse, GREEN_B);
  fb.fillCircle(cx, 60, 20, GREEN_L);
  ic(ic_bt40, cx - 20, 40, 40, GREEN);
  sm("Type this code in the BloomBack app", cx, 92, MUTED, TC_DATUM);
  char code[8];
  snprintf(code, sizeof code, "%06lu", (unsigned long)(m.passkey % 1000000UL));
  for (int i = 0; i < 6; i++) {
    const int x = 25 + i * 46;
    card(x, 116, 40, 54, CARD, GREEN_B);
    const char d[2] = {code[i], '\0'};
    txt(d, x + 20, 142, &FreeSansBold24pt7b, INK, MC_DATUM);
  }
  sm("The code is shown only here, on the band", cx, 184, MUTED, TC_DATUM);
}

void screenRemind(const UiModel& m, uint32_t ms) {
  static const int8_t kSwing[4] = {0, 3, 0, -3};
  const int cx = W / 2;
  ic(ic_bell40, cx - 20 + kSwing[(ms / 220) % 4], 44, 40, ACCENT);
  sm("Time for your small step", cx, 94, MUTED, TC_DATUM);
  habitTitle(m, cx, 118, 296);
  button(12, 178, 130, 48, "Later", false, ui::TapKind::Short, 0, ms);
  button(154, 178, 154, 48, "Check in", true, ui::TapKind::Long, 0, ms, ic_check24);
}

void screenUnpair(const UiModel&, uint32_t ms) {
  const int cx = W / 2;
  ic(ic_phone40, cx - 20, 48, 40, MUTED);
  txt("Unpair the phone?", cx, 100, &FreeSansBold12pt7b, INK, TC_DATUM);
  sm("You can pair again from the app", cx, 130, MUTED, TC_DATUM);
  button(12, 178, 130, 48, "No", false, ui::TapKind::Short, 0, ms);
  button(154, 178, 154, 48, "Yes, unpair", true, ui::TapKind::Long, 0, ms);
}

// A notice in place of the tab bar (syncing, touch setup), so it never covers the page.
void statusBand(const char* s, const unsigned char* icon16) {
  fb.fillRect(0, kNavY, W, kNavH, INK);
  fb.setTextFont(2);
  const int x = (W - fb.textWidth(s) - 24) / 2;
  ic(icon16, x, kNavY + 16, 16, GOLD);
  sm(s, x + 24, kNavY + 16, CARD);
  hit(0, kNavY, W, kNavH, ui::TapKind::Touch);
}

// ---------- touch: XPT2046 on the display's SPI bus (TFT_eSPI reads it, CS = TOUCH_CS) ----------
struct Cal {
  uint8_t ok;            // 1 = the numbers below are valid
  uint8_t swap;          // raw y follows screen x
  float ax, bx, ay, by;  // screen = a * raw + b
};
Cal cal = {0, 0, 0, 0, 0, 0};
bool touchPresent = false;
bool calActive = false;
bool calRetry = false;
int calStep = 0;
uint32_t calSince = 0;
uint16_t calRaw[4][2];
const int16_t kCalPt[4][2] = {{26, 26}, {W - 26, 26}, {W - 26, H - 26}, {26, H - 26}};
bool armed = true;  // one tap per pen-down
uint8_t upCount = 0;
uint32_t lastTouchPoll = 0;
struct {
  bool pending;
  int x, y;
} inj = {false, 0, 0};

constexpr uint16_t kZDown = 260, kZUp = 140;

void saveCal() {
  Preferences p;
  if (p.begin("bbui", false)) {
    p.putBytes("cal", &cal, sizeof cal);
    p.end();
  }
}

void loadCal() {
  Preferences p;
  if (p.begin("bbui", true)) {
    Cal c;
    if (p.getBytes("cal", &c, sizeof c) == sizeof c && c.ok == 1) cal = c;
    if (p.isKey("owner")) p.getString("owner", owner, sizeof owner);
    p.end();
  }
}

// One steady raw reading (0..4095 each), or false while the pen is up or still moving.
bool rawPoint(uint16_t& rx, uint16_t& ry) {
  uint32_t sx = 0, sy = 0;
  uint16_t px = 0, py = 0;
  int got = 0;
  for (int i = 0; i < 6 && got < 3; i++) {
    if (tft.getTouchRawZ() < kZDown) return false;
    uint16_t x, y;
    tft.getTouchRaw(&x, &y);
    if (got && (abs((int)x - (int)px) > 90 || abs((int)y - (int)py) > 90)) {
      got = 0;  // jumped: start again
      sx = sy = 0;
    }
    px = x;
    py = y;
    sx += x;
    sy += y;
    got++;
  }
  if (got < 3 || tft.getTouchRawZ() < kZDown) return false;
  rx = (uint16_t)(sx / got);
  ry = (uint16_t)(sy / got);
  return true;
}

void startCal() {
  calActive = true;
  calStep = 0;
  calSince = millis();
  armed = false;  // the tap that started it is not the first corner
}

bool solveCal() {
  const int dxx = abs((int)calRaw[1][0] - calRaw[0][0]) + abs((int)calRaw[2][0] - calRaw[3][0]);
  const int dxy = abs((int)calRaw[1][1] - calRaw[0][1]) + abs((int)calRaw[2][1] - calRaw[3][1]);
  const int sw = dxy > dxx ? 1 : 0;
  auto A = [&](int i) { return (float)calRaw[i][sw ? 1 : 0]; };  // the raw axis that follows screen x
  auto B = [&](int i) { return (float)calRaw[i][sw ? 0 : 1]; };
  const float aL = (A(0) + A(3)) / 2, aR = (A(1) + A(2)) / 2, bT = (B(0) + B(1)) / 2, bB = (B(2) + B(3)) / 2;
  if (fabsf(aR - aL) < 800 || fabsf(bB - bT) < 600) return false;  // corners too close: a slip
  if (fabsf(A(0) - A(3)) > 500 || fabsf(A(1) - A(2)) > 500 || fabsf(B(0) - B(1)) > 500 || fabsf(B(2) - B(3)) > 500)
    return false;  // the four taps do not make a rectangle
  cal.swap = (uint8_t)sw;
  cal.ax = (kCalPt[1][0] - kCalPt[0][0]) / (aR - aL);
  cal.bx = kCalPt[0][0] - cal.ax * aL;
  cal.ay = (kCalPt[3][1] - kCalPt[0][1]) / (bB - bT);
  cal.by = kCalPt[0][1] - cal.ay * bT;
  cal.ok = 1;
  saveCal();
  Serial.printf("touch: set up (swap %d, ax %.4f bx %.1f ay %.4f by %.1f)\n", sw, cal.ax, cal.bx, cal.ay, cal.by);
  return true;
}

void drawCal(uint32_t ms) {
  fb.fillSprite(BG);
  logo(W / 2 - 14, 62, 28, ic_logo_leaf28, ic_logo_moon28);
  txt("Touch setup", W / 2, 96, &FreeSansBold12pt7b, INK, TC_DATUM);
  sm(calRetry ? "Let's try once more: tap the green target" : "Tap the green target with the pen", W / 2, 126, MUTED,
     TC_DATUM);
  char buf[16];
  snprintf(buf, sizeof buf, "%d of 4", (calStep & 3) + 1);
  sm(buf, W / 2, 148, GREEN, TC_DATUM);
  const int x = kCalPt[calStep][0], y = kCalPt[calStep][1];
  fb.drawCircle(x, y, 12 + (ms / 90) % 10, GREEN_B);
  fb.fillCircle(x, y, 11, GREEN_L);
  fb.drawCircle(x, y, 11, GREEN);
  fb.drawFastHLine(x - 16, y, 33, GREEN);
  fb.drawFastVLine(x, y - 16, 33, GREEN);
}

void pagePhone(const UiModel& m, uint32_t ms) {
  ic(ic_phone40, 16, 44, 40, m.bleSecure ? GREEN : MUTED);
  pageHeader("Phone");
  const char* st = m.bleSecure ? "Connected" : (m.bleConnected ? "Connecting" : (m.bonds ? "Paired" : "Not paired"));
  txt(st, 70, 66, &FreeSansBold18pt7b, m.bleSecure ? GREEN : INK);
  char who[48];
  if (owner[0]) snprintf(who, sizeof who, "%s's band: %s", owner, bandName);
  else snprintf(who, sizeof who, "%s", bandName);
  sm(who, 70, 104, MUTED);
  const bool linked = m.bonds > 0 || m.bleConnected;
  if (!linked) sm("In the app: More > BloomBack band > Connect", 12, 126, MUTED);
  int x = 12;
  if (linked) {
    button(x, 144, 120, 40, "Unpair", false, ui::TapKind::Long, 0, ms);
    x += 130;
  }
  if (touchPresent) button(x, 144, 166, 40, "Touch setup", false, ui::TapKind::Touch, kInternalCal, ms, ic_pen24);
}

void splashFrame(float grow, bool words) {
  fb.fillSprite(BG);
  const int cx = W / 2, cy = 96;
  fb.fillCircle(cx, cy, (int)(10 + 54 * grow), GREEN_L);
  const int rows = (int)(96 * grow);
  if (rows > 0) {
    const int r0 = 96 - rows;
    fb.drawXBitmap(cx - 48, cy - 48 + r0, ic_logo_moon96 + r0 * 12, 96, rows, GOLD);
    fb.drawXBitmap(cx - 48, cy - 48 + r0, ic_logo_leaf96 + r0 * 12, 96, rows, GREEN);
  }
  if (words) {
    txt("BloomBack", cx, 186, &FreeSansBold18pt7b, GREEN, MC_DATUM);
    if (owner[0]) {
      char w[40];
      snprintf(w, sizeof w, "Welcome, %s", owner);
      txt(w, cx, 216, &FreeSans9pt7b, INK, MC_DATUM);
    } else {
      sm("band", cx, 206, MUTED, TC_DATUM);
    }
  }
  fb.pushSprite(0, 0);
}

void sample(const UiModel& m, uint32_t ms) {  // the "last 2 minutes" bars
  if (!stripInit || ms - stripMs > 180000UL || m.steps < stripBase) {
    stripInit = true;
    memset(strip, 0, sizeof strip);
    stripBase = m.steps;
    stripMs = ms;
  }
  while (ms - stripMs >= 5000) {
    memmove(strip, strip + 1, sizeof strip - 1);
    const uint32_t d = m.steps - stripBase;
    strip[sizeof strip - 1] = (uint8_t)(d > 255 ? 255 : d);
    stripBase = m.steps;
    stripMs += 5000;
  }
}

}  // namespace

namespace ui {

bool begin() {
  // Which touch controller? (printed once at boot; capacitive panels answer on I2C 33/32)
  Wire1.begin(33, 32, 100000);
  Wire1.setTimeOut(20);
  Wire1.beginTransmission(0x15);
  const bool cst = Wire1.endTransmission() == 0;
  Wire1.end();

  tft.init();
  tft.setRotation(BB_ROTATION);
#ifdef BB_INVERT
  tft.invertDisplay(true);
#endif
  tft.fillScreen(kPalette[BG]);
#ifdef TFT_BL
  pinMode(TFT_BL, OUTPUT);
  digitalWrite(TFT_BL, TFT_BACKLIGHT_ON);
#endif
  fb.setColorDepth(4);
  haveFb = fb.createSprite(W, H) != nullptr;
  if (haveFb) fb.createPalette(kPalette, 16);
  else Serial.println("screen: no memory for the frame buffer");

  uint8_t mac[6];
  esp_read_mac(mac, ESP_MAC_BT);
  snprintf(bandName, sizeof bandName, "BloomBack-%02X%02X", mac[4], mac[5]);

  uint16_t zMax = 0;
  for (int i = 0; i < 8; i++) {
    const uint16_t z = tft.getTouchRawZ();
    if (z > zMax) zMax = z;
    delay(4);
  }
  touchPresent = zMax < 300;  // a missing chip reads as fully pressed
  loadCal();
  Serial.printf("touch: xpt2046 idle z=%u -> %s, set up %s; cst820 on i2c %s\n", zMax,
                touchPresent ? "present" : "not found", cal.ok ? "yes" : "no", cst ? "yes" : "no");

  if (haveFb) {  // the sprout grows, then the name
    for (int f = 0; f <= 12; f++) {
      splashFrame(ease(f / 12.0f), f >= 9);
      delay(25);
    }
  }
  splashUntil = millis() + 900;
  return true;
}

void power(bool on) {
  screenOn = on;
#ifdef TFT_BL
  digitalWrite(TFT_BL, on ? TFT_BACKLIGHT_ON : !TFT_BACKLIGHT_ON);
#endif
}

// USB only: the frame on screen as one line, for screenshots (tools/cydshot.py).
// "SCREEN4 <on> <w> <h> " then runs: a letter a..p = palette index, then the run length (none = 1).
void dumpScreen() {
  if (!haveFb) {
    Serial.println("ERR screen: no frame buffer");
    return;
  }
  Serial.printf("SCREEN4 %d %d %d ", screenOn ? 1 : 0, W, H);
  char buf[128];
  size_t k = 0;
  int cur = -1, run = 0;
  auto emit = [&]() {
    if (!run) return;
    buf[k++] = (char)('a' + cur);
    if (run > 1) k += snprintf(buf + k, sizeof buf - k, "%d", run);
    if (k > sizeof buf - 12) {
      Serial.write((const uint8_t*)buf, k);
      k = 0;
    }
  };
  for (int y = 0; y < H; y++) {
    for (int x = 0; x < W; x++) {
      const int v = fb.readPixelValue(x, y) & 15;
      if (v == cur) {
        run++;
      } else {
        emit();
        cur = v;
        run = 1;
      }
    }
  }
  emit();
  Serial.write((const uint8_t*)buf, k);
  Serial.println();
}

bool animated(const UiModel& m) {
  const uint32_t ms = millis();
  if (ms < splashUntil || calActive || navMoving) return true;
  if (m.screen == Screen::Pairing || m.screen == Screen::Saved || m.screen == Screen::Remind) return true;
  if (ms - changeMs < 1200 || ms - pressMs < 300) return true;
  if (m.syncMs && ms - m.syncMs < 5600) return true;
  if (m.screen == Screen::Home && (m.page == kPageSteps || !m.timeValid)) return true;
  return false;
}

void settle() {
  changeMs = millis() - 60000UL;
  pressMs = changeMs;
  navX = -1;
  splashUntil = 0;
}

void draw(const UiModel& m, uint32_t ms) {
  if (m.screen == Screen::Off || !haveFb) return;
  if (calActive) {
    nHits = 0;
    drawCal(ms);
    fb.pushSprite(0, 0);
    return;
  }
  if (ms < splashUntil) return;  // the splash stays a moment
  if (m.screen != lastScreen || m.page != lastPage) {
    if (m.screen != lastScreen || m.screen == Screen::Home) changeMs = ms;
    lastScreen = m.screen;
    lastPage = m.page;
  }
  if (!frozen) sample(m, ms);
  nHits = 0;
  fb.fillSprite(BG);
  topBar(m, ms);
  switch (m.screen) {
    case Screen::Home:
      switch (m.page) {
        case kPageSteps: pageSteps(m, ms); break;
        case kPageActive: pageActive(m, ms); break;
        case kPageSleep: pageSleep(m, ms); break;
        case kPagePhone: pagePhone(m, ms); break;
        default: pageToday(m, ms); break;
      }
      if (syncing(m, ms)) {
        static const unsigned char* const kSpin[4] = {ic_sync0_16, ic_sync1_16, ic_sync2_16, ic_sync3_16};
        statusBand("Syncing", kSpin[(ms / 110) % 4]);
      } else if (justSynced(m, ms)) {
        statusBand("Synced", ic_check16);
      } else if (touchPresent && !cal.ok) {
        statusBand("Tap the screen with the pen to set up touch", ic_pen16);
      } else {
        navBar(m, ms);
      }
      break;
    case Screen::Checkin: screenCheckin(m, ms); break;
    case Screen::Saved: screenSaved(m, ms); break;
    case Screen::Pairing: screenPairing(m, ms); break;
    case Screen::Remind: screenRemind(m, ms); break;
    case Screen::Unpair: screenUnpair(m, ms); break;
    case Screen::Off: break;
  }
  fb.pushSprite(0, 0);
}

void drawAt(const UiModel& m, uint32_t t, int32_t syncAge) {
  if (!haveFb) return;
  if (m.screen == Screen::Off) {  // the boot splash: the sprout grows, then the name
    splashFrame(ease(t / 700.0f), t >= 520);
    return;
  }
  const uint32_t base = 1000000UL;  // a private clock, so every recording gives the same frames
  UiModel c = m;
  c.syncMs = syncAge >= 0 ? base + t - (uint32_t)syncAge : 0;
  const bool wasCal = calActive;
  calActive = false;
  splashUntil = 0;
  lastScreen = c.screen;
  lastPage = c.page;
  changeMs = base;
  pressMs = 0;
  navX = -1;
  frozen = true;
  draw(c, base + t);
  frozen = false;
  calActive = wasCal;
  lastScreen = Screen::Off;  // the next live frame starts its own entry animation
}

void injectTap(int x, int y) { inj = {true, x, y}; }

void setOwner(const char* name) {
  size_t k = 0;
  for (const char* c = name; *c && k < sizeof owner - 1; c++) {
    if (*c >= 32 && *c < 127) owner[k++] = *c;  // the screen fonts are ASCII
  }
  while (k && owner[k - 1] == ' ') k--;
  owner[k] = '\0';
  Preferences p;
  if (p.begin("bbui", false)) {
    if (k) p.putString("owner", owner);
    else p.remove("owner");
    p.end();
  }
}

void recalibrate() {
  cal.ok = 0;
  calRetry = false;
  startCal();
}

Tap pollTap(const UiModel& m, uint32_t ms) {
  Tap none;
  int sx = 0, sy = 0;
  if (inj.pending) {  // USB test tap, already in screen pixels
    inj.pending = false;
    sx = inj.x;
    sy = inj.y;
  } else {
    if (!touchPresent || ms - lastTouchPoll < 20) return none;
    lastTouchPoll = ms;
    if (calActive && ms - calSince > 30000UL) {  // nobody is tapping: give up, the button still works
      calActive = false;
      return {TapKind::Touch, 0};
    }
    if (tft.getTouchRawZ() < kZUp) {
      if (upCount < 3 && ++upCount >= 2) armed = true;
      return none;
    }
    upCount = 0;
    if (!armed) return none;
    uint16_t rx, ry;
    if (!rawPoint(rx, ry)) return none;
    armed = false;
    if (m.screen == Screen::Off) return {TapKind::Wake, 0};
    if (ms < splashUntil) return none;
    if (calActive) {
      calRaw[calStep][0] = rx;
      calRaw[calStep][1] = ry;
      calSince = ms;
      if (++calStep >= 4) {
        if (solveCal()) {
          calActive = false;
        } else {
          calRetry = true;
          calStep = 0;
        }
      }
      return {TapKind::Touch, 0};
    }
    if (!cal.ok) {  // first tap ever: set the touch up
      calRetry = false;
      startCal();
      return {TapKind::Touch, 0};
    }
    const float a = cal.swap ? ry : rx, b = cal.swap ? rx : ry;
    sx = (int)(cal.ax * a + cal.bx);
    sy = (int)(cal.ay * b + cal.by);
  }
  if (m.screen == Screen::Off) return {TapKind::Wake, 0};
  for (int i = nHits - 1; i >= 0; i--) {  // later = drawn on top
    const Hit& h = hits[i];
    if (sx < h.x || sy < h.y || sx >= h.x + h.w || sy >= h.y + h.h) continue;
    pressHit = h;
    pressMs = ms;
    if (h.kind == TapKind::Touch && h.arg == kInternalCal) {
      recalibrate();
      return {TapKind::Touch, 0};
    }
    return {h.kind, h.arg};
  }
  return {TapKind::Touch, 0};  // nothing there: still keeps the screen awake
}

}  // namespace ui
