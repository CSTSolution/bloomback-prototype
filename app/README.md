# BloomBack phone app (Flutter, draft)

The main BloomBack app. It coaches small sleep and movement habits from Chi's rules
([../docs/BloomBack_Nguyen_tac_hoat_dong.pdf](../docs/BloomBack_Nguyen_tac_hoat_dong.pdf)) and
reads the ESP32-C3 band over Bluetooth LE using [../docs/PROTOCOL.md](../docs/PROTOCOL.md).
Data stays on the phone and the band. No server, no account, no API keys.

## Run

```sh
cd app
flutter pub get
flutter test            # 109 tests: protocol, sync, sleep port, FHIR, rules, environment rules, end-to-end, screens (Chi's design), demo scenarios, emulator fixes
flutter run             # phone or simulator
flutter build apk --debug
flutter build ios --simulator --debug   # no signing needed
```

The app starts with the **demo band** on (More > Demo and testing > "Use demo band"), so the whole
app works without hardware: More > BloomBack band > type any 6 digits (the demo band shows 482 913) > Pair band.

### Demo band (FakeBand)

`lib/band/fake_band.dart` is a pretend band that answers the same protocol lines (`info`, `time`,
`config`, `sync`, `delete yes`) through the same parser and session code as the real band.
Its data is synthetic, persona **Ravi** from the rules (C7): fixed night shift 22:00-07:00,
standing/light walking at work, day sleep about 5.5 h (08:15 onward), a short wake some days,
two nights off a week, on the charger 18:00-18:40 every day, brisk walks of about 60 min a
week, and band check-ins on some days (done, partly, sometimes not today). From the second
week his sleep and walking improve a little so Garden and "Week by week" have something to show.
It starts with 14 days of history. Switching between the demo band and a real band clears
band data on the phone so the two never mix (your own check-ins stay).

### Demo scenarios (for the video)

More > Demo and testing > **Demo scenarios** (only while the demo band is on; on the web demo also the
**Scenarios** button in the top strip). Picking one asks first, then replaces all data on the
device through the normal paths: "Delete my data", the onboarding result (profile, `initialPlan()`,
suggested habits and reminder times), pairing `BloomBack-DEMO` and a sync over the protocol.
The band's history and its check-ins come from FakeBand (`lib/demo/scenarios.dart` gives it a
start minute and a check-in per day; today is always left open so a check-in can be shown live).
The script is kept in the store (`demoBand`), so the demo band answers the same way after a restart.

| Scenario | State | Today shows |
|---|---|---|
| Fresh start | No history, onboarding not done | Onboarding |
| Week 3, steady | Ravi onboarded 15 days ago, 21 band days, done on 5 of the last 7 days | "Steady lately" step-up card |
| Welcome back | Onboarded 10 days ago, checked in, then 2 days with no check-in | The "Welcome back, Ravi" screen with his own sentence (C5) |
| A bit hard lately | "Partly" on 3 of the last 5 days | "A bit hard lately?" with Shrink / Swap / Move |
| Nights are coming | Rotating shift, switch to nights in 2 days | "Nights are coming" heads-up (Lapse Radar) |

Tests: `test/scenarios_test.dart` (each scenario at 09:30 and 17:00, the card on the Today screen,
replacing one scenario with another, restart, the picker and Fresh start from the web banner).

### Web demo (for judges; not published)

```sh
cd app
flutter build web --release --no-web-resources-cdn   # CanvasKit served from build/web, not a CDN
cd build/web && python3 -m http.server 8080 --bind 127.0.0.1   # then open http://127.0.0.1:8080
```

