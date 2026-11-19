// Data kept on the band, shared by every board:
//   /d/<localDay>.bin   MinuteRec records (12 bytes each), appended in time order
//   /checkins.bin       Checkin records
// The format is the same on the M5StickC Plus2 and the ESP32-C3 band.
#pragma once
#include <Arduino.h>

#include <vector>

#include "bb_types.h"
#include "bbproto.h"
#include "export.h"
#include "sleep.h"

constexpr int kKeepDays = 60;  // local days of minute files kept on the band

// ---------- clock ----------
// true once the clock holds a real time (from the app, or the M5's RTC).
extern bool clockValid;
uint32_t nowMinute();
int32_t localDay(uint32_t utcMin);
int minuteOfDay(uint32_t utcMin);

// ---------- storage ----------
extern std::vector<bb::MinuteRec> pending;  // closed minutes not yet written to flash

// Called every few dozen records during long reads (sync/export), so a board can
// keep its sensor FIFO from overflowing. May be null.
extern void (*storeTick)();

bool storeBegin();
void flushPending();
void readDay(int32_t day, std::vector<bb::MinuteRec>& out);
std::vector<int32_t> storedDays();
// Steps + sleep for local day `day`. Sleep = main sleep in the 24 h ending at day's dayEnd.
bb::DaySummary summarize(int32_t day);
void addCheckin(uint32_t minute, uint8_t status);
void deleteAllData();
// Deletes day files older than kKeepDays (and the oldest days while flash is nearly full).
void pruneOldDays(int32_t today);
bool dataRange(uint32_t& first, uint32_t& last);
void visitMinutesAfter(uint32_t since, bbproto::RecordVisitor& v);
void visitCheckinsAfter(uint32_t since, bbproto::RecordVisitor& v);
void exportFhirAll(bb::Writer& w, const char* deviceName);
