// Every user-facing text in one place, so a Vietnamese copy (strings_vi.dart)
// can be added later by implementing the same class.
// Tone (rules): suggest, never diagnose; neutral words; no blame, no streaks.
import '../data/models.dart';
import '../demo/scenarios.dart';
import '../rules/environment.dart';

class S {
  const S();

  // App
  String get appName => 'BloomBack';
  String get tabToday => 'Today';
  String get tabWeek => 'Week';
  String get tabBand => 'Band';
  String get tabSettings => 'Settings';
  String get tabPlan => 'Plan';
  String get tabGarden => 'Garden';
  String get tabMore => 'More';
  String get why => 'Why?';
  String get source => 'Source';
  String get ok => 'OK';
  String get cancel => 'Cancel';
  String get next => 'Next';
  String get back => 'Back';
  String get done => 'Done';
  String get notNow => 'Not now';
  String get yes => 'Yes';
  String get no => 'No';

  // Onboarding
  String get obWelcomeTitle => 'Small steps for sleep and movement';
  String get obWelcomeBody =>
      'BloomBack suggests small daily habits from official guidelines (AASM, CDC, WHO, DHA, HHS, NIOSH). '
      'It never diagnoses. You decide everything. Your data stays on your phone and your band.';
  String get obStart => 'Start (about 1 minute)';
  String get obGoalsTitle => 'What would you like to feel better?';
  String get obGoalsHint => 'Pick 1 to 3. Tap a picked card again to make it your main one.';
  String get obMain => 'Main';
  String get obMotivationTitle => 'Your reason, in your words (optional)';
  String get obMotivationHint => 'e.g. "So I still have energy to video-call my kids"';
  String get obMotivationBody =>
      'BloomBack will show you this sentence, word for word, if you take a break.';
  String get obWorkTitle => 'Your work';
  String get obActivityQ => 'How much do you move at work?';
  String get obShiftQ => 'When do you work?';
  String get obPlaceQ => 'Where do you work?';
  String get obHabitsTitle => 'Where you are now';
  String get obSleepQ => 'Usual sleep per 24 hours';
  String get obWalkQ => 'Brisk walking or similar, minutes per week';
  String get obWalkHint => 'Activity that makes you breathe a bit faster. 0 is fine.';
  String get obSafetyTitle => 'Two quick questions';
  String get obSafetyQ1 =>
      'Do you have heart disease, diabetes or kidney disease, or often get chest pain, dizziness or shortness of breath when active?';
  String get obSafetyQ2 => 'Are you pregnant or did you give birth recently?';
  String get obSafetyNote =>
      'Please ask a doctor before increasing physical activity. Your plan is still shown; the doctor\'s advice comes first.';
  String get obSafetyUnderstood => 'I understand';
  String get obPlanTitle => 'Suggested start';
  String get obPlanBody => 'BloomBack suggests; you choose.';
  String get obAreaQ => 'Which area first?';
  String get obHabitQ => 'Pick one main habit (the others become backups)';
  String get obFinish => 'Start my plan';
  String suggestedLabel(String x) => '$x (suggested)';
  String planSleep(int sleep, bool enough, int target, int inc) {
    final next = enough
        ? 'Keep the rhythm; focus on regular times.'
        : 'Suggested first step: ${hours(target)}, then +$inc min every 1-2 weeks.';
    return 'You sleep about ${hours(sleep)}; the guideline is 7 hours or more. $next';
  }

  String planMove(int walk, bool enough, int per, int sessions, int weekly) {
    final next = enough
        ? 'Keep the rhythm.'
        : 'Suggested first step: $per min × $sessions days ($weekly min this week).';
    return 'You move about $walk min a week; the guideline is 150-300. $next';
  }

  String hours(int minutes) {
    final h = minutes ~/ 60, m = minutes % 60;
    return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
  }

  String hoursDecimal(int minutes) {
    final v = minutes / 60;
    return '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)} h';
  }

  String activityLabel(WorkActivity a) => switch (a) {
        WorkActivity.sitting => 'Mostly sitting (office, driving, seated guard)',
        WorkActivity.standingLight => 'Standing or light walking (shop, cashier, nurse)',
        WorkActivity.moderate => 'Moderate: heart beats faster (waiter, walking delivery, cleaning)',
        WorkActivity.heavy => 'Heavy: breathing hard (building, loading)',
      };

  String shiftLabel(ShiftType s) => switch (s) {
        ShiftType.dayFixed => 'Fixed day shift',
        ShiftType.nightFixed => 'Fixed night shift',
        ShiftType.rotating => 'Rotating day/night',
        ShiftType.longOrSplit => 'Long (12 h+) or split shifts',
        ShiftType.irregular => 'Irregular hours',
      };

  String placeLabel(WorkPlace p) => switch (p) {
        WorkPlace.indoor => 'Indoors with air conditioning',
        WorkPlace.outdoor => 'Outdoors',
        WorkPlace.both => 'Both',
      };

  String domainLabel(Domain d) => d == Domain.sleep ? 'Sleep' : 'Movement';

  // Goal cards (B5)
  String goalGroup(String g) => switch (g) {
        'night' => 'Night sleep',
        'day' => 'Daytime',
        'mood' => 'Mind',
        'body' => 'Body',
        _ => 'Doctor\'s advice',
      };

  // Chi's card labels (screen 8).
  String goal(String id) => const {
        'fallAsleep': 'Lying awake long',
        'wakeAtNight': 'Waking at night',
        'wakeTooEarly': 'Waking too early',
        'shiftSleep': 'Shift work sleep',
        'tiredOnWaking': 'Still tired after sleep',
        'sleepyAtWork': 'Sleepy at work',
        'focus': 'Hard to focus',
        'mood': 'Better mood',
        'calm': 'Calmer',
        'energy': 'More energy',
        'weight': 'Weight & waist',
        'stronger': 'Fitter',
        'aches': 'Less aches from work',
        'doctor': 'My doctor told me to',
      }[id]!;

  // Habits (C3)
  String habit(String id) => const {
        'sameWake': 'Get up at the same time every day, weekends too',
        'bedEarlier': 'Go to bed a little earlier',
        'bedWhenSleepy': 'Go to bed only when sleepy',
        'up20': 'Can\'t sleep after 20 min? Get up, do something calm in dim light, no phone',
        'windDown': 'Relax before bed',
        'bedForSleep': 'Use the bed only for sleep',
        'quietRoom': 'Keep the bedroom quiet, relaxing and cool',
        'dimLight': 'Dim bright lights in the evening',
        'screensOff': 'Screens off at least 30 min before sleep',
        'lightMeal': 'No big meal before bed; a light snack if hungry',
        'noCaffeine': 'No coffee or energy drinks in the afternoon and evening',
        'noAlcohol': 'No alcohol before sleep',
        'lessFluid': 'Drink less right before bed',
        'napBeforeShift': 'Short nap before the night shift',
        'homeToBed': 'Straight to bed after the night shift, no chores first',
        'blackout': 'Blackout curtains, eye mask, ear plugs for day sleep',
        'briskWalk': 'Brisk walk',
        'walkAfterMeal': 'Walk after a meal',
        'stairs': 'Take the stairs',
        'indoorWalk': 'Walk indoors or in a mall (hot days)',
        'walkAfterIftar': 'Walk after iftar',
        'strength': 'Light strength at home (chair stands, wall push-ups)',
        'standUp': 'Stand up and walk around during the shift',
        'stretch': 'Stretch during breaks',
        'breathing': 'Slow breathing, at least 5 min',
      }[id]!;

  /// Up to 24 characters for the band's tiny screen.
  String habitShort(String id) => const {
        'sameWake': 'Same wake time',
        'bedEarlier': 'Bed a bit earlier',
        'bedWhenSleepy': 'Bed only when sleepy',
        'up20': 'Awake 20 min? Get up',
        'windDown': 'Relax before bed',
        'bedForSleep': 'Bed is for sleep',
        'quietRoom': 'Quiet cool bedroom',
        'dimLight': 'Dim lights tonight',
        'screensOff': 'Screens off 30 min',
        'lightMeal': 'Light evening meal',
        'noCaffeine': 'No coffee after noon',
        'noAlcohol': 'No alcohol at night',
        'lessFluid': 'Less drink before bed',
        'napBeforeShift': 'Nap before shift',
        'homeToBed': 'Home, then bed',
        'blackout': 'Curtains + ear plugs',
        'briskWalk': 'Brisk walk',
        'walkAfterMeal': 'Walk after a meal',
        'stairs': 'Take the stairs',
        'indoorWalk': 'Walk indoors',
        'walkAfterIftar': 'Walk after iftar',
        'strength': 'Light strength',
        'standUp': 'Stand up, walk',
        'stretch': 'Stretch at break',
        'breathing': 'Slow breathing 5 min',
      }[id]!;

