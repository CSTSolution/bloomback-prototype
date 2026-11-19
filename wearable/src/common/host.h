// The protocol host shared by every board: settings in NVS, data in LittleFS.
// A board subclasses it for the battery and the clock.
#pragma once
#include "bbproto.h"
#include "settings.h"
#include "store.h"

#ifndef BB_BOARD
#define BB_BOARD "esp32"
#endif
#ifndef BB_DEVICE_NAME
#define BB_DEVICE_NAME "BloomBack Band"
#endif

class StoreHost : public bbproto::BandHost {
 public:
  const char* board() override { return BB_BOARD; }
  bool timeValid() override { return clockValid; }
  void getSettings(bbproto::Settings& s) override { settingsToProto(s); }
  void setSettings(const bbproto::Settings& s) override {
    settingsFromProto(s);
    saveSettings();
    onSettingsChanged();
  }
  uint32_t daysStored() override { return (uint32_t)storedDays().size(); }
  bool dataRange(uint32_t& first, uint32_t& last) override { return ::dataRange(first, last); }
  void visitMinutes(uint32_t since, bbproto::RecordVisitor& v) override {
    visitMinutesAfter(since, v);
  }
  void visitCheckins(uint32_t since, bbproto::RecordVisitor& v) override {
    visitCheckinsAfter(since, v);
  }
  void exportJson(bb::Writer& w) override { exportFhirAll(w, BB_DEVICE_NAME); }
  void deleteAll() override {
    deleteAllData();
    onDeleted();
  }

 protected:
  virtual void onSettingsChanged() {}
  virtual void onDeleted() {}
};
