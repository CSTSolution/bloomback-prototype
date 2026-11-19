# BloomBack Band: an ESP32 wrist device for BloomBack

Future Health Digital Innovation Challenge (Hack2skill), statement **[Wellness] Sustaining Healthy Behaviors**.
Submission closes **Sat 21 Nov 2026, 01:29 ICT**. The form asks for the challenge, a summary, solution stage, what was built, technology type (it lists *Wearable*, *Sensor*, *Connected device*), a prototype link, a PDF deck on their PPT template (max 5 MB), software/hardware/both, and a public demo video under 3 minutes.

## Does the idea work? Yes, with limits

| Question | Answer |
|---|---|
| Fits the challenge? | Yes. The statement names "wearable data" as a building block and asks for "control over goals, data and notifications". A band that keeps data on the wrist and only hands it over when the user says so is a direct answer. |
| Fits Chi's rules (BloomBack_Nguyen_tac_hoat_dong.pdf)? | Mostly. It measures the two things BB tracks (sleep and movement), labels every number with its source "watch" (B1), stores it as FHIR Observations (B1), does one-tap check-in (C4), max 2 reminders/day with quiet hours (C4), and does not diagnose (principle 1). **Change needed:** A1 says device sync is "later" and "not in the prototype". Chi must agree to add the band as an optional source. |
| What it measures | Steps; **active minutes** (minutes with ≥100 steps, the moderate-intensity cadence from Tudor-Locke et al., BJSM 2018); **main sleep window** (bedtime, wake time, minutes asleep) from wrist angle, adapted from van Hees et al. 2015/2018 (HDCZA); daily check-ins. This gives BB the real "current level" (B4) instead of only self-report, and week-1 vs week-4 numbers (C6). |
| What it does NOT measure | Heart rate, blood pressure, SpO2 (no sensor; and principle 6 says biomarkers never change advice anyway). Sleep stages. Anything medical. Sleep is an **estimate**: wrist methods are good at the sleep window, weaker at telling quiet wake from sleep. |
| Private download | All data stays in the band's flash. The **phone app** (the main BB app) reads it over **Bluetooth LE** after pairing with a 6-digit passkey shown only on the band's screen ([docs/PROTOCOL.md](../docs/PROTOCOL.md)). No cloud, no account. USB serial answers the same commands (flashing, debugging, backup). The M5StickC Plus2 reference build also keeps its own Wi-Fi download page. |
| Risks in 7 days | 1) Getting the board in time (order today, Hanoi stock). 2) Battery: not measured; the C3 band without light sleep is estimated at 15-25 mA, so expect to charge every day (see "Power"). 3) Wearing comfort: a bare board in a case on a strap, fine for a demo, not a product. |

## Board

**Budget: about 200,000 VND per band (Son, 13 Nov). Not bought yet.** Target (13 Nov): **ESP32-C3 SuperMini-style board with the built-in 0.42" OLED + MPU6050 (GY-521) + small LiPo and charger**, firmware env `c3-oled`. The M5StickC Plus2 costs 1.2–3.2M VND in Vietnam and M5Stack has ended it, so it is only the reference build (`m5stickc-plus2`). The core (`lib/bbcore`) and the protocol (`lib/bbproto`) do not depend on the board.

Cheap options:

| Board | Screen | Motion sensor | Notes |
|---|---|---|---|
| LilyGO **T-Display** ESP32 (or clone) | 1.14" colour, 240×135 (same as the Plus2) | none: add an MPU6050 module on I2C | 2 buttons, battery plug with charger, USB-C. About €13 abroad; check Vietnamese shops |
| ESP32 + 0.96" OLED board | 128×64 mono | none: add MPU6050 | Cheapest; tiny text |
| ESP32-C3 with 0.42" OLED | 72×40 mono | none: add MPU6050 | Very small; hard to read |

Also needed: an MPU6050 (or similar) accelerometer module, a small LiPo battery, a strap or case. There is no real-time clock on these boards: the clock is set by the desktop app or the phone page each time the band connects.

## ESP32-C3 band (`c3-oled`)

**Status 2026-11-13: compiles only. Not yet run on hardware** (board not bought). Pins, the OLED offset, NimBLE pairing and power are all unverified; see "Check when the board arrives".

### Wiring