  String bedEarlierDose(int minutes) => 'Go to bed $minutes min earlier';
  String walkDose(int perSession, int sessions) => '$perSession min × $sessions days this week';
  String walkGapDose(int perSession, int walks) =>
      '$walks more walk${walks == 1 ? '' : 's'} of $perSession min this week';
  String get walkGapMet => 'This week\'s target is reached. Keep the rhythm if you like.';

  // Today
  String get todayHabit => 'Today\'s small step';
  String get checkinQ => 'Did you do it today?';
  String get checkinDone => 'Done';
  String get checkinPartial => 'Partly';
  String get checkinNotToday => 'Not today';
  String checkinSaved(CheckinStatus s) => switch (s) {
        CheckinStatus.done => 'Saved: done.',
        CheckinStatus.partial => 'Saved: partly. Partly still counts.',
        CheckinStatus.notToday => 'Saved: not today. That is fine.',
      };
  String checkinResultTitle(CheckinStatus s, String habit) => switch (s) {
        CheckinStatus.done => 'Done: $habit',
        CheckinStatus.partial => 'Partly: $habit',
        CheckinStatus.notToday => 'Not today',
      };
  String checkinResultLine(CheckinStatus s) => switch (s) {
        CheckinStatus.done => 'Nice. Your bud bloomed.',
        CheckinStatus.partial => 'That counts. Your bud bloomed.',
        CheckinStatus.notToday => 'That is fine. Tomorrow is a new day.',
      };
  String get lastSleep => 'Last main sleep';
  String get sleepEstimate => 'Estimate from wrist movement';
  String sleepWindow(String from, String to) => '$from – $to';
  String asleep(int minutes) => 'about ${hours(minutes)} asleep';
  String get noSleepYet => 'No sleep window found yet. Wear the band to bed and sync.';
  String get stepsToday => 'Steps today';
  String get walkingToday => 'Brisk minutes today';
  String get walkingWeek => 'Brisk minutes, last 7 days';
  String get movementCard => 'Movement';
  String get walkingWeekShort => 'Brisk min, 7 days';
  /// 14597 -> "14,597" (no intl dependency).
  String count(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  String weekVsTarget(int done, int target) => '$done of $target min suggested';
  String sleepTarget(int minutes) => 'This step: ${hours(minutes)} per 24 h';
  String get fromBand => 'from the band';
  String get noBandData => 'No band data yet. Open Band to connect, or turn on the demo band in Settings.';
  String lastSync(String when) => 'Last sync $when';
  String get syncNow => 'Sync';
  String get doctorNote => 'Ask a doctor before increasing activity.';

  // Nudges (C5)
  String get welcomeBackTitle => 'Welcome back';
  String welcomeBackBody(String motivation) => motivation.isEmpty
      ? 'Good to see you. Start small again today; nothing you did before is lost.'
      : 'Remember your reason: "$motivation". Today just a small part is enough; nothing you did before is lost.';
  String get restartSmall => 'Restart one step smaller';
  String get stepUpTitle => 'Steady lately';
  String get stepUpBody => 'You did your habit on most days this week. Would you like to take the next small step?';
  String get stepUpYes => 'Yes, next step';
  String get keepAsIs => 'Keep it as it is';
  String get difficultyTitle => 'A bit hard lately?';
  String get difficultyBody => 'What got in the way? Then pick what helps.';
  List<String> get barriers => const ['Tired', 'No time', 'Heat', 'Shift change', 'Mood', 'Unwell'];
  String get shrink => 'Make it smaller';
  String get swap => 'Swap to a backup habit';
  String get move => 'Change reminder time';
  String recalibrate(int measured) =>
      'This week you moved about $measured minutes. Shall we adjust the plan to that?';
  String get adjust => 'Adjust';
  String get dangerTitle => 'Please get help now';
  String get dangerBody =>
      'What you wrote may be a sign that you need help now. BloomBack pauses suggestions. '
      'Please call your local emergency number (UAE: 999 or 998) or someone you trust.';

  // Week
  String get weekTitle => 'Week by week';
  String get weekIntro => 'Band numbers compared with your own first week. No scores.';
  String minutes(int m) => '$m min';
  String perWeek(int m) => '$m min / week';
  String minutesSoFar(int m, int days) =>
      days < 7 ? '$m min ($days ${days == 1 ? 'day' : 'days'} so far)' : '$m min';
  String weekLabel(int i) => 'Week ${i + 1}';
  String get avgSleep => 'Sleep per night';
  String get brisk => 'Brisk minutes';
  String get avgSteps => 'Steps per day';
  String get onsetSpread => 'Bedtime spread';
  String get habitDays => 'Days with your habit';
  String get youToldUs => 'At the start you told us';
  String daysBloomed(int n) => 'Days your habit bloomed so far: $n';
  String get exportFhir => 'Save or share my data (FHIR JSON)';
  String get review4w => '4-week check';
  String review4wQ(String goal) => 'Compared with the start, how is "$goal" now?';
  List<String> get review4wAnswers =>
      const ['Much better', 'A little better', 'About the same', 'A little worse', 'Much worse'];
  String get reviewSaved => 'Thanks. You can keep, step up or change your habit any time.';
  String get reviewDoctor =>
      'If sleep trouble goes on, it is worth talking to a doctor (AASM).';

  // Band
  String get bandTitle => 'Your band';
  String get bandNone => 'No band paired.';
  String get bandScan => 'Find my band';
  String get bandScanning => 'Looking for BloomBack bands…';
  String get bandPairHint =>
      'When asked, type the 6-digit code shown on the band\'s screen. Data moves only between your band and this phone.';
  String get bandConnect => 'Connect';
  String get bandForget => 'Forget band';
  String get bandForgetIos =>
      'Also open Settings > Bluetooth, tap (i) next to the band and choose Forget This Device. On the band, hold the button on the pairing screen to unpair.';
  String get bandDelete => 'Delete data on band';
  String get bandDeleteQ => 'Delete all minutes and check-ins stored on the band? Your phone copy stays.';
  String get bandDeleted => 'Band data deleted.';
  String bandStatus(String step) => 'Sync: $step';
  String bandSynced(int minutes, int checkins) => 'Synced $minutes minutes and $checkins check-ins.';
  String bandBattery(int b) => b < 0 ? 'Battery unknown' : 'Battery $b%';
  String bandInfo(int battery, String fw, int days) =>
      '${bandBattery(battery)} · fw $fw · $days days stored';
  String ago(Duration d) {
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} days ago';
  }

  String get demoBand => 'Demo band (synthetic data for persona Ravi)';

  // Settings
  String get settingsTitle => 'Settings';
  String get reminders => 'Reminders (at most 2 a day)';
  String get reminder1 => 'Reminder 1';
  String get reminder2 => 'Reminder 2';
  String get off => 'Off';
  String get quietHours => 'Quiet hours (no reminders)';
  String get quietFrom => 'From';
  String get quietTo => 'To';
  String get reminderInQuiet => 'This time is inside quiet hours, so it will not ring.';
  String get dayEnd => 'Day ends at (for sleep)';
  String get privacy => 'Your data';
  String get deletePhone => 'Delete my data on this phone';
  String get deletePhoneQ => 'Delete everything BloomBack stored on this phone, including your plan? This cannot be undone.';
  String get deletedPhone => 'All data on this phone deleted.';
  String get debug => 'Debug';
  String get fakeBand => 'Use demo band';
  String get fakeBandHint =>
      'Shows the whole app with synthetic data, no hardware needed. Switching clears band data on this phone.';
  String get changePlan => 'Change goals or plan';
  String get retention => 'Minute data older than 60 days is removed automatically.';

