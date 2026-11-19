// App controller: loads the store, talks to the band, runs analytics and rules,
// and tells the screens to rebuild. One instance for the whole app.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'account/account.dart';
import 'account/pro_store.dart';
import 'analytics/daily.dart';
import 'analytics/fhir.dart';
import 'band/band_link.dart';
import 'band/band_session.dart';
import 'band/fake_band.dart';
import 'band/protocol.dart';
import 'band/real_band.dart';
import 'data/models.dart';
import 'data/store.dart';
import 'demo/scenarios.dart';
import 'l10n/strings.dart';
import 'notify/notifier.dart';
import 'platform/share_file.dart';
import 'platform/song_file.dart';
import 'rules/biomarkers.dart';
import 'rules/environment.dart';
import 'rules/habits.dart';
import 'rules/levels.dart';
import 'rules/plan.dart';
import 'rules/quiz.dart';
import 'rules/regularity.dart';
import 'rules/reminders.dart' show inQuiet;
import 'sound/after_sound.dart';

class AppState extends ChangeNotifier {
  final Store store;
  final Notifier? notifier;
  final DateTime Function() clock;
  /// The optional account (Chi's screen 2): email code, Apple or Google; Pro and the coach.
  final Account account;

  /// BloomBack Pro in the stores; started when the Pro sheet first opens.
  late final ProStore pro = ProStore(account);

  /// The sound after Done or Partly (Chi, thread 0007). Silent in the web demo and in tests.
  final AfterSound sound;

  AppState(this.store, {this.notifier, DateTime Function()? clock, Account? account, AfterSound? sound})
      : clock = clock ?? DateTime.now,
        account = account ?? Account(),
        sound = sound ?? (kIsWeb ? SilentSound() : PhoneSound()) {
    this.account.addListener(_accountChanged);
  }

  void _accountChanged() {
    // A first name from the account fills "Rest well, …" when the phone has none yet.
    final n = account.view?.name;
    if (displayName.isEmpty && n != null && n.isNotEmpty) unawaited(saveName(n));
    notifyListeners();
  }

  /// First name or nickname only (screen 2), for "Rest well, Ravi". Never a phone
  /// number or Emirates ID. Empty = not given.
  String displayName = '';

  /// Screen 3 "You decide what we use". Only "use my answers" works in this version;
  /// sync and sharing are "coming later" and stay off. "research" (Chi, thread 0007): help health research
  /// with anonymous group data; off by default. This version sends nothing: there is no UAE server yet.
  Map<String, bool> choices = {..._defaultChoices};
  static const _defaultChoices = {'useAnswers': true, 'sync': false, 'share': false, 'research': false};

  /// Daily health-knowledge questions (Chi, thread 0007): the approved bank and what this phone has shown.
  /// Only ids are kept; never which choice the user picked, never a right/wrong count.
  List<QuizQuestion> quizBank = [];
  Map<String, dynamic> quiz = {};

  Profile? profile;
  Plan? plan;
  Settings settings = Settings();
  Map<String, dynamic> review = {};
  Biomarkers? biomarkers;
  FastingMode? fasting;
  int? lastActiveMinute; // last app open or check-in (irregular-hours reminders)
  List<MinuteRec> minutes = [];
  List<Checkin> checkins = [];
  List<DaySummary> days = [];
  List<WeekSummary> weeks = [];
  Map<int, CheckinStatus> byDay = {};
  bool loaded = false;

  // Band
  BandLink? _link;
  FakeBandLink? _fake;
  /// Demo scenario band (start minute + check-in script), kept so the demo band
  /// keeps answering the same way after the app restarts. null = Ravi's usual band.
  Map<String, dynamic>? _demoBand;
  /// Set while a demo scenario is being loaded (Settings > Debug).
  DemoScenario? loadingScenario;
  bool syncing = false;
  String? syncStep;
  String? bandMessage;
  InfoMsg? lastInfo;
  DateTime? lastSync;