| From | To | Notes |
|---|---|---|
| OLED 0.42" 72×40 (SSD1306) | on the board: SDA GPIO5, SCL GPIO6 | Nothing to wire. Some boards differ: change `BB_SDA`/`BB_SCL` |
| MPU6050 (GY-521) VCC | 3V3 | Not 5V. The GY-521 has its own regulator and pull-ups; 3V3 works |
| MPU6050 GND | GND | |
| MPU6050 SDA | GPIO5 | Same I2C bus as the OLED, address 0x68 (AD0 low or open) |
| MPU6050 SCL | GPIO6 | |
| MPU6050 INT | not connected | The FIFO is read every 2 s by polling |
| Button | BOOT button (GPIO9) on the board | Active low. Holding it while plugging in USB = download mode |
| Vibration motor (optional) | GPIO → 1 kΩ → NPN (e.g. S8050) base; motor between LiPo+ and collector (~60–80 mA, not from the 3V3 LDO); diode (1N4148) across the motor | Build with `-DBB_VIBE_PIN=<gpio>` (e.g. 4) |
| Battery voltage (optional) | LiPo+ → 100 kΩ → ADC pin → 100 kΩ → GND | Build with `-DBB_BAT_PIN=<adc gpio 0-4> -DBB_BAT_DIVIDER=2.0`; without it `battery` is -1 |
| Charging (optional) | TP4056 `CHRG` pin → GPIO (input pull-up) | Build with `-DBB_CHG_PIN=<gpio>`; marks minutes "charging" so they never count as sleep |
| LiPo + charger | charger OUT → board 5V/VBAT pad (per board), GND → GND | Check the board's battery pad; on boards without one, feed 3.7 V LiPo into `5V` (the LDO drops it to 3.3 V) |

Pins are `#define`s in `src/c3/pins.h`; override any of them with `-D` in `build_flags`, or for one build: `PLATFORMIO_BUILD_FLAGS="-DBB_VIBE_PIN=4" pio run -e c3-oled`.

### Buttons (one button)

- **Short press** = wake / next. **Long press (0.7 s)** = action.
- Screen off: any press wakes it (page 1). Screen turns off after 10 s.
- Home pages, short press to move: **time** (+ battery, `BT` = paired phone connected) → **steps today** → **active minutes** (minutes with ≥100 steps) → **last sleep** window → **phone**.
- Long press on any home page = **check-in**: short press changes the answer (✓ Done / ~ Partly / ✗ Not today), long press saves.
- **Reminder** (max 2 a day, never in quiet hours): screen turns on with the habit (+ vibration if fitted). Long press = check-in, short = later.
- **Pairing**: when the phone pairs, the band shows a 6-digit code in big digits; type it on the phone.
- **Phone page**: long press → "Unpair?" → long press = forget the phone (short = no).
- Before the app has set the clock the time page says "Open the BloomBack app to start" and nothing is recorded.

### Flash


```bash
pio run -e c3-oled -t upload     # USB-C; if no port appears, hold BOOT while plugging in, then retry
pio device monitor               # USB serial: type "info" + Enter
```

First boot formats LittleFS (a few seconds). The band advertises as `BloomBack-XXXX`.

### Demo mirror (USB only)

USB serial also answers `screen` with `SCREEN <1|0> <720 hex digits>`: the 72x40 frame buffer (5 pages x 72 bytes, each byte 8 pixels down, lowest bit on top). Not on BLE (longer than a protocol line). `python tools/mirror.py COM5` shows the screen 12x larger at http://localhost:8765 for demo videos; `tools/bbserial.py` sends one command and prints the answer.

### Protocol

[docs/PROTOCOL.md](../docs/PROTOCOL.md): Nordic UART Service over BLE (pairing required: bonding, MITM, LE Secure Connections, passkey on the band), MTU 247, answers as notifications of up to MTU−3 bytes. Commands `info`, `time`, `config`, `sync <since>`, `export json|csv`, `delete yes`. The same `bbproto::handleLine` answers on BLE and on USB serial (115200), and on the M5 build's USB serial. Tested on the Mac in `test/test_proto`.

### How it works