  // A1 inputs (day 1: required only)
  String get obAboutTitle => 'About you';
  String get obAboutBody =>
      'Needed on day 1. Other health numbers are optional and are offered after your first week.';
  String get obHeightQ => 'Height';
  String get obWeightQ => 'Weight';
  String get obHeightHint => '100 to 250 cm';
  String get obWeightHint => '30 to 300 kg';
  String get cm => 'cm';
  String get kg => 'kg';
  String get obCityQ => 'City';
  String cityLabel(City c) => switch (c) {
        City.abuDhabi => 'Abu Dhabi',
        City.alAin => 'Al Ain',
        City.dubai => 'Dubai',
        City.sharjah => 'Sharjah',
        City.otherUae => 'Other UAE',
        City.other => 'Other',
      };
  String get obNextNightsQ => 'Next switch to nights (optional)';
  String get obBreakQ => 'Usual break time (optional)';
  String get notSet => 'Not set';
  String get pickDate => 'Pick a date';
  String get workDays => 'Work days';
  String get daysOff => 'Days off';
  String spreadComputed(int minutes) =>
      'Bedtime changes by about ${minutes < 60 ? '$minutes min' : hours(minutes)} between work days and days off.';
  String get obWorkBriskQ => 'At work: minutes a week where you can talk but not sing (optional)';
  String get obWorkBriskHint =>
      'Only minutes that pass this talk test. They all count toward the 150 min (WHO 2020).';
  String planMoveWork(int walk, int credit, bool enough, int per, int sessions, int weekly, int leisure) {
    final next = enough
        ? 'Keep the rhythm.'
        : 'Suggested first step: $weekly min this week, $leisure of it outside work ($per min × $sessions days).';
    return 'You move about $walk min a week outside work, and $credit min a week is counted from '
        'your work; the guideline is 150-300. $next';
  }

  String get obGoalQ => 'Weekly movement goal';
  String get goal150 => '150 min (guideline)';
  String get goal300 => '300 min (my higher goal)';
  String get heavyNote =>
      'Heavy work: sleep, recovery and stretching come first; no extra heavy exercise is suggested.';

  // Environment on Today (B6, C4)
  String changeNote(HabitChange c, String planHabit) => switch (c) {
        HabitChange.none => '',
        HabitChange.firstNights =>
          'First days on nights: only sleep habits for now. "$planHabit" comes back after.',
        HabitChange.outdoorHeat =>
          'Hot season and outdoor work: no extra movement is suggested. Rest, water and sleep first. "$planHabit" comes back on 16 Sep.',
        HabitChange.heavyWork => 'Heavy work: no extra heavy exercise. Today: a gentler habit instead of "$planHabit".',
        HabitChange.fasting => 'Fasting mode: walks move to after iftar; no vigorous activity while fasting.',
        HabitChange.notAllowed => 'Today: a habit that fits your work instead of "$planHabit".',
      };
  String get heatNote =>
      'Hot season (15 Jun - 15 Sep): not outdoors 12:30-15:00. Early morning, after sunset or indoors.';
  String get fastingNote =>
      'Fasting mode is on: walk after iftar, no vigorous activity while fasting, and plan sleep around suhoor (the sleep target still counts per 24 h).';
  String get longShiftNote => 'Long or split shift: smaller parts, in your breaks.';
  String get irregularNote => 'Your reminders follow your check-ins, not fixed times.';
  String longShiftDose(int parts, int minutes, int sessions) =>
      '$parts × $minutes min in your breaks, $sessions days this week';
  String workCreditLine(int c) => 'Counted from your work: +$c min a week (moderate minutes you confirmed)';
  String leisureVsTarget(int done, int target) => '$done of $target min suggested outside work';

  // Lapse Radar (C5)
  String get radarNightsTitle => 'Nights are coming';
  String radarNightsBody(int days) =>
      'Your switch to nights is ${days == 1 ? 'tomorrow' : 'in $days days'}. For the first 2 days on nights '
      'BloomBack suggests sleep habits only. A short nap before the first night shift may help.';
  String get radarNextNightsTitle => 'Next switch to nights?';
  String get radarNextNightsBody =>
      'Add the date of your next switch to nights so BloomBack can give you a heads-up.';
  String get addDate => 'Add date';
  String get radarRamadanTitle => 'Ramadan is expected soon';
  String radarRamadanBody(DateTime from, DateTime to, bool inUae) =>
      'Expected ${inUae ? 'in the UAE ' : ''}from about ${date(from)} to ${date(to)} '
      '(approximate; confirm with the official announcement${inUae ? '' : '; it can differ by a day where you live'}). '
      'If you will fast, fasting mode moves walks to after iftar and moves reminders.';
  String get setUpFasting => 'Set up fasting mode';
  String get radarHeatTitle => 'Hot season starts soon';
  String radarHeatBody(int days) =>
      'From 15 Jun (in $days ${days == 1 ? 'day' : 'days'}) BloomBack suggests no outdoor movement 12:30-15:00: '
      'early morning, after sunset or indoors.';
  String get hide => 'Hide';

  // Optional health numbers (A1, B1, D2)
  String get bioOfferTitle => 'Optional: a few health numbers';
  String get bioOfferBody =>
      'Waist, blood pressure, resting heart rate, blood sugar. "Don\'t know" is fine. They never change your plan.';
  String get add => 'Add';
  String get bioTitle => 'Health numbers (optional)';
  String get bioIntro =>
      'Only used to show "Ask a doctor before increasing activity" when a number reaches a reference level. '
      'They never change your plan. Leave any you don\'t know.';
  String get waist => 'Waist';
  String get bloodPressure => 'Blood pressure';
  String get systolic => 'Upper (systolic)';
  String get diastolic => 'Lower (diastolic)';
  String get restingHr => 'Resting heart rate';
  String get bpm => 'beats/min';
  String get glucose => 'Fasting blood sugar';
  String get mmolL => 'mmol/L';
  String get mgDl => 'mg/dL';
  String get hba1c => 'HbA1c';
  String get dontKnow => 'Don\'t know';
  String get bioSourceQ => 'Where are these numbers from?';
  String get srcSelf => 'Typed by me';
  String get srcCheckup => 'From a check-up';
  String get measuredOn => 'Measured on';
  String get save => 'Save';
  String get bioSaved => 'Saved. These numbers never change your plan.';

  // Sleep regularity (C2)
  String get spreadTitle => 'Regular bedtimes';
  String spreadText(int m) => m <= 59 ? 'under 1 h' : hours(m);
  String spreadOffer(int current, bool fromBand, int target) =>
      'Your bedtime spread is about ${hours(current)} (${fromBand ? 'band' : 'you told us'}). '
      'Suggested for the next 2 weeks: keep bedtimes within ${spreadText(target)} of each other.';
  String spreadTarget(int target) => 'Bedtimes within ${spreadText(target)} of each other';
  String get tryIt => 'Try it';

  // C5 "Move"
  String get moveTitle => 'Move today\'s reminder';
  String get moveBody => 'Pick a better time. It changes today only, unless you keep it.';
  String get moveKeep => 'Keep this time from now on';
  String get moveOneOff => 'Remind me today at';
  String moveSaved(String t) => 'Reminder moved to $t.';
  String get moveMidday =>
      'Hot season: an outdoor walk is not suggested 12:30-15:00, so this reminder will move to after sunset.';
  String reminderN(int i) => 'Reminder ${i + 1}';

  // Settings additions
  String get aboutYou => 'About you';
  String get workSettings => 'Your work';
  String get workBrisk => 'Moderate minutes at work per week (talk test)';
  String get irregularGap => 'Reminder after last check-in';
  String get remindersFollowCheckins =>
      'Irregular hours: reminders follow your check-ins and app opens, not fixed times.';
  String get fastingTitle => 'Fasting mode';
  String get fastingOffText => 'Off';
  String fastingOnText(String from, String to) => 'On from ${dateK(from)} to ${dateK(to)}';
  String fastingSuggest(DateTime from, DateTime to, bool inUae) =>
      'Suggested${inUae ? ' for the UAE' : ''}: about ${date(from)} - ${date(to)} (Ramadan 1448, approximate; confirm).';
  String get useDates => 'Use these dates';
  String get pickDates => 'Pick other dates';
  String get turnOff => 'Turn off';
  String get fastingPrivacy => 'BloomBack stores only that fasting mode is on and its dates, never a reason.';
  String get edit => 'Edit';
  String get hoursUnit => 'h';

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
  String dateK(String? k) {
    final d = parseDateKey(k);
    return d == null ? notSet : date(d);
  }

  // Demo scenarios and the web demo (Settings > Debug, demo band only)
  // ---------------------------------------------------------------------------
  // Chi's screen design (13 Nov), screens 1-24
  // ---------------------------------------------------------------------------
  String get continueLabel => 'Continue';
  String get optional => '(optional)';
  String get whyTitle => 'Why this suggestion?';
  String get yourTarget => 'Your target';
  String get openSource => 'Open source';
  String linkCopied(String url) => 'Link copied: $url';
  String get bbSuggestion => 'BloomBack suggestion';
  String get estimate => 'estimate';
  /// Chi Q2: wording everywhere sleep from the band is shown.
  String get bandSleepNote =>
      'Estimated from wrist movement, not a medical sleep test. Best at bedtime and wake time; '
      'less accurate when lying still awake. Method: van Hees et al., 2015, 2018.';