  int get tz => clock().timeZoneOffset.inMinutes;
  int get nowMinute => clock().toUtc().millisecondsSinceEpoch ~/ 60000;
  int get today => localDay(nowMinute, tz);
  bool get onboarded => profile != null && plan != null;

  BandLink get link {
    if (settings.useFakeBand) return _fake ??= _makeFakeBand();
    return _link ??= createRealBandLink();
  }

  FakeBandLink _makeFakeBand() {
    final d = _demoBand;
    if (d == null) return FakeBandLink(now: clock);
    final script = (d['checkins'] as Map<String, dynamic>? ?? const {})
        .map((k, v) => MapEntry(int.parse(k), v as int));
    return FakeBandLink(now: clock, firstMinute: d['first'] as int?, checkinScript: script);
  }

  Future<void> load() async {
    final p = await store.getJson('profile');
    final pl = await store.getJson('plan');
    final st = await store.getJson('settings');
    profile = p == null ? null : Profile.fromJson(p);
    plan = pl == null ? null : Plan.fromJson(pl);
    if (st != null) settings = Settings.fromJson(st);
    review = await store.getJson('review') ?? {};
    final bio = await store.getJson('biomarkers');
    biomarkers = bio == null ? null : Biomarkers.fromJson(bio);
    fasting = FastingMode.fromJson(await store.getJson('fasting'));
    _demoBand = await store.getJson('demoBand');
    displayName = ((await store.getJson('account'))?['name'] ?? '') as String;
    quiz = await store.getJson('quiz') ?? {};
    await _loadQuizBank();
    final ch = await store.getJson('choices');
    if (ch != null) choices = {...choices, ...ch.map((k, v) => MapEntry(k, v == true))};
    await _touch();
    final ls = await store.getJson('lastSync');
    lastSync = ls == null ? null : DateTime.fromMillisecondsSinceEpoch(ls['ms'] as int);
    await store.prune(nowMinute);
    await _recompute();
    loaded = true;
    notifyListeners();
    unawaited(_reschedule());
    unawaited(account.restore());
  }

  Future<void> _loadQuizBank() async {
    try {
      quizBank = parseQuizBank(await rootBundle.loadString('assets/quiz/questions.json'))
          .where((q) => q.isApproved)
          .toList();
    } catch (e) {
      quizBank = [];
      debugPrint('quiz bank not loaded: $e');
    }
  }

  // ---------- after the small step: sound and today's question (Chi, thread 0007) ----------

  /// "Change" on today's check-in result (Chi, thread 0004 fix 8): the three buttons show again until the next
  /// answer. Kept here, not in the card, so scrolling Today does not lose it. Not saved.
  int? changingCheckinDay;
  bool get changingCheckin => changingCheckinDay == today;
  void startChangingCheckin() {
    changingCheckinDay = today;
    notifyListeners();
  }

  void stopChangingCheckin() {
    changingCheckinDay = null;
    notifyListeners();
  }

  /// Set by the home screen: switches the bottom tab, for pages pushed over it that keep the tab bar.
  void Function(int tab)? openTab;

  bool get didStepToday => todayCheckin == CheckinStatus.done || todayCheckin == CheckinStatus.partial;

  List<String> get _quizSeen => [...(quiz['seen'] as List? ?? const []).cast<String>()];
  Set<String> get quizShownToday =>
      quiz['day'] == today ? {...(quiz['today'] as List? ?? const []).cast<String>()} : <String>{};
  bool get quizSkippedToday => quiz['skip'] == today;

  /// Questions still offered today (Off / 1 / 2 / 3 a day).
  int get quizLeftToday {
    if (settings.quizPerDay <= 0 || quizSkippedToday) return 0;
    final left = settings.quizPerDay - quizShownToday.length;
    return left < 0 ? 0 : left;
  }

  /// Today's next question: only after Done or Partly, never more than the daily choice.
  QuizQuestion? get nextQuiz {
    if (!didStepToday || quizLeftToday == 0 || plan == null) return null;
    return nextQuestion(quizBank,
        domains: plan!.domains.toSet(),
        seen: _quizSeen,
        shownToday: quizShownToday,
        shownCount: (quiz['count'] ?? 0) as int);
  }