- **Motion:** MPU6050 by registers: awake on its internal clock, gyro in standby (accelerometer only), ±4 g, DLPF 10 Hz, 25 Hz sample rate, accelerometer data into its 1 KB FIFO. The band reads the FIFO every 2 s (also during long BLE syncs), converts to g and feeds `bb::StepCounter` and `bb::AngleTracker` with 40 ms-spaced timestamps (spacing follows the real rate). A full FIFO is reset and that batch dropped.
- **Storage:** same format as the M5 build: `/d/<localDay>.bin` with 12-byte `MinuteRec`, `/checkins.bin`. Kept **60 days**; older day files (and check-ins) are deleted, and the oldest days go first if flash runs low. 2 MB LittleFS partition (`partitions_c3.csv`, no OTA).
- **Clock:** no RTC. Nothing is recorded until the app sends `time`. After a software reset or crash the ESP32 keeps its clock and recording goes on; after power loss it waits for the app again.
- **Settings:** habit, reminder times, quiet hours, day end, time zone in NVS (Preferences). Bonds are in NVS too, so they survive reboots and `delete yes`.
- **BLE:** NimBLE-Arduino 2.x (it uses the NimBLE stack built into Arduino-ESP32 3.3). One connection at a time (advertising stops while connected). After a new phone pairs, older bonds are deleted (one phone per band).

### Power (estimate, not measured)

| Part | Current |
|---|---|
| ESP32-C3 at 80 MHz, idle between 15–40 ms loop ticks, BLE advertising every ~1 s | ~12–20 mA |
| MPU6050 accelerometer only, 25 Hz | ~0.5 mA |
| OLED off / on (low contrast) | ~0.01 / ~5–8 mA |
| Board LDO + charger leakage | ~0.1 mA |
| **Average, screen mostly off** | **~15–25 mA** → a 300 mAh LiPo lasts about 12–20 h |

Light sleep is not used: the Arduino-ESP32 3.3 libraries for the C3 are built without power management (`CONFIG_PM_ENABLE` off, BT controller sleep off), so sleeping would stop BLE advertising. **Next step** if the battery does not last a day and a night: build on the pioarduino platform with `custom_sdkconfig` (or ESP-IDF + Arduino as a component) with `CONFIG_PM_ENABLE`, `CONFIG_FREERTOS_USE_TICKLESS_IDLE`, BT controller modem sleep with the main XTAL as low-power clock, then `esp_pm_configure()` with light sleep on. The firmware already only needs the CPU every 2 s (FIFO) and on button presses, so the expected average is ~2–4 mA. A cheaper stop-gap: advertise only for a few minutes after a button press.

### Check when the board arrives

1. `pio run -e c3-oled -t upload`, then `pio device monitor`: the log prints `MPU6050 WHO_AM_I=0x..` and `BloomBack-XXXX c3-oled fw 0.2.0`. `info` answers `INFO {...}`.
2. OLED: text centred and not cut off. If it is shifted, the panel needs another U8g2 constructor (e.g. 128×64 with an offset) in `src/c3/ui.cpp`. Check Vietnamese habit text renders (font `unifont_t_vietnamese2`).
3. I2C pins: if the OLED or MPU6050 stays dark, try `-DBB_SDA=8 -DBB_SCL=9` style overrides per the board's pinout.
4. Pair from the phone app (or nRF Connect): the passkey appears on the band; RX/TX must refuse access before pairing; reconnect after reboot without pairing again; "Unpair" on the band clears it.
5. Walk 100 counted steps, compare; wear one night; check `sync` output.
6. Measure current with a USB meter on battery power (USB serial keeps the chip awake) and how long a full charge lasts.

## Demo board with a touch screen (`cyd`)

**Status 2026-11-19: runs on our ESP32-2432S024 demo board.** Screens and pen taps checked; Bluetooth pairing and the app sync not yet shown on it. Steps and sleep on this board are demo data (DEMO tag) until a motion sensor is fitted.

- **Board:** ESP32-2432S024 family: classic ESP32 (CH340 USB-C), 2.4" 320x240 ST7789 display (backlight GPIO27), XPT2046 resistive touch on the display's SPI bus (CS GPIO33), SD slot, battery connector. **No motion sensor**: an MPU6050 would go on SDA 21 / SCL 22.
- **Firmware:** the same band firmware as `c3-oled` (`src/c3/` without its `ui.cpp`) with big-screen drawing and touch in `src/cyd/ui.cpp`. Flash: `pio run -e cyd -t upload`.
- **Use:** tap with the pen (the first tap starts a 4-corner touch setup), or the BOOT button as on the C3 band. Tabs: Today, Steps, Active, Sleep, Phone.
- **Demo data:** while no motion sensor answers, steps are simulated (`BB_DEMO_STEPS`, stored and synced like real ones) and a sample sleep window is shown on the screen only. A small DEMO tag in the top bar says so.
- **Tools (USB):** `tools/cydshot.py` (screenshot as PNG, or send commands), `tools/cydvideo.py` (frame-by-frame screen recording as MP4), `tools/cydclock.py` (keeps the clock set while filming), `tools/cyd_icons.py` (makes `src/cyd/icons.h`). `tools/mirror.py` is for the C3 band's small screen, not this board.

