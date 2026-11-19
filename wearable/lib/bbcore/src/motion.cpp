#include "motion.h"

#include <math.h>
#include <string.h>

namespace bb {

namespace {
constexpr float kPeakThreshold = 0.10f;  // g above the slow average
constexpr uint32_t kMinStepMs = 250;     // faster than 4 steps/s is not walking
constexpr uint32_t kMaxStepMs = 2000;    // slower than 0.5 steps/s breaks the run
constexpr int kRunToConfirm = 4;
constexpr float kPi = 3.14159265f;
}  // namespace

int StepCounter::add(uint32_t tMs, float ax, float ay, float az) {
  float mag = sqrtf(ax * ax + ay * ay + az * az);
  if (!started_) {
    slow_ = mag;
    started_ = true;
    lastMs_ = tMs;
  }
  // Time-based filters, so any sample rate from ~10 to 50 Hz behaves the same.
  float dt = (tMs - lastMs_) / 1000.0f;
  lastMs_ = tMs;
  if (dt <= 0.0f || dt > 0.5f) dt = 0.04f;
  float aSlow = 1.0f - expf(-dt / 2.0f);     // ~2 s: gravity and posture
  float aFast = 1.0f - expf(-dt / 0.09f);    // ~0.09 s: removes jitter
  slow_ += aSlow * (mag - slow_);
  smooth_ += aFast * ((mag - slow_) - smooth_);

  int added = 0;
  // A peak is the previous sample: higher than both neighbours and the threshold.
  bool peak = prev1_ > prev2_ && prev1_ >= smooth_ && prev1_ > kPeakThreshold;
  if (peak) {
    if (!havePeak_) {
      havePeak_ = true;
      lastPeakMs_ = tMs;
      run_ = 1;
    } else {
      uint32_t dt = tMs - lastPeakMs_;
      if (dt < kMinStepMs) {
        // Bounce inside one step: ignore, keep the earlier peak.
      } else if (dt <= kMaxStepMs) {
        lastPeakMs_ = tMs;
        run_++;
        if (run_ == kRunToConfirm) {
          added = kRunToConfirm;
        } else if (run_ > kRunToConfirm) {
          added = 1;
        }
      } else {
        lastPeakMs_ = tMs;
        run_ = 1;
      }
    }
  }
  if (havePeak_ && run_ > 0 && tMs - lastPeakMs_ > kMaxStepMs) run_ = 0;

  prev2_ = prev1_;
  prev1_ = smooth_;
  total_ += added;
  return added;
}

void AngleTracker::add(uint32_t tMs, float ax, float ay, float az) {
  if (!epochOpen_) {
    epochOpen_ = true;
    epochStartMs_ = tMs;
  } else if (tMs - epochStartMs_ >= 5000) {
    closeEpoch();
    epochOpen_ = true;
    epochStartMs_ = tMs;
  }
  float horiz = sqrtf(ax * ax + ay * ay);
  float angle = atan2f(az, horiz) * 180.0f / kPi;  // -90..90 degrees
  sum_ += angle;
  n_++;
}

void AngleTracker::closeEpoch() {
  if (n_ == 0) return;
  float angle = (float)(sum_ / n_);
  sum_ = 0;
  n_ = 0;
  if (havePrev_ && nDiffs_ < kMaxDiffs) {
    float d = fabsf(angle - prevAngle_) * 100.0f;
    if (d > 65535.0f) d = 65535.0f;
    diffs_[nDiffs_++] = (uint16_t)(d + 0.5f);
  }
  prevAngle_ = angle;
  havePrev_ = true;
}

bool AngleTracker::takeMinute(uint16_t& medDiff, uint16_t& maxDiff) {
  if (nDiffs_ == 0) {
    medDiff = maxDiff = 0;
    return false;
  }
  uint16_t s[kMaxDiffs];
  memcpy(s, diffs_, sizeof(uint16_t) * nDiffs_);
  for (int i = 1; i < nDiffs_; i++) {  // insertion sort, at most 16 items
    uint16_t v = s[i];
    int j = i - 1;
    while (j >= 0 && s[j] > v) {
      s[j + 1] = s[j];
      j--;
    }
    s[j + 1] = v;
  }
  medDiff = s[nDiffs_ / 2];
  maxDiff = s[nDiffs_ - 1];
  nDiffs_ = 0;
  return true;
}

}  // namespace bb