  /// The answer of [id] was shown (the user tapped Check).
  Future<void> quizAnswered(String id) async {
    final seen = _quizSeen
      ..remove(id)
      ..add(id);
    quiz = {
      'seen': seen,
      'count': ((quiz['count'] ?? 0) as int) + 1,
      'day': today,
      'today': [...quizShownToday, id],
      'skip': quiz['skip'],
    };
    await store.setJson('quiz', quiz);
    notifyListeners();
  }

  /// "Skip today" on the card, or "Skip" on the question.
  Future<void> skipQuizToday() async {
    quiz = {...quiz, 'skip': today};
    await store.setJson('quiz', quiz);
    notifyListeners();
  }

  /// Plays the chosen sound after Done or Partly, if the user turned it on.
  Future<PlayResult?> playAfterStep() async {
    final st = settings;
    final asset = switch (st.sound) {
      'chime' => kChimes[st.chime] ?? kChimes['bell'],
      'music' => musicTrack(st.musicTrack).asset,
      _ => null,
    };
    final song = st.sound == 'song' ? st.songPath : null;
    if (asset == null && song == null) return null;
    final now = clock();
    return sound.play(
      asset: asset,
      songPath: song,
      quietHours: inQuiet(now.hour * 60 + now.minute, st.quietStart, st.quietEnd),
    );
  }

  Future<void> _recompute() async {
    final from = nowMinute - kRetentionDays * 1440;
    minutes = await store.minutesFrom(from);
    checkins = await store.checkinsFrom(from);
    byDay = checkinsByDay(checkins, tz);
    final firstDataDay = minutes.isEmpty ? today : localDay(minutes.first.minute, tz);
    days = summarizeDays(minutes, firstDataDay, today, tz, settings.dayEnd);
    weeks = summarizeWeeks(days, byDay, firstDay, today, tz, settings.dayEnd);
  }

  /// Local day the user's plan started (onboarding done). Before it the garden
  /// shows no grey days: "grey days just didn't bloom" only counts days after starting.
  int get planDay => profile == null ? today : localDay(profile!.startMinute, tz);

  /// Week 1 = the earlier of the user's start and the first band data.
  int get firstDay {
    final start = profile == null ? today : localDay(profile!.startMinute, tz);
    final data = minutes.isEmpty ? today : localDay(minutes.first.minute, tz);
    return start < data ? start : data;
  }

  // ---------- onboarding and plan ----------

  Future<void> finishOnboarding(Profile p, Plan pl, Settings st, {Biomarkers? markers}) async {
    profile = p;
    plan = pl;
    settings = st;
    await store.setJson('profile', p.toJson());
    await store.setJson('plan', pl.toJson());
    await store.setJson('settings', st.toJson());
    await store.setJson('choices', choices);
    if (markers != null && !markers.isEmpty) {
      biomarkers = markers;
      await store.setJson('biomarkers', markers.toJson());
    }
    await _recompute();
    notifyListeners();
    await notifier?.requestPermission();
    await _reschedule();
  }

  /// Edits from Settings (height, weight, city, work answers). Never changes the
  /// plan's level or steps, except that a new work answer updates the minutes
  /// counted from work (and the base they are part of).
  Future<void> saveProfile(Profile p) async {
    final old = profile;
    profile = p;
    await store.setJson('profile', p.toJson());
    final pl = plan;
    if (pl != null && old != null) {
      final credit = workCredit(p);
      if (credit != pl.workCredit) {
        final base = pl.movementBaseWeekly - pl.workCredit + credit;
        final np = Plan.fromJson(pl.toJson())
          ..workCredit = credit
          ..movementBaseWeekly = base <= 0 ? 0 : base;
        plan = np;
        await store.setJson('plan', np.toJson());
      }
    }
    notifyListeners();
    await _reschedule();
  }

