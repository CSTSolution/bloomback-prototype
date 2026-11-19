// BloomBack band <-> app line protocol v1 (docs/PROTOCOL.md).
// Plain C++ (no Arduino): the same code answers over Bluetooth LE and USB serial on
// the band, and runs in the Mac tests with a fake host.
#pragma once
#include <stddef.h>
#include <stdint.h>

#include "bb_types.h"
#include "export.h"

namespace bbproto {

constexpr const char* kFirmwareVersion = "0.2.0";
constexpr size_t kMaxLine = 200;             // bytes per line, including the '\n'
constexpr int kHabitMaxChars = 24;           // characters (code points), tiny screen
constexpr size_t kHabitMaxBytes = kHabitMaxChars * 4;
constexpr uint32_t kMinValidUtc = 1767225600u;  // 2026-01-01T00:00:00Z
constexpr uint32_t kMaxValidUtc = 4102444800u;  // 2100-01-01T00:00:00Z
constexpr int kMinTz = -12 * 60;
constexpr int kMaxTz = 14 * 60;

// Settings the app can change with `config` (+ the time zone from `time`).
// Times are local minutes of the day, -1 = off.
struct Settings {
  int16_t r1 = 8 * 60;    // reminder 1
  int16_t r2 = 20 * 60;   // reminder 2
  int16_t qs = 22 * 60;   // quiet hours start
  int16_t qe = 6 * 60;    // quiet hours end
  int16_t de = 18 * 60;   // day end used for "last night's sleep"
  int16_t tz = 7 * 60;    // minutes east of UTC
  char habit[kHabitMaxBytes + 1] = "Go to bed 15 min earlier";
};

class RecordVisitor {
 public:
  virtual ~RecordVisitor() {}
  virtual void minute(const bb::MinuteRec& r) = 0;
  virtual void checkin(const bb::Checkin& c) = 0;
};

// What the protocol needs from the band. The firmware implements it on top of
// LittleFS/NVS; the tests implement it with vectors.
class BandHost {
 public:
  virtual ~BandHost() {}
  virtual const char* board() = 0;            // e.g. "c3-oled"
  virtual int battery() = 0;                  // 0..100, -1 = unknown
  virtual bool timeValid() = 0;
  virtual void setTime(uint32_t utcSeconds, int16_t tzMin) = 0;
  virtual void getSettings(Settings& s) = 0;
  virtual void setSettings(const Settings& s) = 0;
  virtual uint32_t daysStored() = 0;
  // First and last stored minute (UTC unix minutes). false = no data.
  virtual bool dataRange(uint32_t& first, uint32_t& last) = 0;
  // Calls v.minute() for every stored minute with minute > since, oldest first.
  virtual void visitMinutes(uint32_t since, RecordVisitor& v) = 0;
  // Calls v.checkin() for every check-in with minute > since, oldest first.
  virtual void visitCheckins(uint32_t since, RecordVisitor& v) = 0;
  // FHIR Bundle of all stored days (ends with "\n").
  virtual void exportJson(bb::Writer& w) = 0;
  // Wipes minutes and check-ins. Bonds and settings stay.
  virtual void deleteAll() = 0;
  // true while the band cannot answer data commands (e.g. writing flash).
  virtual bool busy() { return false; }
};

// Handles one command line (without the '\n'; a trailing '\r' is ignored) and
// writes the full answer, every line ending in '\n'. An empty line gets no answer.
void handleLine(const char* line, BandHost& host, bb::Writer& out);

// Joins bytes from a transport into lines and calls handleLine for each.
// A line longer than kMaxLine bytes is dropped and answered with "ERR args".
class LineReader {
 public:
  void feed(const char* data, size_t n, BandHost& host, bb::Writer& out);
  void reset() { len_ = 0; overflow_ = false; }

 private:
  char buf_[kMaxLine];
  size_t len_ = 0;
  bool overflow_ = false;
};

// Parses the JSON object of `config` into s. Only known keys change; unknown keys
// are ignored. Returns false (and leaves s unchanged) on any error.
bool parseConfig(const char* json, Settings& s);

// Replaces invalid UTF-8 with '?' and control characters with ' ', then cuts the
// text after maxChars code points without splitting a character. Works in place.
void cleanUtf8(char* s, int maxChars);

// Number of UTF-8 code points in s.
int utf8Length(const char* s);

}  // namespace bbproto