  // 1 Start
  String get tagline1 => 'Small steps.';
  String get tagline2 => 'Easy restarts.';
  String get startBody => 'Better sleep and movement that fit your shifts. No scores. No streaks to lose.';
  String get getStarted => 'Get started';
  String get haveAccount => 'I already have an account';
  String get english => 'English';
  String get arabic => 'العربية';
  String get arabicSoonTitle => 'Arabic is coming soon';
  String get arabicSoonBody =>
      'The Arabic version is being translated and needs a check by a native speaker before it is used. '
      'For now BloomBack is in English.';

  // 2 Sign in
  String get signInHeader => 'Create your account';
  String get signInTitle => 'Keep Pro and the coach on any phone';
  String get signInBody => 'Your plan and garden stay on this phone. An account is only for Pro and the coach.';
  String get withApple => 'Continue with Apple';
  String get withGoogle => 'Continue with Google';
  String get withEmail => 'Continue with email (one-time code)';
  String get nameQ => 'What should we call you?';
  String get nameHint => 'First name or nickname';
  String get nameNote => 'A first name or nickname is enough. We never ask for your phone number or Emirates ID.';
  String get lockNote => 'Your health data is yours. You can download or delete it anytime.';
  String get tryWithout => 'Try without an account';
  String get pilotTitle => 'Accounts start with the pilot';
  String get pilotBody =>
      'Accounts start with the pilot. For now BloomBack keeps everything on this phone; you can download your data anytime.';
  String get continueWithout => 'Continue without an account';

  // 3 Your choices
  String get choicesHeader => 'Your choices';
  String get choicesTitle => 'You decide what we use';
  String get choicesBody => 'Turn each one on or off. You can change them anytime in More.';
  String get useAnswers => 'Use my answers to make my plan';
  String get useAnswersSub => 'Needed for the app to work';
  String get syncChoice => 'Sync my phone or watch';
  String get syncChoiceSub => 'Steps and sleep. Coming later';
  String get shareChoice => 'Share with someone I invite';
  String get shareChoiceSub => 'Only "done today". Set up later';
  String get choicesNote =>
      'We don\'t sell your data or show ads. For now everything stays on this phone; in the pilot, '
      'health data is stored in the UAE.';
  String get useAnswersNeeded => 'BloomBack needs your answers to suggest a plan. Turn this on to continue.';

  // 4 Work
  String get workHeader => 'About your work';
  String get workTitle => 'Tell us about your work';
  String get workBody => 'So we only suggest things that fit your day.';
  String get activityQ => 'How active is your job?';
  String activityChip(WorkActivity a) => switch (a) {
        WorkActivity.sitting => 'Mostly sitting',
        WorkActivity.standingLight => 'Standing / light walking',
        WorkActivity.moderate => 'Moderate',
        WorkActivity.heavy => 'Heavy',
      };
  String activityExample(WorkActivity a) => switch (a) {
        WorkActivity.sitting => 'For example office work, driving, a seated guard.',
        WorkActivity.standingLight => 'For example a shop, a cashier, a nurse on the ward.',
        WorkActivity.moderate => 'Your heart beats faster: a waiter, walking delivery, cleaning.',
        WorkActivity.heavy => 'You breathe hard: building, loading.',
      };
  String get shiftQ => 'Your shift';
  String shiftChip(ShiftType x) => switch (x) {
        ShiftType.dayFixed => 'Fixed day',
        ShiftType.nightFixed => 'Fixed night',
        ShiftType.rotating => 'Rotating',
        ShiftType.longOrSplit => 'Long / split',
        ShiftType.irregular => 'Irregular',
      };
  String get placeQ => 'Where do you work?';
  String placeChip(WorkPlace p) => switch (p) {
        WorkPlace.indoor => 'Indoors (AC)',
        WorkPlace.outdoor => 'Outdoors',
        WorkPlace.both => 'Both',
      };
  String get cityHint => 'Choose your city (optional)';
  String get skipForNow => 'Skip for now';

  // 5 Sleep and movement now
  String get nowHeader => 'Your sleep and movement';
  String get nowTitle => 'How do you sleep and move now?';
  String get nowBody => 'A rough guess is fine. Your first week becomes your starting point.';
  String get sleepUsually => 'Sleep, usually';
  String get fallAsleepAt => 'Fall asleep at';
  String get wakeUpAt => 'Wake up at';
  String get addNap => '+ Add a nap';
  String get nap => 'Nap';
  String get removeNap => 'Remove nap';
  String hoursOfSleep(int minutes) => '≈ ${hoursDecimal(minutes).replaceAll(' h', '')} h on work days';
  String dayPart(int minuteOfDay) {
    final h = minuteOfDay ~/ 60;
    if (h >= 5 && h < 12) return 'morning';
    if (h >= 12 && h < 17) return 'afternoon';
    if (h >= 17 && h < 21) return 'evening';
    return 'night';
  }

  String get exerciseQ => 'How often do you exercise, outside of work?';
  String get exerciseHint =>
      'Things like brisk walking, cycling, swimming or sports, where you can talk but not sing.';
  String get daysPerWeek => 'Days per week';
  String get minutesEachTime => 'Minutes each time';
  String exerciseTotal(int m) => '≈ $m min a week';
  String get talkTest => 'The talk test';

  // 6 Body measures
  String get bodyHeader => 'Body measures';
  String get bodyTitle => 'A few body measures';
  String get bodyBody => 'Only to see your own trend over time. We never diagnose.';
  String get optionalLater => 'Optional · add later if you like';
  String get glucoseOrA1c => 'Fasting glucose or HbA1c';
  String get bodySourceNote => 'Each number keeps its source: self-reported, health check or device.';
  String markerSource(MarkerSource m) => m == MarkerSource.selfReport ? 'Self-reported' : 'From a health check';
  String get clear => 'Clear';

  // 7 / 7b Safety
  String get safetyHeader => 'Before you start';
  String get safetyTitle => 'A quick safety check';
  String get safetyQ1 =>
      'Do you have heart disease, diabetes or kidney disease, or chest pain, dizziness or breathlessness when active?';
  String get safetyQ2 => 'Are you pregnant or recently gave birth?';
  String get safetyNoteTitle => 'Please talk to your doctor before increasing activity';
  String get safetyNoteBody => 'You can still use BloomBack. Start gently and check with your doctor.';
  String get understandContinue => 'I understand · Continue';

  // 8 Goals
  String get goalsHeader => 'Your goal';
  String get goalsTitle => 'What would you like to change?';
  String get goalsHint => 'Pick up to 3.';
  String get mattersMost => 'Which one matters most?';
  String get whyMatters => 'Why does this matter to you?';
  String get motivationHint => 'e.g. So I still have energy to video-call my kids';

  // 9 Your picture
  String get pictureTitle => 'Here\'s where you are today';
  String get pictureBody => 'No scores. Just a starting point.';
  String get recSleep => 'recommended 7 h or more';
  String get recMove => 'recommended 150 min / week';
  String atWorkIncluded(int n) => 'includes $n min at work';
  String suggestsStart(Domain d) => 'BloomBack suggests starting with ${domainLabel(d).toLowerCase()}';
  String suggestGoal(String goal) => 'It matches your main goal "$goal".';
  String get suggestHeavy => 'With heavy work, sleep and recovery come first.';
  String get suggestGap => 'It is the area furthest from the recommendation, for your main goal.';
  String get whereStart => 'Where do you want to start?';
  String get bothAreas => 'Both';

