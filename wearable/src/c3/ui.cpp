#include "ui.h"

#include <Arduino.h>
#include <U8g2lib.h>

#include "pins.h"

namespace {

// 72x40 visible window of the SSD1306 ("ER" = the offset these 0.42" glass panels use).
U8G2_SSD1306_72X40_ER_F_HW_I2C u8g2(U8G2_R0, U8X8_PIN_NONE, BB_SCL, BB_SDA);

constexpr int W = 72;
const uint8_t* kSmall = u8g2_font_5x8_tf;     // 14 characters a line
const uint8_t* kText = u8g2_font_6x10_tf;     // 12 characters a line
const uint8_t* kBig = u8g2_font_logisoso16_tn;
const uint8_t* kCode = u8g2_font_10x20_tn;    // passkey: 6 digits x 10 px
const uint8_t* kHabit = u8g2_font_unifont_t_vietnamese2;  // UTF-8, Vietnamese marks

void centered(const char* s, int y) {
  int w = u8g2.getUTF8Width(s);
  u8g2.drawUTF8((W - w) / 2 > 0 ? (W - w) / 2 : 0, y, s);
}

void hhmm(int mod, char* out) {  // out: at least 8 bytes
  mod = ((mod % 1440) + 1440) % 1440;
  snprintf(out, 8, "%02d:%02d", mod / 60, mod % 60);
}

// Habit text on the top line; long text scrolls.
void habitLine(const char* habit, uint32_t ms) {
  u8g2.setFont(kHabit);
  int w = u8g2.getUTF8Width(habit);
  if (w <= W) {
    u8g2.drawUTF8((W - w) / 2, 14, habit);
    return;
  }
  int gap = 24;
  int off = (int)((ms / 50) % (uint32_t)(w + gap));
  u8g2.drawUTF8(-off, 14, habit);
  u8g2.drawUTF8(-off + w + gap, 14, habit);
}

void icon(int choice, int x, int y) {  // 12x10 box with top-left (x, y)
  for (int t = 0; t < 2; t++) {
    if (choice == 0) {  // check mark
      u8g2.drawLine(x, y + 5 + t, x + 4, y + 9 + t);
      u8g2.drawLine(x + 4, y + 9 + t, x + 11, y + t);
    } else if (choice == 1) {  // tilde: partly
      u8g2.drawLine(x, y + 6 + t, x + 3, y + 3 + t);
      u8g2.drawLine(x + 3, y + 3 + t, x + 8, y + 7 + t);
      u8g2.drawLine(x + 8, y + 7 + t, x + 11, y + 4 + t);
    } else {  // cross: not today
      u8g2.drawLine(x + 1 + t, y, x + 10 + t, y + 9);
      u8g2.drawLine(x + 10 + t, y, x + 1 + t, y + 9);
    }
  }
}

const char* kChoice[] = {"Done", "Partly", "Not today"};

void home(const UiModel& m) {
  char a[16], b[16];
  switch (m.page) {
    case kPageTime:
      if (!m.timeValid) {
        u8g2.setFont(kText);
        centered("Open the", 10);
        centered("BloomBack", 21);
        centered("app to start", 32);
        break;
      }
      u8g2.setFont(kBig);
      hhmm(m.nowMod, a);
      centered(a, 18);
      u8g2.setFont(kSmall);
      if (m.battery >= 0) {
        snprintf(b, sizeof b, "%d%%", m.battery);
        u8g2.drawStr(0, 39, b);
      }
      if (m.bleSecure) u8g2.drawStr(W - 10, 39, "BT");
      else if (m.bleConnected) u8g2.drawStr(W - 10, 39, "bt");
      if (!m.imuOk) u8g2.drawStr(24, 39, "IMU!");
      break;
    case kPageSteps:
    case kPageActive:
      u8g2.setFont(kSmall);
      centered(m.page == kPageSteps ? "steps today" : "active min", 8);
      u8g2.setFont(kBig);
      snprintf(a, sizeof a, "%lu", m.page == kPageSteps ? (unsigned long)m.steps
                                                         : (unsigned long)m.active);
      centered(a, 34);
      break;
    case kPageSleep:
      u8g2.setFont(kSmall);
      centered("last sleep", 8);
      u8g2.setFont(kText);
      if (m.sleepFound) {
        char s[8], e[8];
        hhmm(m.sleepStartMod, s);
        hhmm(m.sleepEndMod, e);
        snprintf(a, sizeof a, "%s-%s", s, e);
        centered(a, 22);
        snprintf(b, sizeof b, "~%uh%02u", m.sleepMinutes / 60, m.sleepMinutes % 60);
        centered(b, 35);
      } else {
        centered("no data", 26);
      }
      break;
    case kPagePhone:
      u8g2.setFont(kSmall);
      centered("phone", 8);
      u8g2.setFont(kText);
      centered(m.bleSecure ? "connected" : (m.bonds > 0 ? "paired" : "not paired"), 22);
      u8g2.setFont(kSmall);
      centered(m.bonds > 0 ? "hold: unpair" : "pair in app", 36);
      break;
  }
}

}  // namespace

