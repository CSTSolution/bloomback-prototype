#include "imu.h"

#include <Arduino.h>
#include <Wire.h>

#include "pins.h"

namespace imu {

namespace {

// MPU6050 registers (RM-MPU-6000A-00 rev 4.2).
constexpr uint8_t kSmplrtDiv = 0x19;
constexpr uint8_t kConfig = 0x1A;
constexpr uint8_t kAccelConfig = 0x1C;
constexpr uint8_t kFifoEn = 0x23;
constexpr uint8_t kIntEnable = 0x38;
constexpr uint8_t kIntStatus = 0x3A;
constexpr uint8_t kUserCtrl = 0x6A;
constexpr uint8_t kPwrMgmt1 = 0x6B;
constexpr uint8_t kPwrMgmt2 = 0x6C;
constexpr uint8_t kFifoCountH = 0x72;
constexpr uint8_t kFifoRw = 0x74;
constexpr uint8_t kWhoAmI = 0x75;

constexpr float kLsbPerG = 8192.0f;   // +-4 g
constexpr uint16_t kFifoSize = 1024;
constexpr int kBytesPerSample = 6;     // accel X, Y, Z, big-endian int16
constexpr int kChunkSamples = 20;      // 120 bytes per I2C read (Wire buffer is 128)

bool ok_ = false;
bool haveT_ = false;
uint32_t lastT_ = 0;
uint32_t overflows_ = 0;

bool writeReg(uint8_t reg, uint8_t v) {
  Wire.beginTransmission(BB_MPU_ADDR);
  Wire.write(reg);
  Wire.write(v);
  return Wire.endTransmission() == 0;
}

bool readRegs(uint8_t reg, uint8_t* buf, uint8_t n) {
  Wire.beginTransmission(BB_MPU_ADDR);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom((uint8_t)BB_MPU_ADDR, n) != n) return false;
  for (uint8_t i = 0; i < n; i++) buf[i] = (uint8_t)Wire.read();
  return true;
}

void resetFifo() {
  writeReg(kUserCtrl, 0x04);  // FIFO_RESET (FIFO off while resetting)
  writeReg(kUserCtrl, 0x40);  // FIFO_EN
  uint8_t s;
  readRegs(kIntStatus, &s, 1);  // clear the overflow flag
  haveT_ = false;               // next batch starts a new time base
}

}  // namespace

bool begin() {
  uint8_t who = 0;
  if (!readRegs(kWhoAmI, &who, 1)) return (ok_ = false);
  Serial.printf("MPU6050 WHO_AM_I=0x%02X\n", who);  // 0x68 genuine; clones answer 0x70/0x72/0x98
  writeReg(kPwrMgmt1, 0x80);   // device reset
  delay(100);
  writeReg(kPwrMgmt1, 0x08);   // awake, internal 8 MHz clock, temperature sensor off
  delay(10);
  writeReg(kPwrMgmt2, 0x07);   // gyro X/Y/Z in standby: accelerometer only (~0.5 mA)
  writeReg(kConfig, 0x05);     // DLPF_CFG=5: accel bandwidth 10 Hz (below 12.5 Hz Nyquist)
  writeReg(kSmplrtDiv, 39);    // 1 kHz / (1 + 39) = 25 Hz
  writeReg(kAccelConfig, 0x08);  // AFS_SEL=1: +-4 g (wrist swings pass 2 g)
  writeReg(kIntEnable, 0x10);  // FIFO_OFLOW flag in INT_STATUS (INT pin not wired)
  writeReg(kFifoEn, 0x08);     // ACCEL_FIFO_EN
  resetFifo();
  ok_ = true;
  return true;
}

bool ok() { return ok_; }
uint32_t overflows() { return overflows_; }

int drain(SampleFn fn) {
  if (!ok_) return -1;
  uint8_t b[2];
  uint8_t status = 0;
  if (!readRegs(kIntStatus, &status, 1) || !readRegs(kFifoCountH, b, 2)) return -1;
  uint16_t count = (uint16_t)((b[0] << 8) | b[1]);
  uint32_t now = millis();
  if ((status & 0x10) || count >= kFifoSize || count % kBytesPerSample) {
    // Full (data lost, frames may be split): start again from an empty FIFO.
    overflows_++;
    resetFifo();
    return -1;
  }
  int n = count / kBytesPerSample;
  if (n == 0) return 0;

  // Timestamps: the newest sample was taken about now, samples are ~40 ms apart.
  // Within a run of batches the spacing follows the real rate (the MPU's clock is
  // only ~1-2 % accurate) and time never goes backwards.
  uint32_t step;
  int32_t gap = (int32_t)(now - lastT_);
  if (!haveT_ || gap > (int32_t)(n * kSampleMs * 2 + 500)) {
    lastT_ = now - (uint32_t)n * kSampleMs;
    step = kSampleMs;
  } else {
    step = gap > 0 ? (uint32_t)gap / (uint32_t)n : 0;
    if (step < kSampleMs - 4) step = kSampleMs - 4;
    if (step > kSampleMs + 4) step = kSampleMs + 4;
  }
  haveT_ = true;

  uint8_t buf[kChunkSamples * kBytesPerSample];
  int done = 0;
  while (done < n) {
    int k = n - done < kChunkSamples ? n - done : kChunkSamples;
    if (!readRegs(kFifoRw, buf, (uint8_t)(k * kBytesPerSample))) {
      resetFifo();
      return -1;
    }
    for (int i = 0; i < k; i++) {
      const uint8_t* p = buf + i * kBytesPerSample;
      float ax = (int16_t)((p[0] << 8) | p[1]) / kLsbPerG;
      float ay = (int16_t)((p[2] << 8) | p[3]) / kLsbPerG;
      float az = (int16_t)((p[4] << 8) | p[5]) / kLsbPerG;
      lastT_ += step;
      fn(lastT_, ax, ay, az);
    }
    done += k;
  }
  return n;
}

}  // namespace imu
