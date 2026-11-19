# BloomBack prototype

**BloomBack** helps shift and outdoor workers in the UAE start, keep and come back to two habits: sleep and everyday movement. It is a phone app (iPhone and Android) with an optional low-cost wrist band. Entry of CST Solution to the **Future Health Digital Innovation Challenge**, statement *[Wellness] Sustaining Healthy Behaviors*.

## Try it

**Web demo, no install and no login: https://bloomback.cstsolution.com/demo/**

- Tap **Scenarios** (top right) → **Week 3, steady**: the synthetic persona *Ravi* (fixed night shifts) with three weeks of demo band data. Other scenarios show "A bit hard lately?" and "Welcome back".
- Or tap **Get started** to go through onboarding yourself.
- Everything works as a guest. Only the AI coach ("Ask BloomBack", Pro) needs a sign-in: More › Account › Continue with email, then More › Account › Redeem a code. **The judges' Pro code is on the login slide of our submitted deck.**
- iPhone TestFlight build on request: hello@cstsolution.com

## What is in this repository

| Folder | What | Check it |
|---|---|---|
| [`app/`](app/) | The phone app (Flutter): goal cards, work and shift questions, Today with "Your day" around the shift, My shifts, check-ins, welcome back, sources on every "?", daily health question, garden, FHIR export, demo band and demo scenarios | `cd app && flutter test` (168 tests) |
| [`wearable/`](wearable/) | Band firmware (PlatformIO): steps, active minutes, sleep window estimate, one-button check-in, Bluetooth LE with passkey pairing, 60-day storage. Envs `c3-oled` (target band) and `cyd` (the ESP32 display board in our demo) | `cd wearable && pio test -e native` (22 tests) |
| [`docs/PROTOCOL.md`](docs/PROTOCOL.md) | Band ↔ app protocol (Nordic UART over BLE, same lines over USB) | |
| [`docs/submission/band-demo/`](docs/submission/band-demo/) | Photos and phone videos of the band firmware on the ESP32 board (19 Nov 2026) | |
| [`docs/submission/screens/`](docs/submission/screens/) | App screenshots (synthetic data) | |

**Hardware status (19 Nov 2026):** the firmware runs on an ESP32 board with a 2.4" touch screen (screens, check-in, touch menu). The motion sensor is not fitted yet, so steps and sleep on that board are **demo data**, marked DEMO on its screen. Bluetooth pairing is written but not yet shown on that board.

## Not in this repository (on purpose)

- **The account and coach server.** It holds sign-in, Pro and the guarded AI coach (pre-check, fixed brief, output check). Its prompts and guard rules are part of the safety design, so they stay private.
- Our rules book (owned by our product lead), internal notes and anything with keys. No API key, password or token is in this repository.

## Data

Only synthetic data (persona *Ravi*) appears in the code, screenshots and videos. In the app, health data stays on the phone and the band; an account is optional and holds no health data.

## Credits

Music: 9 tracks by Kevin MacLeod (incompetech.com), CC BY 4.0 ([app/assets/music/CREDITS.md](app/assets/music/CREDITS.md)). Fonts: Be Vietnam Pro, Baloo 2, Noto Naskh Arabic (SIL Open Font License). Open-source packages under their own licences.

© 2026 CST Solution. Shared for the challenge's judges and reviewers; all rights reserved.
