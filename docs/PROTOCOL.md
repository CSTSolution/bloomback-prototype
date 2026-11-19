# Band ↔ app protocol (v1)

One line-based text protocol, used the same way over **Bluetooth LE** (main: phone app) and **USB serial** (flashing, debugging, backup copy). The phone app and the firmware must both follow this file; change it here first, then both sides.

## Transport

### Bluetooth LE (main)
- The band advertises as `BloomBack-XXXX` (last 4 hex digits of its MAC) with the **Nordic UART Service** (NUS), which every BLE library understands:
  - Service `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
  - RX, app → band, write: `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
  - TX, band → app, notify: `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`
- **Pairing is required.** LE Secure Connections, bonding on, the band **displays a 6-digit passkey** on its screen and the phone asks the user to type it. RX and TX need an encrypted, authenticated link; an unpaired device can see the band but cannot read or write.
- The app asks for MTU 247. Responses arrive as notifications of up to (MTU − 3) bytes; the app joins them and splits on `\n`.
- A band talks to one bonded phone at a time. "Forget band" in the app + "Unpair" (long hold on the band's pairing screen) clear bonds on both sides.

### USB serial
- 115200 baud (ignored on the ESP32-C3's built-in USB). Same commands, same answers.

## Lines

- Every command and every answer is one UTF-8 line ending in `\n`, at most 200 bytes.
- Errors: `ERR <reason>` (`ERR unknown`, `ERR args`, `ERR time-not-set`, `ERR busy`).

## Commands

| Command | Answer | Notes |
|---|---|---|
| `info` | `INFO {"fw":"0.2.0","board":"c3-oled","battery":87,"days":3,"time_valid":true,"first_minute":29910000,"last_minute":29914320,"tz":420}` | One JSON object on one line. `battery` is -1 if unknown |
| `time <utc_seconds> <tz_minutes>` | `OK time` | The app sends this on every connect (the C3 board has no battery-backed clock) |
| `config <json>` | `OK config` | `{"habit":"Ngủ sớm 15'","r1":480,"r2":1200,"qs":1320,"qe":360,"de":1080}`. Times are local minutes of the day; `-1` = off. `habit` ≤ 24 characters (tiny screen). Missing keys stay as they are |
| `sync <since_minute>` | `BEGIN sync` · records · `END sync <count>` | Records strictly after `since_minute` (UTC unix minutes). The app stores the last minute it saved and sends it next time |
| `export json` / `export csv` | `BEGIN json` … `END` | Ready-made FHIR Bundle / CSV. For USB and debugging; the phone uses `sync` |
| `delete yes` | `OK deleted` | Wipes minutes and check-ins on the band. Bonds and settings stay |

### Records inside `sync`

```
M <minute> <steps> <med_cdeg> <max_cdeg> <flags>
C <minute> <status>
```

- `M`: one minute of data (fields as in `MinuteRec`: steps, median and max arm-angle change in hundredths of a degree, flags bit 0 = charging).
- `C`: a check-in tapped on the band; status `0` done, `1` partly, `2` not today.
- Example: `M 29914200 104 312 1450 0`, `C 29914230 1`.

## What the app does with the data

The app converts records to FHIR R4 Observations with source tag `watch` (rules B1) using the same rules as `wearable/lib/bbcore`: steps per day (LOINC 55423-8), minutes with ≥100 steps (55411-3), main sleep window and minutes asleep (93832-4). The app may keep the raw minutes for 60 days to recompute; nothing is sent to a server.

## Versioning

`info.fw` carries the firmware version. A breaking change bumps this file to v2 and the app refuses to sync with a band it does not understand ("Please update the band").