## M5StickC Plus2 (`m5stickc-plus2`, reference)

- **USB:** the same line protocol as BLE (`info`, `time`, `config`, `sync`, `export json|csv`, `delete yes`). The old `status` command is gone (use `info`).
- **Wi-Fi (optional):** hold B; the band starts its own Wi-Fi with a password shown on its screen; open `http://192.168.4.1`.

## What is in this folder

```
platformio.ini          build settings (c3-oled, m5stickc-plus2, native tests)
partitions_c3.csv       C3 flash layout: 1.9 MB app, 2 MB LittleFS
lib/bbcore/             board-independent core, plain C++
  motion.*              step counter (4-step confirm) + arm-angle tracker
  sleep.*               main sleep window (HDCZA-style) + minutes asleep (5 deg / 5 min rule)
  reminders.*           max 2/day, quiet hours, no catch-up nagging
  export.*              FHIR R4 Bundle (LOINC 55423-8 steps, 55411-3 exercise minutes,
                        93832-4 sleep duration, source tag "watch") + CSV
lib/bbproto/            band <-> app protocol (docs/PROTOCOL.md), plain C++: BandHost
                        interface, handleLine, LineReader, config JSON parser
src/common/             shared firmware: settings (NVS), minute files (LittleFS), protocol host
src/c3/                 ESP32-C3 band: main, OLED screens, MPU6050 FIFO, BLE (NimBLE)
src/m5/                 M5StickC Plus2: main (screens, Wi-Fi download page, USB protocol)
test/test_core/         11 tests with synthetic walking, noise, nights, charging, exports
test/test_proto/        11 protocol tests with a fake band (info, time, config, sync, limits)
```

Status on 2026-11-13: tests pass on the Mac (22/22); `c3-oled` and `m5stickc-plus2` compile. **Neither has run on a real board yet.**

## Commands

```bash
pio test -e native                        # core + protocol tests on the Mac
pio run -e c3-oled -t upload              # cheap band: build + flash (default env)
pio run -e m5stickc-plus2 -t upload       # reference watch
pio device monitor                        # serial log + commands
```

## Using the M5StickC Plus2

- Screen off: press A or B to wake.
- Home: **A** = check-in, **B** = steps/active ↔ sleep page, **hold B** = share/download.
- Check-in: **B** cycles Done / Partly / Not today, **A** saves.
- Reminder: band beeps, shows the habit; **A** = check-in, **B** = later.
- First use: hold B, join the band's Wi-Fi from the phone, open `http://192.168.4.1` (this also sets the clock and time zone). Nothing is recorded until the clock is set.

## Plan to 20 Nov

| Day | Work |
|---|---|
| 13 Nov | Pick and order a ~200K board + MPU6050 + battery. Chi answers thread 0001 (band as optional source). |
| Board arrives | Flash, walk 100 counted steps and compare; wear it one night; measure battery. Tune step threshold if needed. |
| +1 day | Phone app pairs over BLE, runs `sync` (records tagged source "watch") and shows week numbers next to self-report. |
| 18–19 Nov | Record the demo (wrist close-ups + phone download), fill the PPT template, export PDF < 5 MB. |
| 20 Nov | Submit (form closes 21 Nov 01:29 ICT). |

## Sources

- Tudor-Locke C et al. How fast is fast enough? Walking cadence (steps/min) as a practical estimate of intensity in adults. Br J Sports Med 2018 (≥100 steps/min ≈ moderate).
- van Hees VT et al. A novel, open access method to assess sleep duration using a wrist-worn accelerometer. PLoS ONE 2015;10:e0142533.
- van Hees VT et al. Estimating sleep parameters using an accelerometer without sleep diary. Sci Rep 2018;8:12975 (HDCZA).
- HL7 FHIR R4 Observation; LOINC codes 55423-8, 55411-3, 93832-4 (check against loinc.org before the deck).
- Threshold clamp (0.13–0.50°) and the 18:00 day boundary are our own choices, to be tuned on real nights.
