// Turns raw accelerometer samples (in g) into steps and arm-angle changes.
#pragma once
#include <stdint.h>

namespace bb {

// Peak-based step counter for a wrist accelerometer.
// Steps are only counted once 4 regular peaks in a row are seen, so a single
// arm movement or a tap on the desk does not add steps.
class StepCounter {
 public:
  // Returns how many new steps this sample confirmed (usually 0 or 1,
  // or 4 when a walking run is first confirmed).
  int add(uint32_t tMs, float ax, float ay, float az);
  uint32_t total() const { return total_; }

 private:
  bool started_ = false;
  float slow_ = 1.0f;     // slow average of |a| (gravity + posture)
  float smooth_ = 0.0f;   // smoothed dynamic part
  float prev1_ = 0.0f, prev2_ = 0.0f;
  uint32_t lastPeakMs_ = 0;
  uint32_t lastMs_ = 0;
  bool havePeak_ = false;
  int run_ = 0;           // regular peaks in the current run
  uint32_t total_ = 0;
};

// Arm-angle tracker used for sleep detection (van Hees et al. 2015, 2018):
// z-angle averaged per 5 s epoch, then the absolute change between epochs.
class AngleTracker {
 public:
  void add(uint32_t tMs, float ax, float ay, float az);
  // Closes the current minute. Returns false if no epoch changes were seen.
  bool takeMinute(uint16_t& medDiffCdeg, uint16_t& maxDiffCdeg);

 private:
  static constexpr int kMaxDiffs = 16;
  uint32_t epochStartMs_ = 0;
  bool epochOpen_ = false;
  double sum_ = 0;
  int n_ = 0;
  bool havePrev_ = false;
  float prevAngle_ = 0;
  uint16_t diffs_[kMaxDiffs];
  int nDiffs_ = 0;
  void closeEpoch();
};

}  // namespace bb