  Future<void> saveName(String name) async {
    displayName = name.trim();
    if (displayName.isEmpty) {
      await store.removeKey('account');
    } else {
      await store.setJson('account', {'name': displayName});
    }
    notifyListeners();
  }

  Future<void> saveChoices(Map<String, bool> c) async {
    choices = {...c};
    await store.setJson('choices', choices);
    notifyListeners();
  }

  Future<void> saveBiomarkers(Biomarkers b) async {
    biomarkers = b;
    await store.setJson('biomarkers', b.toJson());
    notifyListeners();
  }

  /// Only "fasting mode on, from - to" is stored (C4, A3). null = off.
  Future<void> saveFasting(FastingMode? f) async {
    fasting = f;
    if (f == null) {
      await store.removeKey('fasting');
    } else {
      await store.setJson('fasting', f.toJson());
    }
    notifyListeners();
    await _reschedule();
  }

  Future<void> _touch() async {
    lastActiveMinute = nowMinute;
    await store.setJson('lastActive', {'minute': lastActiveMinute});
  }

  Future<void> savePlan(Plan pl) async {
    plan = pl;
    await store.setJson('plan', pl.toJson());
    notifyListeners();
    await _reschedule();
  }

  Future<void> saveSettings(Settings st) async {
    final fakeChanged = st.useFakeBand != settings.useFakeBand;
    settings = st;
    if (fakeChanged) {
      // Demo data and real band data never mix.
      settings.bandId = null;
      settings.bandName = null;
      lastInfo = null;
      lastSync = null;
      _fake = null;
      _demoBand = null;
      await store.deleteBandData();
      await store.removeKey('lastSync');
      await store.removeKey('demoBand');
    }
    await store.setJson('settings', st.toJson());
    await _recompute();
    notifyListeners();
    await _reschedule();
  }

  Future<void> saveReview(Map<String, dynamic> r) async {
    review = r;
    await store.setJson('review', r);
    notifyListeners();
  }

  /// The plan's main habit (the user's choice).
  Habit? get planHabit => plan == null ? null : habitById(plan!.mainHabitId);

  DateTime get localDate => dateOnly(clock());

  /// Today's rules from the environment (B6, C4): habit, notes, reminder times.
  DayRules? get todayRules {
    final p = profile, pl = plan;
    if (p == null || pl == null) return null;
    return dayRules(profile: p, plan: pl, settings: settings, fasting: fasting, date: clock());
  }

  /// Today's habit: the main habit, unless heat, fasting or the first nights change it.
  Habit? get mainHabit => todayRules?.habit;

  /// The habit with today's dose, e.g. "Brisk walk: 5 min × 3 days this week".
  /// A band has sent minute data (or is paired): only then are minutes shown (Chi, thread 0004 fix 4).
  bool get hasBandData => minutes.isNotEmpty;

  /// This week (Monday first) as 7 local days with the check-in of each, for "3 of 5 days" (design 12b).
  List<(int, CheckinStatus?)> get weekCheckins {
    final monday = today - (today + 3) % 7; // local day 0 (1 Jan 1970) was a Thursday
    return [for (var i = 0; i < 7; i++) (monday + i, byDay[monday + i])];
  }

  /// Minutes for a small step that has a duration (Chi, thread 0007 "music while you move"), or null.
  /// Walks use the plan's minutes per walk (per part on long or split shifts); breathing 5 (NHS "at least 5 min");
  /// stretching 5 and light strength 10 are BloomBack's own defaults.
  int? stepMinutes() {
    final suggested = suggestedStepMinutes();
    if (suggested == null) return null;
    return settings.stepMins[mainHabit!.id] ?? suggested;
  }

  /// The minutes BloomBack suggests for today's timed step, before the user's own choice.
  int? suggestedStepMinutes() {
    final pl = plan;
    final h = mainHabit;
    if (pl == null || h == null) return null;
    switch (h.id) {
      case 'breathing':
      case 'stretch':
        return 5;
      case 'strength':
        return 10;
      case 'briskWalk':
      case 'walkAfterMeal':
      case 'indoorWalk':
      case 'walkAfterIftar':
        final per = movementTarget(pl).perSession;
        if (profile?.shift == ShiftType.longOrSplit) return breakSplit(per).$2;
        return per < 5 ? 5 : per;
    }
    return null;
  }