  // 10 Your plan
  String get sleepPlanHeader => 'Your sleep plan';
  String get planHeader => 'Your plan';
  String get sleepPathTitle => 'A gentle path to 7 hours';
  String get sleepKeepTitle => 'Keep your sleep rhythm';
  String get movePathTitle => 'A gentle path to 150 minutes';
  String get moveHealthyTitle => 'You\'re already in the healthy range';
  String get moveWhatNext => 'What would you like to do?';
  String get keepRhythm => 'Keep my rhythm';
  String get suggestedTag => 'suggested';
  String aboutWeekly(int m) => 'About $m min a week';
  String get toward300 => 'Move towards 300 min';
  String get toward300Sub => 'Extra benefits (HHS 2018)';
  String get addStrength => 'Add muscle strengthening 2 days a week';
  String get addStrengthSub => 'DHA 2026';
  String get above300Note => 'Above 300 min: keep the rhythm; sleep and recovery come first.';
  String get neverLower => 'BloomBack never sets a goal lower than what you already do.';
  String get keepWake => 'Keep your wake-up time the same';
  String get keepWakeBody => 'Every day, even days off. Then go to bed a little earlier.';
  String wakeLine(String wake, String bed) => 'Wake up at $wake. This step: asleep by $bed.';
  String get suggestedPace => 'Suggested pace';
  String get paceRange => '15–30 min earlier every 1–2 weeks';
  String get pace30 => '+30 min per step (suggested)';
  String get pace15 => '+15 min per step (gentler)';
  String get nowShort => 'now';
  String wk(int a, int b) => 'wk $a–$b';
  String get goalShort => 'goal';
  String get howGo => 'How do you want to go?';
  String get followSuggestion => 'Follow the suggestion';
  String get goSlower => 'Go slower';
  String get ownPace => 'Set my own goal and pace';
  String get ownFirstStep => 'First step';
  String get ownStepSize => 'Step size';
  String get changeAnytime => 'You can change your goal or pace anytime.';
  String get moveCardTitle => 'Movement';
  String moveLadderText(int perSession, int sessions, bool fromZero, {int goal = 150}) => fromZero
      ? 'Start with $perSession min × $sessions days, then a little more every 1–2 weeks.'
      : 'This week $perSession min × $sessions days, then +10 min a week up to $goal.';
  String movePace(int weekly) => '$weekly min this week';

