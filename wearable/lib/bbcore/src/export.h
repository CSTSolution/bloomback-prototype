// Export the watch's data to files the user downloads themselves:
// a per-minute CSV and a FHIR R4 Bundle of Observations (BloomBack rule B1:
// every source stored as FHIR Observation, labelled with its source).
#pragma once
#include "bb_types.h"
#include "sleep.h"

namespace bb {

class Writer {
 public:
  virtual ~Writer() {}
  virtual void write(const char* s) = 0;
};

struct DaySummary {
  uint32_t dayStartMinute = 0;  // UTC unix minute of local midnight
  uint32_t steps = 0;
  uint16_t moderateMinutes = 0; // minutes with >= 100 steps
  uint16_t recordedMinutes = 0; // minutes with data and not charging
  SleepWindow sleep;            // main sleep in the 24 h ending at dayEnd
};

enum CheckinStatus : uint8_t { kDone = 0, kPartial = 1, kNotToday = 2 };

struct Checkin {
  uint32_t minute;  // UTC unix minute when the user tapped
  uint8_t status;   // CheckinStatus
};

// Local date-time text, e.g. "2026-11-13T07:05:00+07:00".
void formatLocal(uint32_t utcMinute, int tzMin, char* out, int outLen);

// Steps and moderate minutes for records inside [dayStart, dayStart + 1440).
void summarizeSteps(const MinuteRec* recs, size_t n, DaySummary& day);

void exportCsv(const MinuteRec* recs, size_t n, int tzMin, Writer& w);

void exportFhir(const DaySummary* days, size_t nDays, const Checkin* checkins,
                size_t nCheckins, int tzMin, const char* deviceName, Writer& w);

}  // namespace bb
