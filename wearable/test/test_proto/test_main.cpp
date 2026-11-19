// Protocol tests (docs/PROTOCOL.md) with a fake band host: pio test -e native
#include <string.h>
#include <unity.h>

#include <string>
#include <vector>

#include "bbproto.h"

using namespace bbproto;

struct StrWriter : bb::Writer {
  std::string s;
  void write(const char* x) override { s += x; }
};

struct FakeHost : BandHost {
  Settings settings;
  bool valid = false;
  uint32_t utc = 0;
  int battery_ = -1;
  bool busy_ = false;
  int deletes = 0;
  std::vector<bb::MinuteRec> mins;
  std::vector<bb::Checkin> cks;

  const char* board() override { return "c3-oled"; }
  int battery() override { return battery_; }
  bool timeValid() override { return valid; }
  void setTime(uint32_t s, int16_t tz) override {
    utc = s;
    settings.tz = tz;
    valid = true;
  }
  void getSettings(Settings& s) override { s = settings; }
  void setSettings(const Settings& s) override { settings = s; }
  uint32_t daysStored() override { return mins.empty() ? 0 : 3; }
  bool dataRange(uint32_t& a, uint32_t& b) override {
    if (mins.empty()) return false;
    a = mins.front().minute;
    b = mins.back().minute;
    return true;
  }
  void visitMinutes(uint32_t since, RecordVisitor& v) override {
    for (auto& r : mins)
      if (r.minute > since) v.minute(r);
  }
  void visitCheckins(uint32_t since, RecordVisitor& v) override {
    for (auto& c : cks)
      if (c.minute > since) v.checkin(c);
  }
  void exportJson(bb::Writer& w) override { w.write("{\"resourceType\":\"Bundle\"}\n"); }
  void deleteAll() override {
    deletes++;
    mins.clear();
    cks.clear();
  }
  bool busy() override { return busy_; }
};

static std::string run(FakeHost& h, const char* line) {
  StrWriter w;
  handleLine(line, h, w);
  return w.s;
}

static void addData(FakeHost& h) {
  h.mins.push_back({29910000, 0, 120, 900, 1});
  h.mins.push_back({29914200, 104, 312, 1450, 0});
  h.mins.push_back({29914320, 7, 20, 40, 0});
  h.cks.push_back({29914230, 1});
}

void setUp() {}
void tearDown() {}

void test_info_shape() {
  FakeHost h;
  addData(h);
  h.valid = true;
  h.battery_ = 87;
  h.settings.tz = 420;
  TEST_ASSERT_EQUAL_STRING(
      "INFO {\"fw\":\"0.2.0\",\"board\":\"c3-oled\",\"battery\":87,\"days\":3,"
      "\"time_valid\":true,\"first_minute\":29910000,\"last_minute\":29914320,\"tz\":420}\n",
      run(h, "info").c_str());
}

void test_info_empty_band() {
  FakeHost h;
  std::string s = run(h, "info");
  TEST_ASSERT_NOT_NULL(strstr(s.c_str(), "\"battery\":-1"));
  TEST_ASSERT_NOT_NULL(strstr(s.c_str(), "\"time_valid\":false"));
  TEST_ASSERT_NOT_NULL(strstr(s.c_str(), "\"first_minute\":0,\"last_minute\":0"));
  TEST_ASSERT_TRUE(s.size() <= kMaxLine);
  TEST_ASSERT_EQUAL_STRING("ERR args\n", run(h, "info now").c_str());
}

void test_time() {
  FakeHost h;
  TEST_ASSERT_EQUAL_STRING("OK time\n", run(h, "time 1794528000 420").c_str());
  TEST_ASSERT_TRUE(h.valid);
  TEST_ASSERT_EQUAL_UINT32(1794528000u, h.utc);
  TEST_ASSERT_EQUAL(420, h.settings.tz);
  TEST_ASSERT_EQUAL_STRING("OK time\n", run(h, "time 1794528000 -300\r").c_str());
  TEST_ASSERT_EQUAL(-300, h.settings.tz);

  FakeHost b;
  TEST_ASSERT_EQUAL_STRING("ERR args\n", run(b, "time").c_str());
  TEST_ASSERT_EQUAL_STRING("ERR args\n", run(b, "time 1794528000").c_str());
  TEST_ASSERT_EQUAL_STRING("ERR args\n", run(b, "time abc 420").c_str());
  TEST_ASSERT_EQUAL_STRING("ERR args\n", run(b, "time 1794528000 420 9").c_str());
  TEST_ASSERT_EQUAL_STRING("ERR args\n", run(b, "time 1794528000.5 420").c_str());
  TEST_ASSERT_EQUAL_STRING("ERR args\n", run(b, "time 1000 420").c_str());       // 1970
  TEST_ASSERT_EQUAL_STRING("ERR args\n", run(b, "time 1794528000 900").c_str());  // tz +15h
  TEST_ASSERT_FALSE(b.valid);
}