  // 11 Pick one small step
  String get stepHeader => 'Your small step';
  String get stepTitle => 'Pick one small step';
  String stepFits(ShiftType x) => 'Fits ${switch (x) {
        ShiftType.dayFixed => 'a fixed day shift',
        ShiftType.nightFixed => 'a fixed night shift',
        ShiftType.rotating => 'rotating shifts',
        ShiftType.longOrSplit => 'long or split shifts',
        ShiftType.irregular => 'irregular hours',
      }}. Tick 1–2 as backup.';
  String get backup => 'Backup';
  String get partOfDay => 'Make it part of your day';
  String cue(String anchor, String action) => 'After I $anchor, I will $action.';
  String get afterI => 'After I';
  String get iWill => 'I will';
  String get remindAt => 'Remind me at';
  String get startTomorrow => 'Start tomorrow';
  String get yourOwnWords => 'In your own words';
  String habitAnchor(String id) => switch (id) {
        'homeToBed' || 'blackout' => 'get home from my shift',
        'napBeforeShift' => 'have my meal before the night shift',
        'sameWake' => 'my alarm goes off',
        'bedEarlier' || 'windDown' || 'dimLight' || 'screensOff' || 'quietRoom' || 'bedForSleep' => 'finish dinner',
        'bedWhenSleepy' || 'up20' => 'turn off the light',
        'lightMeal' || 'lessFluid' || 'noAlcohol' => 'start my evening',
        'noCaffeine' => 'have lunch',
        'walkAfterMeal' || 'walkAfterIftar' => 'finish my meal',
        'standUp' || 'stretch' => 'start my break',
        'breathing' => 'get into bed',
        _ => 'finish work',
      };
  String habitAction(String id) => switch (id) {
        'homeToBed' => 'draw the curtains and go to bed',
        'blackout' => 'put on my eye mask and earplugs',
        'napBeforeShift' => 'take a short nap',
        'briskWalk' => 'go for a brisk walk',
        'indoorWalk' => 'walk indoors',
        _ => habit(id)[0].toLowerCase() + habit(id).substring(1),
      };

  // 12 Today
  String get shiftDone => 'Shift done';
  String get beforeShift => 'Before your shift';
  String get onShift => 'On shift';
  String restWell(String name) => name.isEmpty ? 'Rest well' : 'Rest well, $name';
  String goodMorning(String name) => name.isEmpty ? 'Good morning' : 'Good morning, $name';
  String goodAfternoon(String name) => name.isEmpty ? 'Good afternoon' : 'Good afternoon, $name';
  String goodEvening(String name) => name.isEmpty ? 'Good evening' : 'Good evening, $name';
  String get sleepThisWeek => 'Sleep this week';
  String get average => 'average';
  String goalThisWeek(int minutes) => 'goal this week ${hoursDecimal(minutes)}';
  String get sleepYouToldUs => 'you told us';
  String get noBandSleep => 'No band nights yet. Your plan works without a band.';
  String get yourGarden => 'Your garden';
  String daysBloomedN(int n) => '$n ${n == 1 ? 'day' : 'days'} bloomed';
  String get gardenNote => 'Days never reset. Missed days don\'t wilt anything.';
  String get fourWeeksCard => 'You are 4 weeks in. How is it going?';
  String get answer => 'Answer';
  String hm(int minutes) => '${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')} m';

  // 13 Why
  String whyYouChose(List<String> goals, ShiftType shift) {
    final g = goals.map((x) => '"$x"').toList();
    final chose = g.length <= 1 ? g.join() : '${g.sublist(0, g.length - 1).join(', ')} and ${g.last}';
    final work = switch (shift) {
      ShiftType.dayFixed => 'you work fixed days',
      ShiftType.nightFixed => 'you work fixed nights',
      ShiftType.rotating => 'you work rotating shifts',
      ShiftType.longOrSplit => 'you work long or split shifts',
      ShiftType.irregular => 'your hours are irregular',
    };
    return 'You chose $chose, and $work.';
  }

  String targetSleep(int stepTarget) =>
      'American Academy of Sleep Medicine · Healthy Sleep Habits: at least 7 hours. This step: ${hours(stepTarget)} per 24 h.';
  String targetMove(int weekly) =>
      'HHS 2018 and WHO 2020: 150 minutes of moderate activity a week. This week: $weekly min.';

  // 14 Welcome back
  String welcomeBackName(String name) => name.isEmpty ? 'Welcome back' : 'Welcome back, $name';
  String bloomedStillHere(int n) =>
      n == 0 ? 'Nothing you did before is lost.' : 'Your $n bloomed ${n == 1 ? 'day is' : 'days are'} all still here.';
  String get yourReason => 'Your reason';
  String get whatGotInWay => 'What got in the way?';
  List<String> get barriersChi => const ['Tired', 'No time', 'Too hot', 'Shift change', 'Low mood', 'Sick'];
  String get restartSmallTitle => 'Let\'s restart small';
  String get makeSmallerSub => 'One step back for now. Nothing is reset.';
  String get swapShort => 'Swap';
  String swapSub(String backup) => 'Use your backup: $backup';
  String get moveTime => 'Move the time';
  String get moveTimeSub => 'Remind me later today';
  String get restartToday => 'Restart today';

  // 15 4 weeks in
  String get fourWeeksHeader => '4 weeks in';
  String get howGoing => 'How is it going?';
  String comparedWith(String goal) => 'Compared with when you started, how is "$goal"?';
  String get numbersW1W4 => 'Your numbers · week 1 → week 4';
  String get sleepPerNight => 'Sleep / night';
  String get daysDone => 'Days done';
  String daysDoneWeek(int a, int b) => '$a → $b / week';
  String get whatNext => 'What next?';
  String get keep => 'Keep';
  String get stepUpShort => 'Step up';
  String get change => 'Change';
  String heroGardenLabel(int flowers, {required bool waiting}) =>
      '$flowers ${flowers == 1 ? 'flower' : 'flowers'}${waiting ? " · today's bud" : ''}';
  String get keptPlan => 'Kept as it is.';
  String get steppedUp => 'Next small step saved.';

  // 16 Someone to cheer you on
  String get companionTitle => 'Someone to cheer you on';
  String get inviteOne => 'Invite one person';
  String get inviteBody => 'Family or a friend, even far away. They don\'t need the app.';
  String get companionName => 'Name';
  String get companionNameHint => 'e.g. My wife';
  String get theyWillSee => 'They will see';
  String get seeDone => 'When you finish today\'s step';
  String seeBack(String name) => '"${name.isEmpty ? 'Your friend' : name} is back" after a break';
  String get neverSee => 'They will never see';
  String get neverMissed => 'Missed days or reasons';
  String get neverNumbers => 'Your health numbers';
  String get sharingOn => 'Sharing on';
  String get sharingPilot => 'Available in the pilot';
  String get cheerNote => 'They can send a cheer with one tap: a clap, "Proud of you" or "Rest well".';
  String get sendInvite => 'Send invite link';
  String get invitePilotBody =>
      'Sharing needs our server, which starts with the pilot. Nothing was sent and nothing was saved.';
  String get notInvited => 'Not invited yet';

  // 17 Ramadan
  String get ramadanTitle => 'Ramadan';
  String get ramadanComing => 'Ramadan is coming';
  String expectedIn(String place) => 'Expected in $place';
  String dateRange(DateTime a, DateTime b) => '${dayDate(a)} – ${dayDate(b)} ${b.year}';
  String get ummAlQura => 'Based on the Umm al-Qura calendar. Official dates may differ by a day.';
  String get thatsRight => 'That\'s right';
  String get fastingModeSub => 'Walks after iftar, sleep around suhoor, no hard exercise while fasting';
  String get ramadanPrivacy =>
      'Optional. We don\'t ask about or store your religion. Reminders move to after iftar (19:30) and before suhoor (21:30).';
  String get yourStepRamadan => 'Your step during Ramadan';
  String get ramadanSaved => 'Saved.';
  String get fastingOn => 'Fasting mode on';
  String get fastingOff => 'Fasting mode off';
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String dayDate(DateTime d) => '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

  // 20 Plan tab
  String get planTitle => 'Your plan';
  String get mainGoal => 'Main goal';
  String yourReasonLine(String m) => 'Your reason: "$m"';
  String get startShort => 'start';
  String get thisWeekShort => 'this week';
  String get nextShort => 'next';
  String perStep(int n) => '+$n min per step';
  String get changePace => 'Change pace';
  String get yourSmallStep => 'Your small step';
  /// Plan tab: the reminder times that will ring (0, 1 or 2) and the quiet hours.
  String reminderLine(List<String> times, String qs, String qe) => '${switch (times.length) {
        0 => 'No reminders',
        1 => 'Reminder ${times.first}',
        _ => 'Reminders ${times.join(' and ')}',
      }} · Quiet hours $qs–$qe';
  String get moveNotStarted => 'Not started yet. Add when you\'re ready.';
  String get addMoveTitle => 'Add movement';
  String addMoveBody(int per, int sessions) =>
      'Suggested start: $per min × $sessions days this week. You can change it anytime.';
  String get addMoveConfirm => 'Add movement';
  String get sleepNotStarted => 'Not started yet. Add when you\'re ready.';
  String get addSleepTitle => 'Add sleep';
  String addSleepBody(int target) => 'Suggested first step: ${hours(target)} per 24 h. You can change it anytime.';
  String get weeklyGoal => 'Weekly goal';

  // 21 Garden
  String get gardenTitle => 'Your garden';
  String get gardenBody => 'Every day you do your step, even partly, a flower blooms. Nothing ever wilts.';
  String get greyNote => 'Grey days just didn\'t bloom. They never count against you.';
  String get week1Now => 'Week 1 → now';
  String get sleep24 => 'Sleep / 24 h';
  String get cameBack => 'Came back after a break';
  String times(int n) => '$n ${n == 1 ? 'time' : 'times'}';
  String get sameSource => 'Compared only with yourself, from the same source.';
  String get weekByWeek => 'Week by week (band numbers)';
  static const _monthsLong = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  String monthName(int m) => _monthsLong[m - 1];
  String dayDoneLabel(int day, CheckinStatus? st) => switch (st) {
        CheckinStatus.done => '$day: bloomed (done)',
        CheckinStatus.partial => '$day: bloomed (partly)',
        _ => '$day',
      };

  // 22 More
  String get moreTitle => 'More';
  String get remindersRow => 'Reminders';
  String get remindersRowSub => '2 a day max · quiet while you sleep';
  String get bandRow => 'BloomBack band (optional)';
  String get notConnected => 'Not connected';
  String get connected => 'Connected';
  String get languageRow => 'Language';
  String get yourData => 'Your data';
  String get whatWeUse => 'What we use';
  String get whatWeUseSub => '4 choices · change anytime';
  String get downloadData => 'Download my data';
  String get downloadDataSub => 'Standard health format (FHIR)';
  String get deleteEverything => 'Delete everything';
  String get deleteEverythingSub => 'From this phone, and the band if paired';
  String get deleteEverythingQ =>
      'Delete everything BloomBack stored on this phone (and on the band, if one is paired), including your plan? This cannot be undone.';
  String get sourcesRow => 'Sources behind every tip';
  String get sourcesRowSub => 'WHO, DHA, HHS, AASM, CDC, NHS, NIOSH';
  String get aboutRow => 'About BloomBack';
  String get aboutRowSub => 'Suggestions, not medical advice';
  String get demoSection => 'Demo and testing';
  String get yourAnswers => 'Your answers';
  String get noDataYet => 'No data to download yet.';
  String get aboutBody =>
      'BloomBack suggests small sleep and movement habits from official guidelines (AASM, CDC, WHO, '
      'DHA, HHS, NIOSH, NHS). It never diagnoses and gives suggestions, not medical advice. You decide '
      'everything. Your data stays on your phone and your band. Made for the Future Health challenge, Abu Dhabi.';
  String get sourcesIntro =>
      'Every suggestion in BloomBack comes from one of these. Tap "?" next to any tip to see its source.';
  String get habitsSources => 'Habits';
  String get levelsSources => 'Levels and steps';
  String get environmentSources => 'Work, heat and Ramadan';
  String get bandSources => 'Band estimates';

  // 23 / 24 Band
  String get bandHeader => 'BloomBack band';
  String get pairTitle => 'Pair your BloomBack band';
  String get pairBody => 'Optional. Without a band, BloomBack works fully with what you tell it.';
  String get holdButton => 'Hold the band button for 3 seconds. A 6-digit code appears.';
  String get enterCode => 'Enter the code shown on your band';
  String get bandPrivacy =>
      'Only your phone can read your band after pairing. The band has no GPS, microphone or heart sensor.';
  String get pairBand => 'Pair band';
  String get realBandCodeHint => 'Find your band below. Your phone asks for the 6-digit code when it connects.';
  String get yourBand => 'Your band';
  String syncedAgo(String when) => 'Synced $when';
  String get lastMainSleep => 'Last main sleep';
  String get fromWrist => 'From wrist movement. Includes daytime sleep after night shifts.';
  String get briskMin7 => 'Brisk min · 7 days';
  String nextToOwn(int n) => 'next to your own $n';
  String get whyEstimate => 'Why "estimate"?';
  String get bandSettings => 'Band settings';
  String get noSleepWindow => 'No sleep window yet. Wear the band to bed and sync.';

  String get demoBanner => 'Demo with synthetic data. Real use: the iPhone or Android app + optional band.';
  String get demoScenarios => 'Demo scenarios';
  String get demoScenariosHint => 'Reset the app to a ready-made state with synthetic data (persona Ravi).';
  String get demoScenariosShort => 'Scenarios';
  String get demoScenarioQ =>
      'Load this scenario? It replaces all BloomBack data on this device with synthetic demo data.';
  String get demoLoading => 'Loading the scenario...';
  String demoLoaded(String title) => 'Loaded: $title';
  String scenarioTitle(DemoScenario sc) => switch (sc) {
        DemoScenario.fresh => 'Fresh start',
        DemoScenario.week3 => 'Week 3, steady',
        DemoScenario.welcomeBack => 'Welcome back',
        DemoScenario.hardLately => 'A bit hard lately',
        DemoScenario.nightsSoon => 'Nights are coming',
      };
  String scenarioDescription(DemoScenario sc) => switch (sc) {
        DemoScenario.fresh => 'No data and no plan yet: starts at onboarding.',
        DemoScenario.week3 =>
          'Ravi started 15 days ago, band synced, done on most days: BloomBack offers a small step up.',
        DemoScenario.welcomeBack =>
          'Ravi started 10 days ago and checked in, then 2 days without: welcome back with his own sentence.',
        DemoScenario.hardLately => 'Ravi answered "partly" on 3 of the last 5 days: shrink, swap or move the habit.',
        DemoScenario.nightsSoon => 'Ravi on a rotating shift, switching to nights in 2 days: a heads-up to plan sleep.',
      };
  String get webDemoBandOnly => 'The web demo uses the demo band only. A real band needs the Android app.';
  String get webNoReminders =>
      'This web demo does not send reminders. In the Android app they arrive as phone notifications '
      'at these times (at most 2 a day, never in quiet hours).';


  // Movement without a band, and already in the healthy range (thread 0004 fixes 4-5, designs 12b/12d/20b)
  String get thisWeekCaps => 'This week';
  String get fromCheckins => 'from your check-ins';
  String daysOfPlan(int done, int planned) => '$done of $planned days';
  String get yourPlan => 'your plan';
  String get movementCaps => 'Movement';
  String toldUsHealthy(int m) => 'You told us about $m min a week, in the healthy range. Keep your rhythm.';
  String toldUsTowards(int m, int goal) => 'You told us about $m min a week. Your plan: towards $goal min, a little at a time.';
  String get activeMinutes7 => 'Active minutes · 7 days';
  String get fromTheBand => 'from the band';
  String yourUsual(int m) => 'your usual: about $m';
  String get bandCountsWalking => 'Counts minutes with 100+ steps (walking only). Cycling or gym may not show.';
  String get activeMinutesSource =>
      'Active minutes are minutes with at least 100 steps, measured by the band (Tudor-Locke et al., Br J Sports Med '
      '2018). They count walking only, so cycling, swimming or gym work may not show.';
  String healthyRangeLine(int m) => '$m min';
  String get healthyRange => 'healthy range 150–300';
  String get yourChoice => 'your choice';
  String moveChoiceLabel(String c) => switch (c) {
        'to300' => 'Move towards 300 min',
        'strength' => 'Add muscle strengthening',
        _ => 'Keep my rhythm',
      };
  String get keepRhythmDose => 'Keep your usual rhythm';
  String get stairsDose => 'Start with 2 floors';
  String get strengthDose => '2 days a week, a few minutes';
  String notSignedInName(String name) => '$name · not signed in';
  String get notSignedInLine => 'Your plan stays on this phone. Sign in to keep Pro and the coach.';

  // Account (thread 0003): email code, Apple, Google; Pro and the coach
  String get accountRow => 'Account';
  String get accountRowOut => 'Not signed in';
  String accountRowIn(String who) => 'Signed in · $who';
  String get accountTitle => 'Account';
  String get accountWhy =>
      'An account keeps BloomBack Pro and the coach with you on any phone. Your plan, check-ins, garden and band data stay on this phone.';
  String get signInWith => 'Sign in';
  String get emailTitle => 'Sign in with email';
  String get emailBody => 'We email you a 6-digit code. No password.';
  String get emailLabel => 'Email address';
  String get sendCode => 'Send code';
  String get codeTitle => 'Enter the code';
  String codeBody(String email) => 'We sent a 6-digit code to $email. It works for 10 minutes. Look in spam if it is not there.';
  String get codeLabel => '6-digit code';
  String get signInButton => 'Sign in';
  String get resendCode => 'Send a new code';
  String get codeSent => 'A new code is on its way.';
  String get signedInAs => 'Signed in as';
  String get viaEmail => 'Email code';
  String get viaApple => 'Sign in with Apple';
  String get viaGoogle => 'Google';
  String get signOut => 'Sign out';
  String get signOutBody => 'You can sign in again anytime. Everything on this phone stays.';
  String get deleteAccount => 'Delete my account';
  String get deleteAccountBody =>
      'This deletes your account from our server now: email, sign-ins, first name, Pro and question counts. '
      'Your plan and garden on this phone stay. A Pro purchase can be restored to a new account later.';
  String get deleteAccountConfirm => 'Delete account';
  String get accountDeleted => 'Your account was deleted.';
  String get signedInNow => 'Signed in. BloomBack Pro and the coach now follow your account.';
  String get accountsInApp => 'Accounts are in the phone app';
  String get accountsInAppBody =>
      'This web demo has no server connection. In the phone app you can sign in with an email code, Apple or Google.';

  // Pro
  String get proName => 'BloomBack Pro';
  String get proRowOff => 'Not active';
  String get proLifetime => 'Active, for good';
  String proUntil(DateTime d) => 'Active until ${date(d)}';
  String get proPitch => 'Ask the coach how your habits can fit your days, whenever you need, up to 20 questions a day.';
  String get proPoint1 => 'Ask BloomBack: answers built from your plan\'s habits, each with its source';
  String get proPoint2 => 'Up to 20 questions a day';
  String get proPoint3 => 'One purchase, on every phone you sign in to';
  String get proFreeNote => 'Your plan, garden, reminders and the band stay free, always.';
  String proBuy(String price) => 'Get Pro · $price';
  String get proBuyNoPrice => 'Get Pro';
  String get proUnavailable => 'The store is not available on this phone right now.';
  String get restorePurchases => 'Restore purchases';
  String get redeemCode => 'Redeem a code';
  String get redeemLabel => 'Code, for example BB-7KQ2-M9XD';
  String get redeem => 'Redeem';
  String redeemDone(int days) => 'Code accepted: BloomBack Pro for $days days.';
  String get signInForPro => 'Sign in first, so Pro stays with your account on any phone.';

  // Ask BloomBack (the coach)
  String get askTitle => 'Ask BloomBack';
  String get askRowSub => 'Questions about your sleep and movement habits';
  String get askIntro =>
      'Ask how a habit could fit your day. Answers only use habits from BloomBack\'s list, with their sources. '
      'Not for symptoms or medicines: ask your doctor.';
  String get askHint => 'For example: I work nights, when should I nap?';
  String get askSend => 'Ask';
  String askLeftFree(int n) => '$n free question${n == 1 ? '' : 's'} left';
  String askLeftPro(int n) => 'Pro · $n question${n == 1 ? '' : 's'} left today';
  String get askSignIn => 'Sign in to ask the coach. Three questions are free.';
  String get askThinking => 'The coach is thinking…';
  String get askHabitsUsed => 'Habits in this answer';
  String get askSeeDoctor => 'A question for your doctor';
  String get askPrivacy => 'Your question goes to our server and an AI model to write the answer, and is not stored. '
      "We never send the health numbers you saved, your name or your email. Please don't type them in your question.";
  String get askSamples1 => 'I work nights. How can I sleep better in the day?';
  String get askSamples2 => 'It is too hot to walk outside. What can I do?';
  String get askSamples3 => 'I wake up at 3 am and cannot fall asleep again.';
  String get reportAnswer => 'Report this answer';
  String get reportHarmful => 'Harmful or unsafe';
  String get reportWrong => 'Wrong or not helpful';
  String get reportOther => 'Something else';
  String get reportNote => 'Note (optional)';
  String get reportIncludeAnswer => 'Send the answer text with the report';
  String get reportSend => 'Send report';
  String get reportThanks => 'Thank you. The BloomBack team will look at it.';

  // Notifications
  String get notifChannel => 'Habit reminders';
  String notifMorning(String habit) => 'Today\'s small step: $habit';
  String notifLater(String habit) => 'A good moment for: $habit';

  // After my small step: sound, today's question, anonymous research (Chi, thread 0007)
  String get afterStepTitle => 'After my small step';
  String get afterStepBody => 'Choose what happens when you tap Done or Partly. The flower always blooms.';
  String afterStepRow(String sound, int quiz) =>
      'Sound ${sound == 'off' ? 'off' : 'on'} · ${quiz == 0 ? 'no question' : quiz == 1 ? '1 question a day' : '$quiz questions a day'}';
  String get soundTitle => 'Sound';
  String get soundOff => 'Off';
  String get soundChime => 'Chime';
  String get soundSong => 'My song';
  String chimeName(String id) => switch (id) { 'wind' => 'Wind chime', 'marimba' => 'Marimba', _ => 'Soft bell' };
  String songFromPhone(String name) => '$name · from this phone';
  String get songNone => 'No song picked yet';
  String get songPick => 'Pick a song';
  String get songChange => 'Change';
  String get songNote => 'A song file you already have. It plays from this phone, is never uploaded, and stops after 30 seconds.';
  String get songWeb => 'In the app on your phone you can pick a song file.';
  String get soundRules => 'Silent mode is respected. Quiet hours: headphones only.';
  String get playSample => 'Play';
  String get quizTitle => 'Daily question';
  String get quizOff => 'Off';
  String quizChip(int n) => n == 1 ? '1 a day' : '$n';
  String get quizSettingsNote => 'Short questions about sleep, movement and common health numbers, each with its source.';
  String get researchChoice => 'Help health research (anonymous)';
  String get researchChoiceSub => 'Off by default. Group reports only, never your name.';
  String get researchWhyTitle => 'Help health research (anonymous)';
  String get researchWhy =>
      'What: only counts and choices. How many days you checked in, the area and small step you chose, your '
      '4-week answer, your shift type and your age band. Never your name, email, account, body numbers, anything '
      'you typed or your question answers.\n\n'
      'With whom and why: UAE health bodies (for example DHA or DoH), to understand the sleep and movement habits '
      'of people who work shifts. Only group reports, with groups big enough that no one can be picked out; never '
      'one person\'s data. Kept and processed in the UAE. Formal research may need an ethics committee first.\n\n'
      'Today nothing is sent: BloomBack has no UAE server yet. You can turn this off anytime.';
  String get nowPlayingChime => 'Now playing · chime';
  String get nowPlayingSong => 'Now playing · your song';
  String get soundQuiet => 'Quiet hours: plug in headphones to hear it.';
  String get soundFailed => "The sound couldn't play.";
  String get todaysQuestion => "Today's question";
  String todaysQuestionSub(int left) =>
      left <= 1 ? '1 short question · about 20 seconds' : '$left short questions · about 20 seconds each';
  String get open => 'Open';
  String get skipToday => 'Skip today';
  String quizLabel(String topic) =>
      "Today's question · ${switch (topic) { 'sleep' => 'Sleep', 'movement' => 'Movement', _ => 'Health numbers' }}";
  String get skip => 'Skip';
  String get quizNoScore => 'No score. Just good to know.';
  String get check => 'Check';
  String get yourAnswer => 'your answer';
  String get goodToKnow => 'Good to know';
  String get askDoctorLine => 'Want to understand your own numbers? Ask your doctor.';
  String get backToGarden => 'Back to my garden';
  String get nextQuestion => 'Next question';

  // BloomBack music and music while you move (Chi, thread 0007, 16/11)
  String get soundMusic => 'BloomBack music';
  String get talkNotSing => 'you can talk but not sing';
  String get musicCreditShort => 'Kevin MacLeod · CC BY 4.0';
  String get musicCreditTitle => 'Music credits';
  String get musicCreditBody =>
      'BloomBack music is 9 gentle tracks by Kevin MacLeod (incompetech.com), used under the Creative Commons '
      'Attribution 4.0 licence. They play from the app on this phone; nothing is streamed.';
  String get musicNote => 'Gentle tracks that come with the app. The first 30 seconds play after Done or Partly.';
  String trackLength(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  String get nowPlayingMusic => 'Now playing · BloomBack music';
  String nowPlayingOf(int i, int n) => 'Now playing · $i of $n';
  String get stepMusicTitle => 'Music while I do my step';
  String get stepMusicBody =>
      'For steps with a time (walks, stretching, light strength, slow breathing): a timer, and music that plays '
      'one track after another until you finish. It only makes the step more pleasant.';
  String get stepMusicOff => 'Off';
  String startStep(int minutes, {required bool music}) => 'Start · $minutes min${music ? ' with music' : ''}';
  String get didItAlready => 'I did it already';
  String stepMinutesLine(int m) => '$m min';
  String get changeMinutes => 'Change minutes';
  String get minutesTitle => 'Minutes for this step';
  String get minutesBody => 'BloomBack only suggests. Pick what fits your day.';
  String get useSuggested => 'Use the suggestion';
  String get timerOwnSource =>
      'BloomBack suggestion: no official source gives minutes for stretching or for muscle strengthening. '
      'WHO 2020 and DHA 2026 say "on 2 or more days a week". You can change the minutes.';
  String get timerBreathSource => 'NHS "Breathing exercises for stress": at least 5 minutes.';
  String get musicWhileYouMove => 'Music while you move';
  String stepMusicChoice(String m, String? song) => switch (m) {
        'music' => 'BloomBack music · gentle',
        'song' => song ?? 'My song',
        _ => 'Off',
      };
  String stepTimerLabel(String habit) => habit;
  String leftOf(int minutes) => 'left of $minutes min';
  String get pause => 'Pause';
  String get resume => 'Resume';
  String get finishNow => 'Finish now';
  String get nextTrack => 'Next track';
  String get outdoorsVolume => 'Outdoors? Keep the volume low enough to hear traffic.';
  String timeUpTitle(int minutes) => '$minutes minutes. Nice.';
  String get stoppedEarlyTitle => 'Good that you moved.';
  String get howDidItGo => 'How did it go?';
  String get stoppedEarlyNote => 'Stopped early? "Partly" counts too. Your flower still grows.';
  String get thenQuestion => "Then: today's question";
  String get thenQuestionSub => '1 short question · no score';
  String get leaveTimerQ => 'Stop the timer?';
  String get leaveTimerBody => 'Nothing is saved until you tap Done or Partly.';
  String get stopTimer => 'Stop';
  String get keepGoing => 'Keep going';

  // Your day, My shifts, Sleep from your band (Chi, thread 0008, 18/11)
  String yourDayLabel(String today) => switch (today) {
        'night' => 'Your day · night shift tonight',
        'day' => 'Your day · day shift today',
        _ => 'Your day · day off',
      };
  String get myShifts => 'My shifts';
  String get late => 'late';
  String dayRowTitle(String kind, {String? until, String? habit}) => switch (kind) {
        'mainSleep' => 'Main sleep · until $until',
        'nap' => 'Nap before the shift, if you can',
        'shiftStart' => 'Shift starts',
        'coffee' => 'Coffee',
        'homeToBed' => 'Go directly to bed when you get home',
        'wake' => 'Wake up',
        'step' => habit ?? '',
        'windDown' => 'Wind down',
        'bedtime' => 'Bedtime',
        _ => 'Day off',
      };
  String dayRowLine(String kind, {bool isStep = false}) => (isStep ? 'Your small step. ' : '') + switch (kind) {
        'nap' => 'It can help you stay alert during the night.',
        'shiftStart' => 'More light in the first half, less in the second half.',
        'coffee' => 'A cup near the end of the shift can disturb your sleep after it.',
        'homeToBed' => 'Keep the room very dark, or wear an eye mask.',
        'wake' => 'Get up at the same time every day, weekends too.',
        'windDown' => 'Relax before bed. Screens off at least 30 min before sleep.',
        'bedtime' => 'Keep the bedroom quiet, relaxing and cool.',
        'dayOff' => 'To keep your sleep times closer together, try staying up until about 3–4 a.m. and sleeping until '
            'noon or 1 p.m.',
        _ => '',
      };
  String bandLine(String from, String to, int minutes) => 'Band: $from–$to, about ${hours(minutes)}';
  String get yourDayFooterNight => 'Times come from your answers. Advice: NIOSH shift-work training, tap ? for the source.';
  String get yourDayFooterDay => 'Times come from your answers. Advice: AASM healthy sleep habits, tap ? for the source.';
  String get myShiftsTitle => 'My shifts this week';
  String get myShiftsBody => 'Tap a day to change it. BloomBack plans your sleep around your shifts.';
  String weekShiftChip(String t) => switch (t) { 'night' => 'Night', 'day' => 'Day', _ => 'Off' };
  String shiftTimes(String n1, String n2, String d1, String d2) => 'Night $n1–$n2 · Day $d1–$d2';
  String get editTimes => 'Edit times';
  String get nightShift => 'Night shift';
  String get dayShift => 'Day shift';
  String get starts => 'Starts';
  String get ends => 'Ends';
  String get comingUp => 'Coming up';
  String get nothingComingUp => 'Nothing changes in the next 7 days.';
  String daysOffTitle(String days) => '$days: ${days.contains(' and ') ? 'days' : 'day'} off';
  String get daysOffSourceShort => 'NIOSH: a compromise sleep schedule for night workers';
  String newShiftTitle(String day, String to) => '$day: switch to ${to == 'night' ? 'night' : 'day'} shift';
  String get newShiftBody => 'A new shift type starts. For the first two days BloomBack keeps to sleep steps only.';
  String weekdayShort(int i) => const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'][i];
  String weekdayLong(int i) => const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][i];
  String get bandSleepTitle => 'Sleep from your band';
  String get bandSleepRow => 'Sleep from your band';
  String get bandSleepRowSub => 'Last 7 days on a 24-hour line';
  String lastMainSleepWhen(String when) => 'Last main sleep · $when';
  String get todayWord => 'today';
  String planThisWeek(String from, String to, int target) => 'Your plan this week: $from – $to, towards ${hours(target)}.';
  String get last7Title => 'Last 7 days · 24-hour view';
  String get afterNight => 'after a night shift';
  String get workDayLegend => 'work day';
  String get dayOffLegend => 'day off';
  String get plannedLegend => 'planned';
  String compareWorkOff(int work, int off, int hoursEarlier) =>
      'On work days you slept about ${hours(work)}; on days off about ${hours(off)}'
      '${hoursEarlier == 0 ? '.' : ', starting ${hoursEarlier.abs()} ${hoursEarlier.abs() == 1 ? 'hour' : 'hours'} ${hoursEarlier > 0 ? 'earlier' : 'later'}.'}';
  String get bandCompareNote => 'Compared only with yourself. Estimated from wrist movement, not a medical sleep test.';
  String get noBandNights => 'No band nights yet. Wear the band to bed and sync; your plan works without a band too.';
  String get connected2 => 'Connected';
}

const s = S();