  /// The user's own minutes for today's timed step; null goes back to the suggestion.
  Future<void> setStepMinutes(int? minutes) async {
    final id = mainHabit?.id;
    if (id == null) return;
    if (minutes == null) {
      settings.stepMins.remove(id);
    } else {
      settings.stepMins[id] = minutes.clamp(1, 90);
    }
    await saveSettings(settings);
  }

  /// Music while doing a timed step: the 9 tracks in order from the chosen one, or the user's song.
  Future<PlayResult?> playStepMusic() {
    final st = settings;
    final now = clock();
    final quiet = inQuiet(now.hour * 60 + now.minute, st.quietStart, st.quietEnd);
    if (st.stepMusic == 'song' && st.songPath != null) {
      return sound.playSession(songPath: st.songPath, quietHours: quiet);
    }
    if (st.stepMusic == 'music') {
      final i = kMusic.indexWhere((m) => m.id == st.musicTrack);
      final order = [...kMusic.skip(i < 0 ? 0 : i), ...kMusic.take(i < 0 ? 0 : i)];
      return sound.playSession(assets: [for (final m in order) m.asset], quietHours: quiet);
    }
    return Future.value(null);
  }

  Future<void> playTimeUpChime() async {
    await sound.stop();
    final now = clock();
    await sound.play(
      asset: kChimes['bell'],
      quietHours: inQuiet(now.hour * 60 + now.minute, settings.quietStart, settings.quietEnd),
    );
  }

  String habitDose() {
    final pl = plan;
    final h = mainHabit;
    if (pl == null || h == null) return '';
    if (h.id == 'bedEarlier') return s.bedEarlierDose(pl.sleepIncrement);
    // The line under the habit matches the habit (design 12b): no walk counts under the stairs.
    if (h.id == 'stairs') return s.stairsDose;
    if (h.id == 'strength') return s.strengthDose;
    const walks = {'briskWalk', 'walkAfterMeal', 'indoorWalk', 'walkAfterIftar'};
    if (h.area == HabitArea.movement && walks.contains(h.id)) {
      final t = movementTarget(pl);
      // Already in the healthy range and keeping it: no "N more walks" (fix 4 #2-3).
      if (t.holding && pl.movementBaseWeekly >= kMoveGuideline) return s.keepRhythmDose;
      final long = profile?.shift == ShiftType.longOrSplit;
      // Without a band there are no minutes to subtract: the plan's own sessions, never "16 more walks".
      if (pl.movementBaseWeekly <= 0 || !hasBandData) {
        if (long) {
          final (parts, per) = breakSplit(t.perSession);
          if (parts > 1) return s.longShiftDose(parts, per, t.sessions);
        }
        return s.walkDose(t.perSession, t.sessions);
      }
      final gap = movementGapDose(leisureTarget(pl), weekModerate);
      if (gap == null) return s.walkGapMet;
      if (long) {
        final (parts, per) = breakSplit(gap.$1);
        if (parts > 1) return s.longShiftDose(parts, per, gap.$2);
      }
      return s.walkGapDose(gap.$1, gap.$2);
    }
    return '';
  }

  /// D2: show "Ask a doctor before increasing activity" (B3 answers, the doctor
  /// card, or a health number at a reference level). Never changes the plan.
  bool get showDoctorNote {
    final p = profile;
    if (p == null) return false;
    return p.askDoctorFirst ||
        doctorNoteFlags(heightCm: p.heightCm, weightKg: p.weightKg, markers: biomarkers).isNotEmpty;
  }

  /// Offer the optional numbers after the first week (B1), until answered or hidden.
  bool get offerBiomarkers {
    final p = profile;
    if (p == null || biomarkers != null || review['bioOfferHidden'] == true) return false;
    return today - localDay(p.startMinute, tz) >= kMarkersOfferAfterDays;
  }