void test_config_partial_update() {
  FakeHost h;
  Settings before = h.settings;
  TEST_ASSERT_EQUAL_STRING("OK config\n", run(h, "config {\"r1\":480, \"habit\":\"Walk 10 min\"}").c_str());
  TEST_ASSERT_EQUAL(480, h.settings.r1);
  TEST_ASSERT_EQUAL_STRING("Walk 10 min", h.settings.habit);
  TEST_ASSERT_EQUAL(before.r2, h.settings.r2);
  TEST_ASSERT_EQUAL(before.qs, h.settings.qs);
  TEST_ASSERT_EQUAL(before.qe, h.settings.qe);
  TEST_ASSERT_EQUAL(before.de, h.settings.de);

  // Full example from PROTOCOL.md, with -1 = off and an unknown key ignored.
  TEST_ASSERT_EQUAL_STRING(
      "OK config\n",
      run(h, "config {\"habit\":\"Ng\xe1\xbb\xa7 s\xe1\xbb\x9bm 15'\",\"r1\":-1,\"r2\":1200,"
             "\"qs\":1320,\"qe\":360,\"de\":1080,\"future\":true}")
          .c_str());
  TEST_ASSERT_EQUAL_STRING("Ng\xe1\xbb\xa7 s\xe1\xbb\x9bm 15'", h.settings.habit);
  TEST_ASSERT_EQUAL(-1, h.settings.r1);
  TEST_ASSERT_EQUAL(1200, h.settings.r2);
  TEST_ASSERT_EQUAL(1320, h.settings.qs);
  TEST_ASSERT_EQUAL(360, h.settings.qe);
  TEST_ASSERT_EQUAL(1080, h.settings.de);
  TEST_ASSERT_EQUAL_STRING("OK config\n", run(h, "config {}").c_str());
}

void test_config_habit_utf8_truncation() {
  FakeHost h;
  // 30 x "ủ" (3 bytes each) -> cut to 24 whole characters.
  std::string habit;
  for (int i = 0; i < 30; i++) habit += "\xe1\xbb\xa7";
  std::string cmd = "config {\"habit\":\"" + habit + "\"}";
  TEST_ASSERT_EQUAL_STRING("OK config\n", run(h, cmd.c_str()).c_str());
  TEST_ASSERT_EQUAL(24, utf8Length(h.settings.habit));
  TEST_ASSERT_EQUAL(72, (int)strlen(h.settings.habit));

  // \u escapes (including a surrogate pair) become UTF-8; control chars become spaces.
  TEST_ASSERT_EQUAL_STRING(
      "OK config\n", run(h, "config {\"habit\":\"Ng\\u1ee7 \\ud83c\\udf19\\tx \\\"y\\\"\"}").c_str());
  TEST_ASSERT_EQUAL_STRING("Ng\xe1\xbb\xa7 \xf0\x9f\x8c\x99 x \"y\"", h.settings.habit);

  // Invalid UTF-8 bytes are replaced, not passed to the screen.
  char bad[] = "ab\xff\xe1\xbb";
  cleanUtf8(bad, 24);
  TEST_ASSERT_EQUAL_STRING("ab???", bad);
}

void test_config_errors_leave_settings() {
  FakeHost h;
  Settings before = h.settings;
  const char* bad[] = {
      "config",
      "config {",
      "config {\"r1\":480",
      "config {\"r1\":480,}",
      "config {\"r1\":1440}",
      "config {\"r1\":-2}",
      "config {\"de\":-1}",
      "config {\"r1\":\"480\"}",
      "config {\"r1\":4.5}",
      "config {\"habit\":\"\"}",
      "config {\"habit\":\"   \"}",
      "config {\"habit\":12}",
      "config {\"x\":[1,2]}",
      "config {\"r2\":600,\"r1\":99999}",  // first key fine, second bad: nothing changes
      "config {\"r1\":480} x",
      "config [1]",
  };
  for (const char* b : bad) {
    std::string s = run(h, b);
    TEST_ASSERT_EQUAL_STRING_MESSAGE("ERR args\n", s.c_str(), b);
  }
  TEST_ASSERT_EQUAL(before.r1, h.settings.r1);
  TEST_ASSERT_EQUAL(before.r2, h.settings.r2);
  TEST_ASSERT_EQUAL_STRING(before.habit, h.settings.habit);
}

void test_sync_cursor() {
  FakeHost h;
  addData(h);
  TEST_ASSERT_EQUAL_STRING(
      "BEGIN sync\n"
      "M 29910000 0 120 900 1\n"
      "M 29914200 104 312 1450 0\n"
      "M 29914320 7 20 40 0\n"
      "C 29914230 1\n"
      "END sync 4\n",
      run(h, "sync 0").c_str());
  // Strictly after: the record at exactly since is not sent again.
  TEST_ASSERT_EQUAL_STRING(
      "BEGIN sync\n"
      "M 29914320 7 20 40 0\n"
      "C 29914230 1\n"
      "END sync 2\n",
      run(h, "sync 29914200").c_str());
  TEST_ASSERT_EQUAL_STRING("BEGIN sync\nEND sync 0\n", run(h, "sync 29914320").c_str());
  TEST_ASSERT_EQUAL_STRING("ERR args\n", run(h, "sync").c_str());
  TEST_ASSERT_EQUAL_STRING("ERR args\n", run(h, "sync -5").c_str());
  TEST_ASSERT_EQUAL_STRING("ERR args\n", run(h, "sync 12x").c_str());
  TEST_ASSERT_EQUAL_STRING("ERR args\n", run(h, "sync 1 2").c_str());
  h.busy_ = true;
  TEST_ASSERT_EQUAL_STRING("ERR busy\n", run(h, "sync 0").c_str());
}

