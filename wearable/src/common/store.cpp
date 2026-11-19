#include "store.h"

#include <LittleFS.h>
#include <time.h>

#include <algorithm>

#include "settings.h"

using namespace bb;

bool clockValid = false;
std::vector<MinuteRec> pending;
void (*storeTick)() = nullptr;

static const char* kCheckins = "/checkins.bin";
static constexpr size_t kMinFreeBytes = 48 * 1024;

uint32_t nowMinute() { return (uint32_t)(time(nullptr) / 60); }
int32_t localDay(uint32_t utcMin) { return (int32_t)((int64_t)((int64_t)utcMin + cfg.tzMin) / 1440); }
int minuteOfDay(uint32_t utcMin) { return (int)(((int64_t)utcMin + cfg.tzMin) % 1440); }

static String dayPath(int32_t day) { return "/d/" + String(day) + ".bin"; }

static void tick(uint32_t& n) {
  if (++n % 48 == 0 && storeTick) storeTick();
}

bool storeBegin() {
  bool ok = LittleFS.begin(true);
  if (ok) LittleFS.mkdir("/d");
  return ok;
}

void flushPending() {
  size_t i = 0;
  while (i < pending.size()) {
    int32_t day = localDay(pending[i].minute);
    File f = LittleFS.open(dayPath(day), FILE_APPEND, true);
    while (i < pending.size() && localDay(pending[i].minute) == day) {
      if (f) f.write((const uint8_t*)&pending[i], sizeof(MinuteRec));
      i++;
    }
    if (f) f.close();
  }
  pending.clear();
}

void readDay(int32_t day, std::vector<MinuteRec>& out) {
  File f = LittleFS.open(dayPath(day), FILE_READ);
  if (!f) return;
  out.reserve(out.size() + f.size() / sizeof(MinuteRec));
  MinuteRec r;
  uint32_t n = 0;
  while (f.read((uint8_t*)&r, sizeof r) == sizeof r) {
    out.push_back(r);
    tick(n);
  }
  f.close();
}

std::vector<int32_t> storedDays() {
  std::vector<int32_t> days;
  File dir = LittleFS.open("/d");
  if (!dir) return days;
  for (File f = dir.openNextFile(); f; f = dir.openNextFile()) {
    String n = f.name();
    int slash = n.lastIndexOf('/');
    if (slash >= 0) n = n.substring(slash + 1);
    days.push_back(n.toInt());
  }
  std::sort(days.begin(), days.end());
  return days;
}

DaySummary summarize(int32_t day) {
  std::vector<MinuteRec> recs;
  readDay(day - 1, recs);
  readDay(day, recs);
  for (auto& r : pending) recs.push_back(r);
  DaySummary d;
  d.dayStartMinute = (uint32_t)((int64_t)day * 1440 - cfg.tzMin);
  summarizeSteps(recs.data(), recs.size(), d);
  uint32_t end = d.dayStartMinute + cfg.dayEnd;
  std::vector<MinuteRec> win;
  for (auto& r : recs)
    if (r.minute >= end - 1440 && r.minute < end) win.push_back(r);
  d.sleep = detectMainSleep(win.data(), win.size());
  return d;
}

void addCheckin(uint32_t minute, uint8_t status) {
  Checkin c{minute, status};
  File f = LittleFS.open(kCheckins, FILE_APPEND, true);
  if (f) {
    f.write((const uint8_t*)&c, sizeof c);
    f.close();
  }
}

void deleteAllData() {
  pending.clear();
  for (int32_t d : storedDays()) LittleFS.remove(dayPath(d));
  LittleFS.remove(kCheckins);
}

