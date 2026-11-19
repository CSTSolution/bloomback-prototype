#include "export.h"

#include <stdio.h>
#include <stdlib.h>

namespace bb {

namespace {

// Days since 1970-01-01 to y/m/d (Howard Hinnant's civil_from_days).
void civil(int32_t z, int& y, int& m, int& d) {
  z += 719468;
  int32_t era = (z >= 0 ? z : z - 146096) / 146097;
  uint32_t doe = (uint32_t)(z - era * 146097);
  uint32_t yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
  int32_t yy = (int32_t)yoe + era * 400;
  uint32_t doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
  uint32_t mp = (5 * doy + 2) / 153;
  d = (int)(doy - (153 * mp + 2) / 5 + 1);
  m = (int)(mp < 10 ? mp + 3 : mp - 9);
  y = (int)(yy + (m <= 2));
}

void obsHeader(Writer& w, bool& first, const char* id, const char* system,
               const char* code, const char* display, const char* device) {
  char buf[768];
  w.write(first ? "" : ",");
  first = false;
  snprintf(buf, sizeof buf,
           "{\"fullUrl\":\"urn:uuid:%s\",\"resource\":{\"resourceType\":\"Observation\","
           "\"id\":\"%s\",\"status\":\"final\","
           "\"meta\":{\"tag\":[{\"system\":\"urn:bloomback:source\",\"code\":\"watch\"}]},"
           "\"category\":[{\"coding\":[{\"system\":"
           "\"http://terminology.hl7.org/CodeSystem/observation-category\","
           "\"code\":\"activity\"}]}],"
           "\"code\":{\"coding\":[{\"system\":\"%s\",\"code\":\"%s\",\"display\":\"%s\"}]},"
           "\"device\":{\"display\":\"%s\"},",
           id, id, system, code, display, device);
  w.write(buf);
}

const char* kLoinc = "http://loinc.org";

}  // namespace

void formatLocal(uint32_t utcMinute, int tzMin, char* out, int outLen) {
  int64_t local = (int64_t)utcMinute + tzMin;
  int32_t days = (int32_t)(local >= 0 ? local / 1440 : (local - 1439) / 1440);
  int mod = (int)(local - (int64_t)days * 1440);
  int y, m, d;
  civil(days, y, m, d);
  int a = abs(tzMin);
  snprintf(out, outLen, "%04d-%02d-%02dT%02d:%02d:00%c%02d:%02d", y, m, d, mod / 60,
           mod % 60, tzMin < 0 ? '-' : '+', a / 60, a % 60);
}

void summarizeSteps(const MinuteRec* recs, size_t n, DaySummary& day) {
  day.steps = 0;
  day.moderateMinutes = 0;
  day.recordedMinutes = 0;
  for (size_t i = 0; i < n; i++) {
    const MinuteRec& r = recs[i];
    if (r.minute < day.dayStartMinute || r.minute >= day.dayStartMinute + 1440) continue;
    day.steps += r.steps;
    if (isModerate(r)) day.moderateMinutes++;
    if (!(r.flags & kCharging)) day.recordedMinutes++;
  }
}

void exportCsv(const MinuteRec* recs, size_t n, int tzMin, Writer& w) {
  w.write("local_time,steps,moderate,angle_change_median_deg,angle_change_max_deg,charging\n");
  char t[40], line[128];
  for (size_t i = 0; i < n; i++) {
    const MinuteRec& r = recs[i];
    formatLocal(r.minute, tzMin, t, sizeof t);
    snprintf(line, sizeof line, "%s,%u,%d,%.2f,%.2f,%d\n", t, (unsigned)r.steps,
             isModerate(r) ? 1 : 0, r.medDiff / 100.0, r.maxDiff / 100.0,
             (r.flags & kCharging) ? 1 : 0);
    w.write(line);
  }
}

void exportFhir(const DaySummary* days, size_t nDays, const Checkin* checkins,
                size_t nCheckins, int tzMin, const char* device, Writer& w) {
  w.write("{\"resourceType\":\"Bundle\",\"type\":\"collection\",\"entry\":[");
  bool first = true;
  char id[48], a[40], b[40], buf[640];
  for (size_t k = 0; k < nDays; k++) {
    const DaySummary& d = days[k];
    formatLocal(d.dayStartMinute, tzMin, a, sizeof a);
    formatLocal(d.dayStartMinute + 1440, tzMin, b, sizeof b);
    char date[11];
    snprintf(date, sizeof date, "%.10s", a);

    snprintf(id, sizeof id, "steps-%s", date);
    obsHeader(w, first, id, kLoinc, "55423-8", "Number of steps", device);
    snprintf(buf, sizeof buf,
             "\"effectivePeriod\":{\"start\":\"%s\",\"end\":\"%s\"},"
             "\"valueQuantity\":{\"value\":%lu,\"unit\":\"steps\","
             "\"system\":\"http://unitsofmeasure.org\",\"code\":\"{steps}\"}}}",
             a, b, (unsigned long)d.steps);
    w.write(buf);

    snprintf(id, sizeof id, "moderate-%s", date);
    obsHeader(w, first, id, kLoinc, "55411-3", "Exercise duration", device);
    snprintf(buf, sizeof buf,
             "\"effectivePeriod\":{\"start\":\"%s\",\"end\":\"%s\"},"
             "\"valueQuantity\":{\"value\":%u,\"unit\":\"min\","
             "\"system\":\"http://unitsofmeasure.org\",\"code\":\"min\"},"
             "\"note\":[{\"text\":\"Minutes with at least 100 steps (moderate cadence). "
             "Recorded minutes: %u.\"}]}}",
             a, b, (unsigned)d.moderateMinutes, (unsigned)d.recordedMinutes);
    w.write(buf);

    if (d.sleep.found) {
      formatLocal(d.sleep.startMinute, tzMin, a, sizeof a);
      formatLocal(d.sleep.endMinute, tzMin, b, sizeof b);
      snprintf(id, sizeof id, "sleep-%s", date);
      obsHeader(w, first, id, kLoinc, "93832-4", "Sleep duration", device);
      snprintf(buf, sizeof buf,
               "\"effectivePeriod\":{\"start\":\"%s\",\"end\":\"%s\"},"
               "\"valueQuantity\":{\"value\":%u,\"unit\":\"min\","
               "\"system\":\"http://unitsofmeasure.org\",\"code\":\"min\"},"
               "\"note\":[{\"text\":\"Estimate from wrist movement; the period is the "
               "main sleep window.\"}]}}",
               a, b, (unsigned)d.sleep.sleepMinutes);
      w.write(buf);
    }
  }
  static const char* kStatus[] = {"done", "partial", "not-today"};
  for (size_t k = 0; k < nCheckins; k++) {
    const Checkin& c = checkins[k];
    formatLocal(c.minute, tzMin, a, sizeof a);
    snprintf(id, sizeof id, "checkin-%lu", (unsigned long)c.minute);
    obsHeader(w, first, id, "urn:bloomback:codes", "habit-checkin", "Daily habit check-in",
              device);
    snprintf(buf, sizeof buf,
             "\"effectiveDateTime\":\"%s\",\"valueCodeableConcept\":{\"coding\":[{"
             "\"system\":\"urn:bloomback:checkin\",\"code\":\"%s\"}]}}}",
             a, kStatus[c.status > 2 ? 2 : c.status]);
    w.write(buf);
  }
  w.write("]}\n");
}

}  // namespace bb