void test_export() {
  FakeHost h;
  addData(h);
  h.settings.tz = 240;
  std::string csv = run(h, "export csv");
  TEST_ASSERT_EQUAL(0, (int)csv.find("BEGIN csv\nlocal_time,steps,"));
  TEST_ASSERT_EQUAL(1, (int)(csv.find("local_time") == csv.rfind("local_time")));  // one header
  TEST_ASSERT_NOT_NULL(strstr(csv.c_str(), ",104,1,3.12,14.50,0\n"));
  TEST_ASSERT_EQUAL_STRING("END\n", csv.c_str() + csv.size() - 4);
  TEST_ASSERT_EQUAL_STRING("BEGIN json\n{\"resourceType\":\"Bundle\"}\nEND\n",
                           run(h, "export json").c_str());
  TEST_ASSERT_EQUAL_STRING("ERR args\n", run(h, "export").c_str());
  TEST_ASSERT_EQUAL_STRING("ERR args\n", run(h, "export xml").c_str());
}

void test_delete() {
  FakeHost h;
  addData(h);
  TEST_ASSERT_EQUAL_STRING("ERR args\n", run(h, "delete").c_str());
  TEST_ASSERT_EQUAL_STRING("ERR args\n", run(h, "delete no").c_str());
  TEST_ASSERT_EQUAL(0, h.deletes);
  TEST_ASSERT_EQUAL_STRING("OK deleted\n", run(h, "delete yes").c_str());
  TEST_ASSERT_EQUAL(1, h.deletes);
  TEST_ASSERT_EQUAL_STRING("BEGIN sync\nEND sync 0\n", run(h, "sync 0").c_str());
}

void test_unknown_and_empty() {
  FakeHost h;
  TEST_ASSERT_EQUAL_STRING("ERR unknown\n", run(h, "hello").c_str());
  TEST_ASSERT_EQUAL_STRING("ERR unknown\n", run(h, "INFO").c_str());
  TEST_ASSERT_EQUAL_STRING("ERR unknown\n", run(h, "status").c_str());
  TEST_ASSERT_EQUAL_STRING("ERR unknown\n", run(h, "averyveryverylongcommand x").c_str());
  TEST_ASSERT_EQUAL_STRING("", run(h, "").c_str());
  TEST_ASSERT_EQUAL_STRING("", run(h, "  \r").c_str());
  TEST_ASSERT_EQUAL_STRING("OK time\n", run(h, "  time   1794528000   420  ").c_str());
}

void test_line_limit_and_reader() {
  FakeHost h;
  // 199 bytes + '\n' = 200: allowed (answered as a normal command).
  std::string ok = "config {\"habit\":\"" + std::string(199 - 19, 'a') + "\"}";
  TEST_ASSERT_EQUAL(199, (int)ok.size());
  TEST_ASSERT_EQUAL_STRING("OK config\n", run(h, ok.c_str()).c_str());
  TEST_ASSERT_EQUAL(24, (int)strlen(h.settings.habit));
  std::string tooLong = ok + "a";
  TEST_ASSERT_EQUAL_STRING("ERR args\n", run(h, tooLong.c_str()).c_str());

  // Bytes arriving in pieces (BLE writes), CRLF, and recovery after an overlong line.
  LineReader rd;
  StrWriter w;
  const char* a = "inf";
  const char* b = "o\r\ntime 1794528000 4";
  const char* c = "20\n";
  rd.feed(a, strlen(a), h, w);
  TEST_ASSERT_EQUAL_STRING("", w.s.c_str());
  rd.feed(b, strlen(b), h, w);
  rd.feed(c, strlen(c), h, w);
  TEST_ASSERT_EQUAL(0, (int)w.s.find("INFO {"));
  TEST_ASSERT_NOT_NULL(strstr(w.s.c_str(), "}\nOK time\n"));

  StrWriter w2;
  std::string flood(500, 'x');
  flood += "\ninfo\n";
  rd.feed(flood.data(), flood.size(), h, w2);
  TEST_ASSERT_EQUAL(0, (int)w2.s.find("ERR args\nINFO {"));
}

int main() {
  UNITY_BEGIN();
  RUN_TEST(test_info_shape);
  RUN_TEST(test_info_empty_band);
  RUN_TEST(test_time);
  RUN_TEST(test_config_partial_update);
  RUN_TEST(test_config_habit_utf8_truncation);
  RUN_TEST(test_config_errors_leave_settings);
  RUN_TEST(test_sync_cursor);
  RUN_TEST(test_export);
  RUN_TEST(test_delete);
  RUN_TEST(test_unknown_and_empty);
  RUN_TEST(test_line_limit_and_reader);
  return UNITY_END();
}