void pruneOldDays(int32_t today) {
  std::vector<int32_t> days = storedDays();
  size_t i = 0;
  for (; i < days.size() && days[i] <= today - kKeepDays; i++) LittleFS.remove(dayPath(days[i]));
  // Keep room for new minutes even if the clock jumped or files grew bigger than planned.
  while (i + 1 < days.size() && LittleFS.totalBytes() - LittleFS.usedBytes() < kMinFreeBytes)
    LittleFS.remove(dayPath(days[i++]));

  // Check-ins older than the oldest day kept are dropped too.
  uint32_t cutoff = (uint32_t)((int64_t)(today - kKeepDays + 1) * 1440 - cfg.tzMin);
  File f = LittleFS.open(kCheckins, FILE_READ);
  if (!f) return;
  std::vector<Checkin> keep;
  Checkin c;
  bool dropped = false;
  while (f.read((uint8_t*)&c, sizeof c) == sizeof c) {
    if (c.minute >= cutoff) keep.push_back(c);
    else dropped = true;
  }
  f.close();
  if (!dropped) return;
  f = LittleFS.open(kCheckins, FILE_WRITE);
  if (!f) return;
  for (auto& k : keep) f.write((const uint8_t*)&k, sizeof k);
  f.close();
}

// First and last record of one day file.
static bool fileEnds(int32_t day, MinuteRec& first, MinuteRec& last) {
  File f = LittleFS.open(dayPath(day), FILE_READ);
  if (!f) return false;
  size_t size = f.size();
  bool ok = size >= sizeof(MinuteRec) && f.read((uint8_t*)&first, sizeof first) == sizeof first &&
            f.seek(size - size % sizeof(MinuteRec) - sizeof(MinuteRec)) &&
            f.read((uint8_t*)&last, sizeof last) == sizeof last;
  f.close();
  return ok;
}

bool dataRange(uint32_t& first, uint32_t& last) {
  bool have = false;
  MinuteRec a, b;
  std::vector<int32_t> days = storedDays();
  for (size_t i = 0; i < days.size() && !have; i++) {
    if (fileEnds(days[i], a, b)) {
      first = a.minute;
      have = true;
    }
  }
  for (size_t i = days.size(); i-- > 0;) {
    if (fileEnds(days[i], a, b)) {
      last = b.minute;
      break;
    }
  }
  if (!pending.empty()) {
    if (!have) first = pending.front().minute;
    last = pending.back().minute;
    have = true;
  }
  return have;
}

void visitMinutesAfter(uint32_t since, bbproto::RecordVisitor& v) {
  flushPending();
  uint32_t n = 0;
  for (int32_t day : storedDays()) {
    MinuteRec a, b;
    // Files are written in time order, so a file that ends at or before `since` is skipped
    // without reading it all.
    if (!fileEnds(day, a, b)) continue;
    if (b.minute <= since && a.minute <= b.minute) continue;
    File f = LittleFS.open(dayPath(day), FILE_READ);
    if (!f) continue;
    MinuteRec r;
    while (f.read((uint8_t*)&r, sizeof r) == sizeof r) {
      if (r.minute > since) v.minute(r);
      tick(n);
    }
    f.close();
  }
}

void visitCheckinsAfter(uint32_t since, bbproto::RecordVisitor& v) {
  File f = LittleFS.open(kCheckins, FILE_READ);
  if (!f) return;
  Checkin c;
  while (f.read((uint8_t*)&c, sizeof c) == sizeof c)
    if (c.minute > since) v.checkin(c);
  f.close();
}

void exportFhirAll(Writer& w, const char* deviceName) {
  flushPending();
  std::vector<DaySummary> days;
  for (int32_t d : storedDays()) {
    days.push_back(summarize(d));
    if (storeTick) storeTick();
  }
  std::vector<Checkin> cks;
  File f = LittleFS.open(kCheckins, FILE_READ);
  if (f) {
    Checkin c;
    while (f.read((uint8_t*)&c, sizeof c) == sizeof c) cks.push_back(c);
    f.close();
  }
  exportFhir(days.data(), days.size(), cks.data(), cks.size(), cfg.tzMin, deviceName, w);
}