namespace ui {

bool begin() {
  u8g2.setBusClock(BB_I2C_HZ);
  bool ok = u8g2.begin();
  u8g2.setContrast(60);  // dimmer = less current; still readable indoors
  u8g2.enableUTF8Print();
  return ok;
}

bool screenOn = true;

void power(bool on) {
  screenOn = on;
  u8g2.setPowerSave(on ? 0 : 1);
}

// Demo mirror (USB only): "SCREEN <1|0> <hex>" = the 72x40 frame buffer, 5 pages x 72 bytes, each byte 8 pixels
// down (lowest bit on top). tools/mirror.py draws it large on a computer screen.
void dumpScreen() {
  static const char hx[] = "0123456789ABCDEF";
  const uint8_t* b = u8g2.getBufferPtr();
  const size_t n = (size_t)u8g2.getBufferTileWidth() * u8g2.getBufferTileHeight() * 8;
  Serial.print(screenOn ? "SCREEN 1 " : "SCREEN 0 ");
  char chunk[65];
  size_t k = 0;
  for (size_t i = 0; i < n; i++) {
    chunk[k++] = hx[b[i] >> 4];
    chunk[k++] = hx[b[i] & 15];
    if (k == 64) {
      chunk[k] = 0;
      Serial.print(chunk);
      k = 0;
    }
  }
  chunk[k] = 0;
  Serial.print(chunk);
  Serial.print("\n");
}

bool animated(const UiModel& m) {
  if (m.screen != Screen::Checkin && m.screen != Screen::Remind) return false;
  u8g2.setFont(kHabit);
  return u8g2.getUTF8Width(m.habit) > W;
}

void draw(const UiModel& m, uint32_t ms) {
  if (m.screen == Screen::Off) return;
  u8g2.clearBuffer();
  u8g2.setFontMode(1);
  switch (m.screen) {
    case Screen::Home:
      home(m);
      break;
    case Screen::Checkin:
      habitLine(m.habit, ms);
      icon(m.choice, 2, 26);
      u8g2.setFont(kText);
      u8g2.drawStr(18, 36, kChoice[m.choice % 3]);
      break;
    case Screen::Remind:
      habitLine(m.habit, ms);
      u8g2.setFont(kSmall);
      centered("hold: check-in", 28);
      centered("press: later", 38);
      break;
    case Screen::Saved:
      u8g2.setFont(kText);
      centered(m.message, 24);
      break;
    case Screen::Pairing: {
      u8g2.setFont(kSmall);
      centered("pair code", 8);
      char code[8];
      snprintf(code, sizeof code, "%06lu", (unsigned long)m.passkey);
      u8g2.setFont(kCode);
      centered(code, 32);
      break;
    }
    case Screen::Unpair:
      u8g2.setFont(kText);
      centered("Unpair?", 10);
      u8g2.setFont(kSmall);
      centered("hold: yes", 26);
      centered("press: no", 37);
      break;
    case Screen::Off:
      break;
  }
  u8g2.sendBuffer();
}

}  // namespace ui