The web build is the demo band only: a strip on every screen says "Demo with synthetic data.
Real use: Android app + optional band." with a **Scenarios** button; it opens at onboarding
(Fresh start). Platform code is picked by conditional imports, so the web bundle contains no
`flutter_blue_plus`, `sqflite` or notification code: `lib/data/open_store.dart` (sqflite on the
phone, `MemoryStore` on the web, so data is gone when the tab closes), `lib/band/real_band.dart`
(BLE on the phone; on the web the "Use demo band" switch is off-limits and a real band says it
needs the Android app), `lib/platform/share_file.dart` (FHIR export: share sheet on the phone,
browser share or download on the web). Reminders are not sent on the web; More > Reminders says so
above the reminder times. Chi's fonts are bundled (`assets/fonts`: Baloo 2, Be Vietnam Pro, Noto
Naskh Arabic for the "العربية" label), and a font family named "Roboto" is an alias of Be Vietnam
Pro, so the web build no longer downloads Roboto from Google Fonts. (Flutter still has Google Fonts
as its fallback for characters no bundled font has; the UI avoids such characters, e.g. "✓" became
an icon.)

## Screen map (Chi's design, docs/design, 13 Nov)

Theme tokens (colours, Baloo 2 / Be Vietnam Pro, radius 18 cards, pill chips, sun band) live in
`lib/ui/theme.dart`; line icons in `lib/ui/icons.dart`; the "?" sheet in `lib/ui/common.dart`
(`showWhy`, `WhyButton`); links and checked quotes in `lib/rules/sources.dart`. Bottom bar:
**Today · Plan · Garden · More** (`lib/main.dart`).