  Future<void> hideBiomarkerOffer() => saveReview({...review, 'bioOfferHidden': true});

  /// Bedtime spread now: the band's latest week with a spread, else the user's answer.
  (int, DataSource)? get currentSpread {
    for (final w in weeks.reversed) {
      if (w.onsetSpreadMinutes != null && w.days >= 4) return (w.onsetSpreadMinutes!, DataSource.watch);
    }
    final self = profile?.selfBedtimeSpreadMinutes;
    return self == null ? null : (self, DataSource.selfReport);
  }

  /// C2 sleep regularity step, only when sleep is one of the chosen areas.
  SpreadOffer? get spreadOfferToday {
    final pl = plan;
    final cur = currentSpread;
    if (pl == null || cur == null || !pl.domains.contains(Domain.sleep)) return null;
    return spreadOffer(
      currentSpread: cur.$1,
      target: pl.spreadTargetMinutes,
      targetSetDay: pl.spreadStepStartMinute == null ? null : localDay(pl.spreadStepStartMinute!, tz),
      today: today,
      declinedDay: review['spreadDeclined'] as int?,
    );
  }

  Future<void> acceptSpread(int target) async {
    final np = Plan.fromJson(plan!.toJson())
      ..spreadTargetMinutes = target
      ..spreadStepStartMinute = nowMinute;
    await savePlan(np);
  }

  Future<void> declineSpread() => saveReview({...review, 'spreadDeclined': today});

  /// C5 Lapse Radar items not hidden by the user.
  List<RadarItem> get radar {
    final p = profile;
    if (p == null) return const [];
    return lapseRadar(profile: p, fasting: fasting, today: clock())
        .where((r) => review['radarHidden_${r.key}'] != true)
        .toList();
  }

  Future<void> hideRadar(RadarItem r) => saveReview({...review, 'radarHidden_${r.key}': true});

  /// C5 "Move": change one of today's reminders; [keep] makes it the new daily time.
  Future<void> moveReminder(int index, int minuteOfDay, {bool keep = false}) async {
    final n = Settings.fromJson(settings.toJson());
    if (keep && profile?.shift != ShiftType.irregular) {
      if (index == 0) {
        n.reminder1 = minuteOfDay;
      } else {
        n.reminder2 = minuteOfDay;
      }
      n.movedDate = null;
      n.movedTime = -1;
    } else {
      n.movedDate = dateKey(clock());
      n.movedIndex = index;
      n.movedTime = minuteOfDay;
    }
    await saveSettings(n);
  }

  /// The reminders that will ring in the next week (for tests and Settings).
  List<ReminderEvent> upcomingReminders({int days = 7}) {
    final p = profile, pl = plan;
    if (p == null || pl == null) return const [];
    final last = checkins.isEmpty ? null : checkins.last;
    return reminderSchedule(
      profile: p,
      plan: pl,
      settings: settings,
      fasting: fasting,
      now: clock(),
      days: days,
      lastActive: lastActiveMinute == null ? null : _local(lastActiveMinute!),
      lastCheckin: last == null ? null : _local(last.minute),
      checkedInToday: todayCheckin != null,
    );
  }

  DateTime _local(int utcMinute) {
    final d = DateTime.fromMillisecondsSinceEpoch((utcMinute + tz) * 60000, isUtc: true);
    return DateTime(d.year, d.month, d.day, d.hour, d.minute);
  }

  int get weekModerate => rollingModerate(days, today);

  DaySummary? get todaySummary => days.where((d) => d.day == today).firstOrNull;

  /// Most recent day with a sleep window (today's, else yesterday's).
  DaySummary? get lastSleepDay =>
      days.reversed.where((d) => d.sleep.found && d.day >= today - 1).firstOrNull;

  CheckinStatus? get todayCheckin => byDay[today];

