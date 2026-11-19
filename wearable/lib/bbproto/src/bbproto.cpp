#include "bbproto.h"

#include <stdio.h>
#include <string.h>

namespace bbproto {

namespace {

const char* skipSpaces(const char* p) {
  while (*p == ' ' || *p == '\t') p++;
  return p;
}

// Strict decimal integer: optional '-', 1..10 digits, nothing else.
bool parseLong(const char*& p, long long& out) {
  bool neg = false;
  if (*p == '-') {
    neg = true;
    p++;
  }
  if (*p < '0' || *p > '9') return false;
  long long v = 0;
  int digits = 0;
  while (*p >= '0' && *p <= '9') {
    if (++digits > 10) return false;
    v = v * 10 + (*p - '0');
    p++;
  }
  out = neg ? -v : v;
  return true;
}

// A whole argument string that is exactly one integer (surrounding spaces allowed).
bool argInt(const char*& p, long long& out) {
  p = skipSpaces(p);
  if (!parseLong(p, out)) return false;
  if (*p != '\0' && *p != ' ' && *p != '\t') return false;
  return true;
}

// ---------- JSON (one flat object) ----------

struct Json {
  const char* p;
  void ws() {
    while (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n') p++;
  }
  static int hex(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
  }
  bool hex4(uint32_t& v) {
    v = 0;
    for (int i = 0; i < 4; i++) {
      int h = hex(p[i]);
      if (h < 0) return false;
      v = (v << 4) | (uint32_t)h;
    }
    p += 4;
    return true;
  }
  static size_t putUtf8(uint32_t cp, char* out) {
    if (cp < 0x80) {
      out[0] = (char)cp;
      return 1;
    }
    if (cp < 0x800) {
      out[0] = (char)(0xC0 | (cp >> 6));
      out[1] = (char)(0x80 | (cp & 0x3F));
      return 2;
    }
    if (cp < 0x10000) {
      out[0] = (char)(0xE0 | (cp >> 12));
      out[1] = (char)(0x80 | ((cp >> 6) & 0x3F));
      out[2] = (char)(0x80 | (cp & 0x3F));
      return 3;
    }
    out[0] = (char)(0xF0 | (cp >> 18));
    out[1] = (char)(0x80 | ((cp >> 12) & 0x3F));
    out[2] = (char)(0x80 | ((cp >> 6) & 0x3F));
    out[3] = (char)(0x80 | (cp & 0x3F));
    return 4;
  }
  // Reads a string into out (cap bytes incl. the 0). Text beyond cap is dropped
  // (whole characters only are kept later by cleanUtf8). out may be null to skip.
  bool str(char* out, size_t cap) {
    if (*p != '"') return false;
    p++;
    size_t n = 0;
    auto put = [&](const char* b, size_t k) {
      if (!out) return;
      if (n + k < cap) {
        memcpy(out + n, b, k);
        n += k;
      }
    };
    while (*p != '"') {
      if (*p == '\0') return false;
      if ((unsigned char)*p < 0x20) return false;  // raw control chars are not JSON
      if (*p != '\\') {
        put(p, 1);
        p++;
        continue;
      }
      p++;
      char e = *p++;
      char b[4];
      switch (e) {
        case '"': put("\"", 1); break;
        case '\\': put("\\", 1); break;
        case '/': put("/", 1); break;
        case 'b': case 'f': case 'n': case 'r': case 't': put(" ", 1); break;
        case 'u': {
          uint32_t cp;
          if (!hex4(cp)) return false;
          if (cp >= 0xD800 && cp <= 0xDBFF) {  // surrogate pair
            uint32_t lo;
            if (p[0] != '\\' || p[1] != 'u') return false;
            p += 2;
            if (!hex4(lo) || lo < 0xDC00 || lo > 0xDFFF) return false;
            cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
          } else if (cp >= 0xDC00 && cp <= 0xDFFF) {
            return false;
          }
          put(b, putUtf8(cp, b));
          break;
        }
        default:
          return false;
      }
    }
    p++;
    if (out) out[n] = '\0';
    return true;
  }
  bool integer(long long& v) {
    if (!parseLong(p, v)) return false;
    // No fractions or exponents: settings are whole minutes.
    return !(*p == '.' || *p == 'e' || *p == 'E');
  }
  bool literal(const char* w) {
    size_t k = strlen(w);
    if (strncmp(p, w, k) != 0) return false;
    p += k;
    return true;
  }
  // Skips a scalar value of a key we do not know (forward compatible).
  bool skipValue() {
    if (*p == '"') return str(nullptr, 0);
    if (literal("true") || literal("false") || literal("null")) return true;
    if (*p == '-' || (*p >= '0' && *p <= '9')) {
      if (*p == '-') p++;
      if (*p < '0' || *p > '9') return false;
      while ((*p >= '0' && *p <= '9') || *p == '.' || *p == 'e' || *p == 'E' || *p == '+' ||
             *p == '-')
        p++;
      return true;
    }
    return false;  // nested objects/arrays are not part of v1
  }
};

struct CountVisitor : RecordVisitor {
  bb::Writer& w;
  uint32_t count = 0;
  explicit CountVisitor(bb::Writer& out) : w(out) {}
  void minute(const bb::MinuteRec& r) override {
    char line[64];
    snprintf(line, sizeof line, "M %lu %u %u %u %u\n", (unsigned long)r.minute,
             (unsigned)r.steps, (unsigned)r.medDiff, (unsigned)r.maxDiff, (unsigned)r.flags);
    w.write(line);
    count++;
  }
  void checkin(const bb::Checkin& c) override {
    char line[32];
    snprintf(line, sizeof line, "C %lu %u\n", (unsigned long)c.minute, (unsigned)c.status);
    w.write(line);
    count++;
  }
};

// Drops the first write (the CSV header) so one header covers all rows.
struct SkipFirst : bb::Writer {
  bb::Writer& w;
  bool skipped = false;
  explicit SkipFirst(bb::Writer& out) : w(out) {}
  void write(const char* s) override {
    if (!skipped) {
      skipped = true;
      return;
    }
    w.write(s);
  }
};

struct CsvVisitor : RecordVisitor {
  bb::Writer& w;
  int tz;
  CsvVisitor(bb::Writer& out, int tzMin) : w(out), tz(tzMin) {}
  void minute(const bb::MinuteRec& r) override {
    SkipFirst s(w);
    bb::exportCsv(&r, 1, tz, s);
  }
  void checkin(const bb::Checkin&) override {}
};

void err(bb::Writer& out, const char* reason) {
  out.write("ERR ");
  out.write(reason);
  out.write("\n");
}

void cmdInfo(BandHost& host, bb::Writer& out) {
  Settings s;
  host.getSettings(s);
  uint32_t first = 0, last = 0;
  if (!host.dataRange(first, last)) first = last = 0;
  char line[kMaxLine];
  snprintf(line, sizeof line,
           "INFO {\"fw\":\"%s\",\"board\":\"%s\",\"battery\":%d,\"days\":%lu,"
           "\"time_valid\":%s,\"first_minute\":%lu,\"last_minute\":%lu,\"tz\":%d}\n",
           kFirmwareVersion, host.board(), host.battery(), (unsigned long)host.daysStored(),
           host.timeValid() ? "true" : "false", (unsigned long)first, (unsigned long)last,
           (int)s.tz);
  out.write(line);
}

}  // namespace

int utf8Length(const char* s) {
  int n = 0;
  for (const unsigned char* p = (const unsigned char*)s; *p; p++)
    if ((*p & 0xC0) != 0x80) n++;
  return n;
}

void cleanUtf8(char* s, int maxChars) {
  const unsigned char* in = (const unsigned char*)s;
  char* out = s;
  int chars = 0;
  while (*in && chars < maxChars) {
    unsigned char c = *in;
    int len = 0;
    uint32_t cp = 0;
    if (c < 0x80) {
      len = 1;
      cp = c;
    } else if ((c & 0xE0) == 0xC0) {
      len = 2;
      cp = c & 0x1F;
    } else if ((c & 0xF0) == 0xE0) {
      len = 3;
      cp = c & 0x0F;
    } else if ((c & 0xF8) == 0xF0) {
      len = 4;
      cp = c & 0x07;
    }
    bool ok = len > 0;
    for (int i = 1; ok && i < len; i++) {
      if ((in[i] & 0xC0) != 0x80) ok = false;
      else cp = (cp << 6) | (in[i] & 0x3F);
    }
    if (ok) {  // reject overlong forms, surrogates and out-of-range code points
      static const uint32_t kMin[5] = {0, 0, 0x80, 0x800, 0x10000};
      if (cp < kMin[len] || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF)) ok = false;
    }
    if (!ok) {
      *out++ = '?';
      in++;
    } else if (cp < 0x20 || cp == 0x7F) {
      *out++ = ' ';
      in++;
    } else {
      for (int i = 0; i < len; i++) *out++ = (char)in[i];
      in += len;
    }
    chars++;
  }
  *out = '\0';
}

bool parseConfig(const char* json, Settings& s) {
  Settings t = s;
  Json j{json};
  j.ws();
  if (*j.p != '{') return false;
  j.p++;
  j.ws();
  if (*j.p == '}') {
    j.p++;
  } else {
    for (;;) {
      char key[17];
      if (!j.str(key, sizeof key)) return false;
      j.ws();
      if (*j.p != ':') return false;
      j.p++;
      j.ws();
      int16_t* field = nullptr;
      long long lo = -1;
      if (!strcmp(key, "r1")) field = &t.r1;
      else if (!strcmp(key, "r2")) field = &t.r2;
      else if (!strcmp(key, "qs")) field = &t.qs;
      else if (!strcmp(key, "qe")) field = &t.qe;
      else if (!strcmp(key, "de")) {
        field = &t.de;
        lo = 0;  // the day end cannot be off
      }
      if (field) {
        long long v;
        if (!j.integer(v) || v < lo || v > 1439) return false;
        *field = (int16_t)v;
      } else if (!strcmp(key, "habit")) {
        char tmp[kMaxLine];
        if (!j.str(tmp, sizeof tmp)) return false;
        cleanUtf8(tmp, kHabitMaxChars);
        // Trim spaces at both ends.
        char* a = tmp;
        while (*a == ' ') a++;
        size_t n = strlen(a);
        while (n > 0 && a[n - 1] == ' ') a[--n] = '\0';
        if (n == 0) return false;
        memcpy(t.habit, a, n + 1);
      } else if (!j.skipValue()) {
        return false;
      }
      j.ws();
      if (*j.p == ',') {
        j.p++;
        j.ws();
        continue;
      }
      if (*j.p == '}') {
        j.p++;
        break;
      }
      return false;
    }
  }
  j.ws();
  if (*j.p != '\0') return false;
  s = t;
  return true;
}

void handleLine(const char* raw, BandHost& host, bb::Writer& out) {
  size_t n = strlen(raw);
  if (n >= kMaxLine) {  // no room for the '\n' within 200 bytes
    err(out, "args");
    return;
  }
  char line[kMaxLine];
  memcpy(line, raw, n + 1);
  while (n > 0 && (line[n - 1] == '\r' || line[n - 1] == ' ' || line[n - 1] == '\t'))
    line[--n] = '\0';
  const char* p = skipSpaces(line);
  if (*p == '\0') return;

  char cmd[12];
  size_t k = 0;
  while (*p && *p != ' ' && *p != '\t') {
    if (k + 1 >= sizeof cmd) {
      err(out, "unknown");
      return;
    }
    cmd[k++] = *p++;
  }
  cmd[k] = '\0';
  const char* args = skipSpaces(p);

  if (!strcmp(cmd, "info")) {
    if (*args) return err(out, "args");
    cmdInfo(host, out);
  } else if (!strcmp(cmd, "time")) {
    long long utc, tz;
    const char* q = args;
    if (!argInt(q, utc) || !argInt(q, tz) || *skipSpaces(q) != '\0') return err(out, "args");
    if (utc < (long long)kMinValidUtc || utc >= (long long)kMaxValidUtc || tz < kMinTz ||
        tz > kMaxTz)
      return err(out, "args");
    host.setTime((uint32_t)utc, (int16_t)tz);
    out.write("OK time\n");
  } else if (!strcmp(cmd, "config")) {
    Settings s;
    host.getSettings(s);
    if (!parseConfig(args, s)) return err(out, "args");
    host.setSettings(s);
    out.write("OK config\n");
  } else if (!strcmp(cmd, "sync")) {
    long long since;
    const char* q = args;
    if (!argInt(q, since) || *skipSpaces(q) != '\0' || since < 0 || since > 0xFFFFFFFFLL)
      return err(out, "args");
    if (host.busy()) return err(out, "busy");
    out.write("BEGIN sync\n");
    CountVisitor v(out);
    host.visitMinutes((uint32_t)since, v);
    host.visitCheckins((uint32_t)since, v);
    char end[32];
    snprintf(end, sizeof end, "END sync %lu\n", (unsigned long)v.count);
    out.write(end);
  } else if (!strcmp(cmd, "export")) {
    bool json = !strcmp(args, "json");
    if (!json && strcmp(args, "csv") != 0) return err(out, "args");
    if (host.busy()) return err(out, "busy");
    if (json) {
      out.write("BEGIN json\n");
      host.exportJson(out);
    } else {
      Settings s;
      host.getSettings(s);
      out.write("BEGIN csv\n");
      bb::exportCsv(nullptr, 0, s.tz, out);  // header line only
      CsvVisitor v(out, s.tz);
      host.visitMinutes(0, v);
    }
    out.write("END\n");
  } else if (!strcmp(cmd, "delete")) {
    if (strcmp(args, "yes") != 0) return err(out, "args");
    if (host.busy()) return err(out, "busy");
    host.deleteAll();
    out.write("OK deleted\n");
  } else {
    err(out, "unknown");
  }
}

void LineReader::feed(const char* data, size_t n, BandHost& host, bb::Writer& out) {
  for (size_t i = 0; i < n; i++) {
    char c = data[i];
    if (c == '\n') {
      if (overflow_) {
        err(out, "args");
      } else {
        buf_[len_] = '\0';
        handleLine(buf_, host, out);
      }
      len_ = 0;
      overflow_ = false;
    } else if (c == '\0') {
      continue;
    } else if (overflow_) {
      continue;
    } else if (len_ + 1 >= kMaxLine) {  // the line with its '\n' would pass 200 bytes
      overflow_ = true;
    } else {
      buf_[len_++] = c;
    }
  }
}

}  // namespace bbproto
