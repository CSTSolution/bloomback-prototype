// MPU6050 as a low-power accelerometer: gyro in standby, 25 Hz, DLPF on, samples
// collected in the chip's 1 KB FIFO and read in batches every few seconds.
#pragma once
#include <stdint.h>

namespace imu {

constexpr uint32_t kSampleMs = 40;  // 25 Hz

typedef void (*SampleFn)(uint32_t tMs, float ax, float ay, float az);

// Wire must already be started. Returns false if the MPU6050 does not answer.
bool begin();
bool ok();

// Reads every sample waiting in the FIFO (oldest first) and calls fn with a
// timestamp for each. Returns the number of samples, or -1 after an overflow or
// bus error (the FIFO is reset and the batch is dropped).
int drain(SampleFn fn);

uint32_t overflows();

}  // namespace imu