| Chi # | Screen | File | State |
|---|---|---|---|
| 1 | Start (English / العربية) | `lib/ui/onboarding.dart` `_startPage` | Done. Logo = the sprout from the app icon (`assets/images/sprout.png`, cut from `design/AppIcon.png` with a transparent background) in a soft green circle, and small before "BloomBack". Arabic opens "coming soon" (not translated) |
| 2 | Sign in | `onboarding.dart` `_signInPage`, `lib/account/account_service.dart` | Placeholder: no server. Apple / Google / email open "Accounts start with the pilot…" + "Continue without an account"; "Try without an account" works fully; the name is kept |
| 3 | Your choices | `onboarding.dart` `_choicesPage` | Done. Only "use my answers" works (on); sync and sharing are shown off, "coming later", disabled |
| 4 | Work (1/5) | `onboarding.dart` `_workPage` | Done: chips, city dropdown; rotating → next nights date; long/split → break time |
| 5 | Sleep and movement now (2/5) | `onboarding.dart` `_nowPage` | Done: fall asleep / wake up (morning/afternoon/evening/night), starting from the shift on screen 4 until the user changes them (fixed night 08:30–14:00 as in Chi's mock; day / long / irregular 23:00–06:00; rotating 23:30–05:30; `suggestedSleepTimes`), up to 2 naps, hours over 24 h; bedtime spread slider; days 0–7 × minutes with the HHS talk-test "?"; moderate work → work minutes (talk test) |
| 6 | Body measures (3/5) | `onboarding.dart` `_bodyPage` | Done: height + weight required; BP, waist, resting HR, glucose/HbA1c optional with "Don't know" and a source each (self-reported / health check); D2 logic unchanged (only the "ask a doctor" note) |
| 7 / 7b | Safety (4/5) | `onboarding.dart` `_safetyPage` | Done: Yes/No; a "Yes" shows the note card and "I understand · Continue"; never blocks |
| 8 | Goals (5/5) | `onboarding.dart` `_goalsPage` | Done: 14 cards in 5 groups with icons, "Which one matters most?" row, optional reason (danger-word check kept) |
| 9 | Your picture | `onboarding.dart` `_picturePage` | Done: neutral #3E7CB1 bars with the recommendation line, BloomBack suggests, user picks Sleep / Movement / Both |
| 10 | Your sleep plan | `onboarding.dart` `_planPage` | Done: keep wake time + bedtime this step; pace card shows +30 (suggested) and +15 (gentler) ladders, "BloomBack suggestion"; Follow / Go slower / Set my own (first step + 15/30 step). Movement card ("BloomBack suggestion", "?" HHS 2018 p. 90) when movement is chosen; 150/300 for the weight card |
| 11 | Pick one small step | `onboarding.dart` `_stepPage` | Done: 3 habits filtered as before (fixed night + sleep: the NIOSH habits C3 #15 straight to bed, #16 blackout, #14 nap before the shift, in Chi's order), tick up to 2 backups, editable "After I …, I will …" (stored in the plan), reminder time that follows the habit on fixed nights (after-shift habits 07:30, nap before the shift 16:00), "Start tomorrow" |
| 12 | Today | `lib/ui/today.dart` | Done: greeting by shift ("Shift done · Rest well, Ravi"), step card with Done / Partly / Not today, sleep this week vs goal, Lapse Radar cards, step-up / "a bit hard" cards, garden strip with "N days bloomed" |
| 13 | Why this suggestion? | `common.dart` `showWhy`, `today.dart` `showHabitWhy` | Done: what you chose + your work, Source (+ quote where checked), Your target, disclaimer, Open source (copies the link) |
| 14 | Welcome back | `lib/ui/welcome_back.dart` | Done (its own screen in the Today tab): title with the sprout inline after the name (one line for "Ravi" at 411 dp; a long name wraps with the sprout kept on the last word), own reason card, optional chips, Make it smaller / Swap / Move the time, "Restart today" |
| 15 | 4 weeks in | `lib/ui/four_weeks.dart` | Done: 5 options, week 1 → week 4 numbers, Keep / Step up / Change. Opened from a Today card, Plan and Garden |
| 16 | Someone to cheer you on | `lib/ui/more.dart` `CompanionScreen` | Placeholder: UI as designed; "Send invite link" says "available in the pilot", nothing is sent or stored |
| 17 | Ramadan | `more.dart` `RamadanScreen` | Done: Umm al-Qura 8 Feb – 8 Mar 2027, "may differ by a day", That's right / Pick other dates, fasting mode toggle, "your step during Ramadan", Save |
| 18 | Today in Arabic (RTL) | — | Not done: no Arabic translation yet (needs a native check); Arabic shows "coming soon" |
| 20 | Plan tab | `lib/ui/plan_tab.dart` | Done: main goal + reason + Change, sleep ladder with "this week", Change pace (+30/+15), small step with reminder, quiet hours, backup; movement "Add" when not started (sleep too) |
| 21 | Garden tab | `lib/ui/garden.dart` | Done: month grid (flower = done/partly, grey from the plan's start day onward, blank before it; same on the Today strip), days bloomed shown quietly, week 1 → last 7 days, "Came back after a break N times", band week by week (`week.dart`) |
| 22 | More tab | `more.dart` `MoreScreen` | Done: Reminders, Someone to cheer you on, Ramadan, Band, Language, What we use, Download my data (FHIR), Delete everything (band too if paired), Sources behind every tip, About; plus "Demo and testing" (demo band switch, demo scenarios) |
| 23 | Band pair | `lib/ui/band_screen.dart` | Done for the demo band (6 code boxes); a real band uses the phone's own Bluetooth pairing dialog for the code (scan list + Connect) |
| 24 | Band connected | `band_screen.dart` | Done: Connected chip, synced / battery, last main sleep "estimate" with Chi's Q2 wording, steps today, brisk min 7 days "next to your own N", Sync now, Band settings (delete on band, forget) |

## What is done

| Area | Where | Notes |
|---|---|---|
| Band link (BLE) | `lib/band/ble_band.dart` | Scan for `BloomBack-*` advertising NUS, connect, MTU 247 (Android), OS bonding (Android `createBond` shows the passkey dialog; the band shows the code), subscribe TX, write RX in MTU-sized chunks |
| Protocol | `lib/band/protocol.dart` | Line assembler (joins chunks, UTF-8 safe, splits on `\n`), parser for `INFO`, `OK`, `ERR`, `BEGIN`/`END`, `M`, `C`; command builders (`config` keeps `habit` ≤ 24 chars and the line ≤ 200 bytes) |
| Session | `lib/band/band_session.dart` | On every connect: `time`, `info`, `config`, `sync <last saved minute>`. Refuses a band with a newer protocol major ("Please update the band"). Sync count mismatch = nothing saved, cursor unchanged |
| Store | `lib/data/store.dart`, `lib/data/sqflite_store.dart` | sqflite (phone; `MemoryStore` on the web demo and in tests): minutes, check-ins (source watch / self-report), profile, plan, settings, sync cursor. 60-day retention. "Delete my data" (phone) and "Delete data on band" (`delete yes`) |
| Analytics | `lib/analytics/` | Dart port of `wearable/lib/bbcore`: `sleep.dart` = `sleep.cpp` line by line (HDCZA window + 5°/5-min sleep minutes); daily steps, minutes ≥ 100 steps/min, sleep for day D = main sleep in the 24 h ending D 18:00 (firmware `de`); weekly totals, bedtime spread |
| FHIR export | `lib/analytics/fhir.dart` | R4 Bundle of Observations, LOINC 55423-8 / 55411-3 / 93832-4 + check-ins, `meta.tag` source `watch` or `self-report`; shared/saved as a JSON file from More > Download my data |
| Rules | `lib/rules/` | B4 levels, C2 ladder (5′×3 … 30′×5) and +10 min/week from a base, sleep +30 (or 15) min steps to 7 h, C3 habit list (25 habits, each with its source) filtered by B6 (night shift → NIOSH habits; outdoor + 15 Jun–15 Sep → no extra movement; heavy work → no stairs/strength; Ramadan habit off), C4 reminder rules (port of `reminders.cpp`), C5 nudges (step up after 5 of 7 / 5 in a row, only if the user agrees; difficulty after 3 "partly" in 5 days; welcome back after 2 days with the user's own sentence, no reset), B4 end-of-week-1 recalibration, B2/B3 danger words + identifier stripping |
| Screens | `lib/ui/` | Chi's 24-screen design (see the screen map above). Every suggestion has a "?" sheet with its source. No red anywhere (Material's error colour is the accent ochre #9A6A12) |
| A1 inputs + D2 note | `lib/ui/onboarding.dart` screens 4 and 6, `lib/ui/health_numbers.dart`, `lib/rules/biomarkers.dart` | Day 1 asks height, weight (required) and city (Abu Dhabi, Al Ain, Dubai, Sharjah, Other UAE, Other). After week 1 Today offers the optional numbers (waist, blood pressure, resting heart rate, fasting glucose in mmol/L or mg/dL, HbA1c), each with "Don't know", a source (typed by me / check-up) and a date (optional numbers can also be given on screen 6, each with its own source); also in More > What we use. They only show "Ask a doctor before increasing activity" (BP ≥ 140/90, glucose ≥ 7.0 mmol/L or 126 mg/dL, HbA1c ≥ 6.5 %, BMI ≥ 30 from height/weight). Tests: levels, plan and habit identical with and without the numbers. No ethnicity question |
| Environment rules | `lib/rules/environment.dart` | One pure `dayRules()` per date: today's habit, quiet hours and up to 2 reminder times. **Heat** (C4, B6 axis 3): 15 Jun–15 Sep no outdoor-type walk (brisk walk, walk after a meal, walk after iftar) reminder 12:30–15:00 for anyone (moved to 19:30, else 06:00), a "not at midday" note with the source; outdoor/both workers get a sleep habit instead of extra movement for the season, reminders included; Lapse Radar a week before 15 Jun. **Fasting mode** (C4, #21): suggested Ramadan 1448 dates 8 Feb – 8 Mar 2027 (Umm al-Qura, Chi's screen 17; "may differ by a day"), user confirms or picks other dates (More > Ramadan or the Lapse Radar card 14 days before); while on: walk after iftar replaces brisk walk/stairs/strength, reminder 2 moves to 19:30 (movement) or 21:30 (sleep, before suhoor), note about sleep around suhoor; stored as `{on, from, to}` only. **Rotating shift**: date of the next switch to nights (onboarding + Settings); Lapse Radar 1–2 days before; the switch day and the next day suggest only sleep habits (own sleep backup, else NIOSH nap before the shift) with night-shift reminder times; asks for the next date once the nights have started. **Long/split shift**: optional break time, reminder 2 rings in the break, walks shown as 2 shorter parts in the breaks, stand-up/stretch ranked higher. **Irregular hours**: no fixed times; one reminder 3 h (Settings: 1–12 h) after the last check-in or app open if today is not checked in, and one the next day at the time of the last check-in, never in quiet hours |
| Work movement | `lib/rules/environment.dart`, `lib/rules/plan.dart` | Moderate work: optional minutes per week at work that pass the talk test (onboarding screen 5 + More > What we use); **100 % count** toward the current level and base (Chi Q7; source WHO 2020, Bull et al., BJSM 2020). Today shows the band/self-report minutes against the part to do outside work, and the work minutes on their own line. Heavy work: sleep suggested first, stretching first, stairs/strength filtered and swapped out if chosen before |
| Weight card goal | `lib/rules/plan.dart` | With the "Manage weight and waist" card the plan page offers 150 (default) or 300 min/week; 300 keeps the +10/week steps after 150 (from 0: the ladder, then +10). Any other value falls back to 150 |
| Sleep regularity | `lib/rules/regularity.dart` | Bedtime spread from the band's latest week (≥ 4 days), else the onboarding answer (new slider, 0–6 h). If ≥ 1 h and sleep is a chosen area: suggest 30 min less for the next 2 weeks; "Try it" saves the target, "Not now" hides it 2 weeks; next step after 14 days, last target "under 1 h". Source text says the step is set by BloomBack |
| Barrier "Move" | `lib/ui/today.dart` `showMoveReminderSheet` | From the "A bit hard lately?" card: pick reminder 1 or 2 (irregular: one time today) and a new time; today only, or "keep this time from now on". Refused inside quiet hours; a midday outdoor walk still moves after sunset in the hot season |
| Notifications | `lib/notify/notifier.dart` | One-off notifications for the next 7 days from `reminderSchedule()` (each day from its own rules: season, fasting dates, first nights, moved reminder, check-ins), at most 2 a day, none inside quiet hours, no catch-up. Rescheduled on app open, check-in and every settings/plan change. Night shift defaults: quiet 08:00–15:00, reminders 16:00 and 06:30; with an after-shift habit (straight to bed, blackout) one reminder at 07:30, with the nap before the shift one at 16:00 (`suggestedReminderSettings(..., habitId:)`). The Plan tab lists the reminders that will ring |
| Strings | `lib/l10n/strings.dart` | All UI text in one class `S`; a Vietnamese copy can implement the same methods |
| Platform | Android manifest, iOS Info.plist | `BLUETOOTH_SCAN` (neverForLocation), `BLUETOOTH_CONNECT`, legacy permissions up to API 30, `POST_NOTIFICATIONS`, boot receiver; minSdk 24; core library desugaring. iOS `NSBluetoothAlwaysUsageDescription` |

## Emulator check (13 Nov)

Walked through on the Android emulator (1080×2400) as Ravi with the demo band: onboarding → plan → Today → Band (scan, connect, sync 14 days) → Today → Week → Settings → check-in. Fixed on the way, each with a test where it is logic:
- Onboarding crashed (null check) when the work activity was picked before the shift: the already-built plan page needed all three answers. Test: `widget_smoke_test` "work answers one at a time".
- Walking minutes accepted "60." and "-5" and read them as 0: field is digits-only now.
- "Welcome back" showed right after onboarding because band check-ins from before the plan counted as a lapse: nudges (C5) now only count days since the plan started. Test: `app_flow_test`.
- "Not today" wrapped onto two lines; step counts had no thousands separators; "1 days so far"; movement card title repeated a stat label.

(14 Nov: the screens were rebuilt to Chi's design; see the screen map.)

## Emulator check (14 Nov, Chi's design)

Fixed after a walk-through on the 1080×2400 emulator, tests in `test/emulator_fixes_test.dart`, `test/rules_test.dart` and the onboarding walk in `test/widget_smoke_test.dart`:
1. Screen 5 sleep times start from the shift picked on screen 4 (fixed night 08:30–14:00).
2. Screen 11 reminder follows the habit on fixed nights (straight to bed 07:30, nap 16:00; one reminder, never in quiet hours); the Plan tab shows the reminders that will ring. Not done: a later Swap to a backup keeps the reminder times.
3. Fixed night + sleep: the three NIOSH night-shift habits first, in Chi's order.
4. Garden: days before the plan started are blank, grey only from the start day.
5. "Welcome back, Ravi" no longer wraps on a 411 dp phone (the title had only half the row: Flexible + Spacer); the sprout is inline, joined to the last word.
6. Screen 1 uses the real sprout from the app icon.
7. Demo scenarios: Ravi's sentence is Chi's exact text "So I still have energy to video-call my kids".

## What is stubbed or missing

- **Not tried on a real band or phone yet.** BLE pairing, MTU and runtime permission prompts
  (flutter_blue_plus asks for Bluetooth permissions on scan/connect) need a device test with the
  C3 firmware once its BLE layer exists.
- iOS: no "forget band" from the app (iOS does not allow it); the app tells the user to use
  Settings > Bluetooth. `flutter build ios --simulator --debug` builds (13 Nov; iOS 15.0
  deployment target, pinned in the Podfile; the first `pod install` added the Pods files to the
  Xcode project and `ios/Podfile.lock`). Not run on a simulator or an iPhone yet. A device or
  TestFlight build still needs Son: signing team and bundle id `com.cstsolution.bloomback` in the
  Apple account. `flutter_local_notifications` 17 does not support Swift Package Manager (a
  warning for now).
- Reminders are scheduled 7 days ahead and refreshed whenever the app opens; if the app is not
  opened for a week they stop until it is opened again.
- Rules not built yet: the bandit learning (C5); weather "from the city" (no network, so heat
  is by date only, the same for every city); "sleep around suhoor" is a note and a 21:30
  reminder, not a split-sleep target; fasting mode does not change quiet hours for suhoor.
- Rotating shift: only the next switch to nights is known, not how long the night block lasts or
  the switch back to days; after the first 2 nights the user's own reminder times apply again.
- Work movement: band minutes at work are not separated from minutes outside work, so with the
  band worn at work, work walking may be counted in the band number and again as the work credit.
  The B4 end-of-week-1 recalibration still compares the band week with the self-reported
  minutes outside work only.
- Health numbers are not in the FHIR export yet (B1 asks for FHIR Observations: height 8302-2,
  weight 29463-7, BMI 39156-5, waist 8280-0, BP 85354-9, resting HR 40443-4, glucose 1558-6 /
  14771-0, HbA1c 4548-4), and the 4-week check (C6) does not show them yet. Only one source and
  date per entry form, not per number.
- Barrier choices (C5) are stored; "Heat" or "Shift change" do not yet pick a different fix.
- The 4-week check (C6) appears after 28 days; answers are kept on the phone only.
- Danger keyword list (English + 2 Arabic phrases) is a first draft; Arabic needs a native check.

## Decisions to confirm

1. **flutter_blue_plus is pinned to 1.36.8**, the last BSD-3 release. 2.x uses the
   "FlutterBluePlus License": paid for for-profit companies (CST) and it pings a licence server
   at build time with the package and app name. Alternative: `flutter_reactive_ble` (BSD-3).
2. **flutter_local_notifications is pinned to 17.x** (as in MedSearch/MedAction). 23.x needs
   Android SDK 37, which this Mac's SDK/AGP does not resolve yet.
3. Movement start for "insufficient" users (some activity, under 150): target = their weekly
   minutes + 10 per week, up to 150 (C2 "đã có nền"). Users at 0 use the C2 ladder. (Chi)
4. First sleep target = self-reported sleep + 30 min (Ravi 5.5 h → 6 h), then +30 min per step;
   the user can choose 15. (Chi: C2 is marked Đề xuất)
5. "Two days without doing it" counts a missing check-in like "not today", but only after the
   user has checked in at least once. (Chi)
6. Week 1 = the earlier of the user's start and the first band data, so a band worn before
   onboarding becomes the baseline. Band numbers are only compared with band numbers (B1).
7. "Days your habit bloomed" counts done + partly days in total; it never resets and is not a
   streak. (Chi: is this wording OK under "no points"?)
8. The band gets an English short habit label (≤ 24 chars, e.g. "Home, then bed"); a
   Vietnamese label needs a font with diacritics on the 72×40 OLED. (Son)

### Decisions to confirm (added 13 Nov, items 1–8 of the rules build)

9. **Asian BMI cut-off (D2: 27.5 for people of Asian origin).** Not used: BloomBack does not ask
   ethnicity (A3, minimum data). Only BMI ≥ 30 shows the note. Should there be an opt-in
   question, or stay at 30 for everyone? (Chi)
10. Height and weight are whole numbers (cm 100–250, kg 30–300); city "Other" gets the same
    rules as UAE cities (heat dates, Ramadan dates labelled "can differ by a day"). (Chi)
11. The optional numbers are offered on Today from day 8 after the plan start; "Not now" hides
    the card for good (still in More > What we use). One source and one date for the whole form. (Chi)
12. The D2 "Why?" text cites the sources without naming a disease ("WHO 2021 guideline",
    "CDC testing reference levels"). The B3 safety question still names diseases, as in the PDF.
13. Heat: the outdoor-type habits are brisk walk, walk after a meal, walk after iftar. A
    reminder for them inside 12:30–15:00 moves to 19:30 (after sunset), else 06:00 if 19:30 is in
    quiet hours, else it is dropped. Outdoor/both workers get a sleep habit in the season (the
    PDF says rest, water, sleep; there is no "drink water" habit in C3). Heat heads-up 7 days
    before 15 Jun. (Chi: C4 heat is Đề xuất)
14. Ramadan 1448 = 8 Feb – 8 Mar 2027 (Umm al-Qura, Chi's screen 17; labelled "may differ by a day"). Lapse Radar
    shows it from 14 days before; "Hide" stores only "hidden: ramadan-2027-02-08". In fasting mode
    brisk walk, stairs and strength all become "walk after iftar" (vigorous = anything with
    extra exercise); stand-up and stretching stay. Reminder 2 moves to 19:30 (movement) or 21:30
    (sleep); reminder 1 stays. (Chi)
15. Rotating shift: heads-up 2 days and 1 day before; "first 2 days" = the switch day and the
    next; on those days the user's own sleep backup is used, else "Short nap before the night
    shift", with night-shift reminder times (16:00, 06:30) and quiet hours 08:00–15:00. (Chi: Đề
    xuất in B6)
16. Long/split shift: the weekly total is not reduced; each walk is shown as 2 parts (≥ 10 min
    sessions only) in the breaks, and reminder 2 rings at the break time. "Smaller tasks" could
    instead mean a smaller step. (Chi)
17. Irregular hours: reminder 3 h after the last check-in or app open (if today is not checked in)
    and one the next day at the time of the last check-in; the user can set 1–12 h. (Chi)
18. ~~Work credit: 50 %~~ Decided by Chi (Q7): 100 % of the minutes at work the user confirms as moderate (talk test), moderate work only (the C2 note
    says moderate/heavy; heavy work is steered to sleep and recovery instead). It is part of the
    base the +10/week steps start from, and Today compares band minutes with the part outside
    work. (Chi)
19. Weight card: the 300 choice is offered only with the "Manage weight and waist" card (not as a
    general "set my own goal", which C1 step 3 also allows). (Chi)
20. Sleep regularity: spread = latest minus earliest bedtime in a week (band onset or the new
    onboarding slider, default 1 h); offered only if sleep is a chosen area and the spread is ≥ 1 h;
    the next step comes after 14 days whether or not the target was met (the user decides);
    "under 1 h" is the last step; "Not now" waits 14 days. (Chi: C2 is Đề xuất)
21. Barrier "Move" changes today's reminder only, unless "keep this time from now on" is on; a
    time inside quiet hours is refused. (Chi)
22. Heavy work: the suggested starting area is sleep for every card (B6 axis 1 "ưu tiên ngủ"),
    and stretching is suggested first if the user picks movement. (Chi)


## Chi's design: placeholders and differences (14 Nov rebuild)

Placeholders (need a server or a translator):
- **Sign-in (2):** no accounts yet. `AccountService` (`lib/account/account_service.dart`) is the seam;
  `LocalOnlyAccountService` says `available = false`, so every provider button shows "Accounts start
  with the pilot…". The first name / nickname is stored on the phone (`account` key) and deleted with
  "Delete everything". Digits and "@" cannot be typed into it (never a phone number or ID).
- **Someone to cheer you on (16):** UI only; nothing is sent or saved.
- **Arabic (1, 18, More > Language):** "coming soon"; no RTL Today yet. The "العربية" label uses
  Noto Naskh Arabic from the Flutter SDK (OFL) because Noto Kufi Arabic is not on disk.
- **"Your choices" (3):** sync and sharing toggles are shown off and disabled ("coming later").

What differs from the design, and why:
- **"Share ✓ with someone I invite"** became "Share with someone I invite": "✓" is not in Be Vietnam
  Pro and would make the web build fetch a fallback font. Its subtitle still says "Only "done today"".
- **Choices note:** "Health data is stored in the UAE (pilot)" became "For now everything stays on
  this phone; in the pilot, health data is stored in the UAE": true for this build.
- **Ramadan note:** "Reminders move to iftar and suhoor times for Abu Dhabi" became "after iftar
  (19:30) and before suhoor (21:30)": the app uses those fixed times (C4 decision), not city prayer times.
- **Companion cheer "👏":** written as "a clap" (no emoji in the UI).
- **Reminder time on screen 11:** the default is the shift's suggested time from the existing C4 rules
  (night shift 16:00; Chi's mock shows 07:30, which is inside her own quiet hours 08:00–14:30 only by
  half an hour); the user can change it there.
- **Week labels on the pace ladder** are "wk 1–2, wk 3–4…" (one step per 1–2 weeks, step up only with
  ≥ 5 of 7 days and the user's yes), not the mock's "wk 2–3, wk 4–5, ≈ wk 8".
- **Band pairing (23):** the 6 code boxes are used with the demo band. A real band pairs through the
  phone's Bluetooth bonding dialog (the OS asks for the code), so the screen shows a scan list instead.
- **"Open source"** copies the link (and shows it) instead of opening a browser: no browser plugin is
  added to the app.
- **Quotes in the "?" sheet:** only NIOSH "Go directly to bed when you arrive home." (from Chi's
  screen 13) is shown as a quote; other sources show the name and link until their wording is checked.
- **Garden "Week 1 → now"** compares week 1 with the last 7 days (sleep from the band only; without a
  band, the self-reported start is shown on its own).
- **Today greeting** after a night shift (06:00–14:00) is "Shift done · Rest well, Ravi"; other shifts
  get good morning / afternoon / evening.

Q2–Q11 in the logic: Q2 wording on Today (band sleep), Band connected, Garden, Week; Q3 both paces
shown, step up after ≥ 5 of 7 days and only on the user's "Yes, next step" / "Step up" (unchanged
rule `nudgeFor`); Q4 "BloomBack suggestion" on movement with "?" citing HHS 2018 p. 90
(`kMoveStepSource`); Q7 100 % (test `environment_test`); Q8 BMI 30 for everyone; Q9–Q11 unchanged and
labelled as before.
