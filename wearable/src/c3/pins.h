// ESP32-C3 "SuperMini" style board with the 0.42" OLED (72x40, SSD1306) on board.
// Every pin can be changed with a -D build flag. NOT yet checked on a real board.
#pragma once

#ifndef BB_SDA
#define BB_SDA 5          // I2C data: OLED (on board) + MPU6050
#endif
#ifndef BB_SCL
#define BB_SCL 6          // I2C clock
#endif
#ifndef BB_BTN
#define BB_BTN 9          // BOOT button, active low (the only button)
#endif
#ifndef BB_MPU_ADDR
#define BB_MPU_ADDR 0x68  // MPU6050 with AD0 low (GY-521 default)
#endif
#ifndef BB_I2C_HZ
#define BB_I2C_HZ 400000
#endif

// Optional (not defined = not fitted):
//   BB_VIBE_PIN     vibration motor through an NPN/MOSFET, active high
//   BB_BAT_PIN      ADC pin on a resistor divider from the LiPo (+ BB_BAT_DIVIDER)
//   BB_CHG_PIN      charger module's CHRG output (open drain, low while charging)
#if defined(BB_BAT_PIN) && !defined(BB_BAT_DIVIDER)
#define BB_BAT_DIVIDER 2.0f  // 100k/100k divider: pin sees half the battery voltage
#endif