  Nudge get nudge {
    final pl = plan;
    if (pl == null) return Nudge.none;
    if (review['dismissed_$today'] == true) return Nudge.none;
    // Nudges (C5) only look at days since the user chose this plan: band check-ins
    // from before onboarding are history, not a lapse (found on the emulator 13 Nov).
    return nudgeFor(
      byDay: {for (final e in byDay.entries) if (e.key >= planDay) e.key: e.value},
      today: today,
      stepStartDay: localDay(pl.stepStartMinute, tz),
      firstDay: planDay,
      canStepUp: (pl.domains.contains(Domain.movement) && canStepUpMovement(pl)) ||
          (pl.domains.contains(Domain.sleep) && canStepUpSleep(pl)),
    );
  }

  Future<void> dismissNudge() => saveReview({...review, 'dismissed_$today': true});

  Future<void> checkIn(CheckinStatus status) async {
    changingCheckinDay = null;
    final c = Checkin(nowMinute, status, DataSource.selfReport);
    await store.saveCheckin(c);
    await _touch();
    await _recompute();
    notifyListeners();
    await _reschedule();
  }

  int get daysBloomed =>
      byDay.values.where((v) => v == CheckinStatus.done || v == CheckinStatus.partial).length;

  /// Garden (Chi Q5): how many times the user came back after a break of 2 or more
  /// days without the habit. Counted since the plan started; never a streak.
  int get comeBackCount {
    final p = profile;
    if (p == null) return 0;
    final start = localDay(p.startMinute, tz);
    bool did(int d) => byDay[d] == CheckinStatus.done || byDay[d] == CheckinStatus.partial;
    var count = 0, gap = 0;
    var started = false;
    for (var d = start; d <= today; d++) {
      if (did(d)) {
        if (started && gap >= 2) count++;
        started = true;
        gap = 0;
      } else if (d < today) {
        gap++;
      }
    }
    return count;
  }

  /// Done or partly days in the week [from]..[from]+6 (local days).
  int daysDoneIn(int from) {
    var n = 0;
    for (var d = from; d < from + 7 && d <= today; d++) {
      if (byDay[d] == CheckinStatus.done || byDay[d] == CheckinStatus.partial) n++;
    }
    return n;
  }

  /// Band sleep per night over the last 7 days (estimate), or null without band nights.
  int? get sleepLast7 {
    final nights = days.where((d) => d.day > today - 7 && d.sleep.found).toList();
    if (nights.isEmpty) return null;
    return nights.map((d) => d.sleep.sleepMinutes).reduce((a, b) => a + b) ~/ nights.length;
  }

  /// C6: the 4-week check is due every 28 days from the first day.
  bool get reviewDue => profile != null && today - firstDay >= 28;
  String get reviewKey => 'review4w_${(today - firstDay) ~/ 28}';

  // ---------- band ----------

  Future<void> pair(FoundBand b) async {
    settings.bandId = b.id;
    settings.bandName = b.name;
    await saveSettings(settings);
    await sync();
  }

  Future<void> forgetBand() async {
    final id = settings.bandId;
    if (id != null) await link.forget(id);
    settings.bandId = null;
    settings.bandName = null;
    lastInfo = null;
    await saveSettings(settings);
  }

  Future<BandTransport> _connect() async {
    final id = settings.bandId;
    if (id == null) throw BandException('No band paired');
    return link.connect(id);
  }

  /// On every connect: time, info, config, `sync <last saved minute>`.
  Future<void> sync() async {
    if (syncing || settings.bandId == null) return;
    syncing = true;
    bandMessage = null;
    syncStep = 'connecting';
    notifyListeners();
    BandTransport? t;
    try {
      t = await _connect();
      final session = BandSession(t);
      final since = await store.syncCursor();
      final r = await session.onConnect(
        nowUtc: clock().toUtc(),
        tzMinutes: tz,
        config: BandConfig(mainHabit == null ? '' : s.habitShort(mainHabit!.id), settings),
        sinceMinute: since,
        onStep: (st) {
          syncStep = st;
          notifyListeners();
        },
      );
      lastInfo = r.info;
      syncStep = 'saving';
      notifyListeners();
      await store.saveMinutes(r.minutes);
      await store.saveCheckins(r.checkins);
      if (r.lastMinute != null) await store.setSyncCursor(r.lastMinute!);
      await store.prune(nowMinute);
      lastSync = clock();
      await store.setJson('lastSync', {'ms': lastSync!.millisecondsSinceEpoch});
      await _recompute();
      bandMessage = s.bandSynced(r.minutes.length, r.checkins.length);
    } catch (e) {
      bandMessage = e.toString();
    } finally {
      await t?.close();
      syncing = false;
      syncStep = null;
      notifyListeners();
    }
  }

  Future<void> deleteOnBand() async {
    BandTransport? t;
    try {
      t = await _connect();
      await BandSession(t).deleteOnBand();
      // The band starts again from now; keep the phone's copy and cursor.
      bandMessage = s.bandDeleted;
    } catch (e) {
      bandMessage = e.toString();
    } finally {
      await t?.close();
      notifyListeners();
    }
  }

  // ---------- data ----------

  /// More > Delete everything: the band's copy too when one is paired, then the phone.
  Future<void> deleteEverything() async {
    if (settings.bandId != null) {
      try {
        await deleteOnBand();
      } catch (_) {
        // Band out of reach: the phone is still cleared.
      }
    }
    await deleteAllOnPhone();
  }

  Future<void> deleteAllOnPhone() async {
    // The account itself stays on the server (More › Account › Delete my account removes it); this phone signs out.
    if (account.signedIn) await account.signOut();
    await sound.stop();
    await deleteSong(settings.songPath);
    await store.deleteAll();
    displayName = '';
    choices = {..._defaultChoices};
    quiz = {};
    await notifier?.cancelAll();
    profile = null;
    plan = null;
    settings = Settings(useFakeBand: settings.useFakeBand);
    review = {};
    biomarkers = null;
    fasting = null;
    lastActiveMinute = null;
    lastSync = null;
    lastInfo = null;
    _fake = null;
    _demoBand = null;
    await _recompute();
    notifyListeners();
  }

  // ---------- demo scenarios (Settings > Debug, demo band only) ----------

  /// Replaces all data with [sc] through the normal paths: delete my data, the
  /// onboarding result, pairing the demo band and a sync over the protocol.
  Future<void> applyScenario(DemoScenario sc) async {
    if (!settings.useFakeBand || loadingScenario != null) return;
    loadingScenario = sc;
    notifyListeners();
    try {
      await deleteAllOnPhone();
      final setup = buildScenario(sc, clock(), base: settings);
      if (setup.profile == null) return; // Fresh start: onboarding
      _demoBand = {
        'first': setup.bandFirstMinute,
        'checkins': {for (final e in setup.checkinScript.entries) '${e.key}': e.value},
      };
      await store.setJson('demoBand', _demoBand!);
      await saveName('Ravi'); // the persona's first name (C7), for "Rest well, Ravi"
      await finishOnboarding(setup.profile!, setup.plan!, setup.settings!);
      await pair(const FoundBand('fake', 'BloomBack-DEMO', -48));
    } finally {
      loadingScenario = null;
      notifyListeners();
    }
  }

  Future<void> exportFhir() async {
    final bundle = buildFhirBundle(
      days: days,
      checkins: checkins,
      tzMinutes: tz,
      bandName: settings.bandName ?? 'BloomBack band',
      profile: profile,
    );
    await shareTextFile('bloomback-fhir-$today.json', fhirJson(bundle), subject: 'BloomBack data');
  }

  Future<void> _reschedule() async {
    if (notifier == null || plan == null) return;
    try {
      await notifier!.schedule([
        for (final e in upcomingReminders())
          (e.at, e.first ? s.notifMorning(s.habit(e.habitId)) : s.notifLater(s.habit(e.habitId))),
      ]);
    } catch (e) {
      debugPrint('schedule failed: $e');
    }
  }
}
