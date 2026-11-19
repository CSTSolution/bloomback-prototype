// Onboarding in Chi's order (docs/design, screens 1-11): Start -> Sign in -> Your
// choices -> Work -> Sleep and movement now -> Body measures -> Safety -> Goals ->
// Your picture -> Your plan -> Pick one small step. Rules: A1 (minimum data), B1,
// B3 (safety note never blocks), B5 (cards + reason), B6 (work axes), C1 steps 1-5,
// C2. BloomBack suggests; the user decides on every page.
//
// Only the current page is built (no PageView with every page at once): an earlier
// version crashed when a later page was built before its answers existed.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../l10n/strings.dart';
import '../rules/biomarkers.dart';
import '../rules/environment.dart';
import '../rules/goals.dart';
import '../rules/habits.dart';
import '../rules/levels.dart';
import '../rules/plan.dart';
import '../rules/regularity.dart';
import '../rules/reminders.dart';
import '../rules/safety.dart';
import '../rules/sources.dart';
import 'after_step.dart';
import 'account_ui.dart';
import 'common.dart';
import 'icons.dart';

class OnboardingScreen extends StatefulWidget {
  /// Prefill when changing goals or plan later (starts at the work page).
  final Profile? initial;
  final VoidCallback? onDone;
  const OnboardingScreen({super.key, this.initial, this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _P { start, signIn, choices, work, now, body, safety, goals, picture, plan, step }

enum _Pace { follow, slower, own }

/// Screen 10b choices (rules B4/C2, 14/11).
enum _Move { keep, to300, strength }

const _kSafetySource = 'DHA Physical Activity Guideline 2026, appendix 1 (ACSM pre-participation '
    'screening) and sec. 9 "Special considerations"; WHO 2020.';

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final List<_P> _pages;
  int _index = 0;
  bool _prefilled = false;

  // 2-3
  final _name = TextEditingController();
  Map<String, bool> _choices = {'useAnswers': true, 'sync': false, 'share': false, 'research': false};

  // 4 work
  WorkActivity? _activity;
  ShiftType? _shift;
  WorkPlace? _place;
  City? _city;
  DateTime? _nextNights;
  int _break = -1;

  // 5 sleep and movement now
  int _sleepStart = 23 * 60 + 30;
  int _wake = 5 * 60 + 30;
  /// The user set the sleep times (or they came from the profile): no more shift defaults.
  bool _sleepSet = false;
  final List<(int, int)> _naps = [];
  // days off (Chi's screen 5, 14/11); the bedtime spread is computed from the two bedtimes
  int _offStart = 23 * 60 + 30;
  int _offWake = 7 * 60;
  int _exDays = 0;
  int _exMin = 20;
  final _workBrisk = TextEditingController(text: '0');

  // 6 body
  final _height = TextEditingController();
  final _weight = TextEditingController();
  int? _sys, _dia, _waist, _hr;
  double? _glu, _a1c;
  bool _gluMgDl = false;
  final Map<String, MarkerSource> _markerSrc = {};

  // 7 safety
  bool? _q1, _q2;

  // 8 goals
  final List<String> _goals = [];
  String? _main;
  final _motivation = TextEditingController();

  // 9-11
  final Set<Domain> _domains = {};
  _Pace _pace = _Pace.follow;
  int _ownTarget = 6 * 60;
  int _ownInc = 30;
  bool _goal300 = false;
  /// Screen 10b (rules B4/C2, 14/11): already at 150-300 min a week. Keep is the suggestion.
  _Move _move = _Move.keep;
  String? _habit;
  final Set<String> _backups = {};
  String? _cueAnchor, _cueAction;
  int? _reminder;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _pages = p == null ? _P.values : _P.values.where((x) => x.index >= _P.work.index).toList();
    if (p != null) {
      _goals.addAll(p.goalIds);
      _main = p.mainGoalId;
      _motivation.text = p.motivation;
      _activity = p.activity;
      _shift = p.shift;
      _place = p.place;
      _city = p.city;
      _nextNights = parseDateKey(p.nextNightsDate);
      _workBrisk.text = '${p.workBriskMinutes}';
      _height.text = p.heightCm == null ? '' : '${p.heightCm}';
      _weight.text = p.weightKg == null ? '' : '${p.weightKg}';
      _q1 = p.askDoctorFirst && !p.goalIds.contains('doctor');
      _q2 = false;
      _sleepSet = true;
      if (p.selfWakeTime != null && p.selfSleepStart != null) {
        _sleepStart = p.selfSleepStart!;
        _wake = p.selfWakeTime!;
        final main = (_wake - _sleepStart + 1440) % 1440;
        if (p.selfSleepMinutes > main) _naps.add((13 * 60, 13 * 60 + p.selfSleepMinutes - main));
        _offStart = p.selfOffSleepStart ?? _sleepStart;
        _offWake = p.selfOffWakeTime ?? _wake;
      } else {
        _wake = 6 * 60;
        _sleepStart = (_wake - p.selfSleepMinutes + 1440) % 1440;
      }
      if (p.exerciseDays != null && p.exerciseMinutes != null) {
        _exDays = p.exerciseDays!;
        _exMin = p.exerciseMinutes!;
      } else if (p.selfWalkMinutes > 0) {
        _exDays = 3;
        _exMin = (p.selfWalkMinutes / 3).round().clamp(5, 180);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Once only: AppScope notifies on every app change.
    if (_prefilled) return;
    _prefilled = true;
    final app = AppScope.of(context);
    _name.text = app.displayName;
    _choices = {...app.choices};
    if (widget.initial != null) {
      _break = app.settings.breakMinute;
      _goal300 = app.plan?.movementGoal == kMoveUpper;
      if (_goal300) _move = _Move.to300;
      final pl = app.plan;
      if (pl != null) {
        _domains.addAll(pl.domains);
        _habit = pl.mainHabitId;
        _backups.addAll(pl.backupHabitIds);
        _cueAnchor = pl.cueAnchor;
        _cueAction = pl.cueAction;
        _pace = pl.sleepIncrement == 15 ? _Pace.slower : _Pace.follow;
      }
      _reminder = app.settings.reminder1 >= 0 ? app.settings.reminder1 : null;
    }
  }

  _P get _page => _pages[_index];

  // ---------- derived answers ----------

  int? _range(TextEditingController c, int lo, int hi) {
    final v = int.tryParse(c.text.trim());
    return v == null || v < lo || v > hi ? null : v;
  }

  int? get _heightCm => _range(_height, 100, 250);
  int? get _weightKg => _range(_weight, 30, 300);
  int get _workBriskMin => int.tryParse(_workBrisk.text.trim())?.clamp(0, 2000) ?? 0;
  int get _walkMin => _exDays * _exMin;

  static int _span(int from, int to) => (to - from + 1440) % 1440;

  /// Hours of sleep over 24 h: main sleep plus naps (A1 ②).
  int get _sleepMin => (_span(_sleepStart, _wake) + _naps.fold<int>(0, (a, n) => a + _span(n.$1, n.$2))).clamp(0, 1440);

  bool get _askDoctor => _q1 == true || _q2 == true || _goals.contains('doctor');

  Biomarkers? get _markers {
    final b = Biomarkers(
      waistCm: _waist,
      systolic: _sys,
      diastolic: _dia,
      restingHr: _hr,
      glucose: _glu,
      glucoseMgDl: _gluMgDl,
      hba1c: _a1c,
      sources: Map.of(_markerSrc),
      source: _markerSrc.values.contains(MarkerSource.checkup) ? MarkerSource.checkup : MarkerSource.selfReport,
      measuredMinute: AppScope.of(context).nowMinute,
    );
    return b.isEmpty ? null : b;
  }

  // D2: BMI from height/weight or an optional number can show the note (never changes the plan).
  bool get _doctorNote =>
      _askDoctor || doctorNoteFlags(heightCm: _heightCm, weightKg: _weightKg, markers: _markers).isNotEmpty;

  bool get _ready => _main != null && _activity != null && _shift != null && _place != null;

  Profile _profile() => Profile(
        goalIds: List.of(_goals),
        mainGoalId: _main!,
        motivation: stripIdentifiers(_motivation.text),
        activity: _activity!,
        shift: _shift!,
        place: _place!,
        selfSleepMinutes: _sleepMin,
        selfWalkMinutes: _walkMin,
        askDoctorFirst: _askDoctor,
        startMinute: widget.initial?.startMinute ?? AppScope.of(context).nowMinute,
        heightCm: _heightCm,
        weightKg: _weightKg,
        city: _city,
        workBriskMinutes: _activity == WorkActivity.moderate ? _workBriskMin : 0,
        selfBedtimeSpreadMinutes: spreadFromBedtimes(_sleepStart, _offStart, rotating: _shift == ShiftType.rotating),
        nextNightsDate: _shift == ShiftType.rotating && _nextNights != null ? dateKey(_nextNights!) : null,
        selfSleepStart: _sleepStart,
        selfWakeTime: _wake,
        selfOffSleepStart: _offStart,
        selfOffWakeTime: _offWake,
        exerciseDays: _exDays,
        exerciseMinutes: _exMin,
      );

  /// Weekly movement now (outside work + work credit), for screen 10b.
  int get _moveNow => _walkMin + (_activity == WorkActivity.moderate ? _workBriskMin : 0);
  bool get _healthyRange => _moveNow >= kMoveGuideline;

  /// Never a goal lower than the current level (rules B4/C2, 14/11): at 150 or more, "towards 300" is the only
  /// higher goal; under 150 the weight card may still pick 300 (B5).
  int get _goal {
    if (_healthyRange) return _move == _Move.to300 && _moveNow < kMoveUpper ? kMoveUpper : kMoveGuideline;
    return _goal300 && _goals.contains('weight') ? kMoveUpper : kMoveGuideline;
  }
  int get _inc => switch (_pace) { _Pace.follow => 30, _Pace.slower => 15, _Pace.own => _ownInc };
  int _firstTarget(Profile p) => _pace == _Pace.own ? _ownTarget : firstSleepTarget(p.selfSleepMinutes, _inc);

  Plan _plan(Profile p, {int now = 0}) {
    final pl = initialPlan(
      profile: p,
      domains: _domains.isEmpty ? {suggestedStartDomain(p)} : _domains,
      mainHabitId: _habit ?? 'bedEarlier',
      backupHabitIds: _backups.where((b) => b != _habit).toList(),
      nowMinute: now,
      movementGoal: _goal,
    );
    return pl
      ..sleepIncrement = _inc
      ..sleepTargetMinutes = _firstTarget(p)
      ..cueAnchor = _cueAnchor
      ..cueAction = _cueAction
      ..moveChoice = _healthyRange && _domains.contains(Domain.movement) ? _move.name : null;
  }

  List<Habit> _suggestions() {
    final today = AppScope.of(context).clock();
    final p = _profile();
    final sug = suggestHabits(profile: p, domains: _domains, today: today);
    // Screen 10b "Add muscle strengthening 2 days a week": the strength habit comes first, when the work allows it.
    if (_healthyRange && _move == _Move.strength && _domains.contains(Domain.movement)) {
      final allowed = filterHabits(profile: p, domains: _domains, today: today).habits;
      final strength = allowed.where((h) => h.id == 'strength').firstOrNull;
      if (strength != null) return [strength, ...sug.where((h) => h.id != 'strength')].take(3).toList();
    }
    return sug;
  }

  /// Reminder times and quiet hours for the shift and, on fixed nights, for the
  /// moment of the picked habit (after / before the shift). Changing goals later on
  /// the same shift keeps the user's own settings unless the habit's moment changed.
  Settings _suggestedSettings() {
    final app = AppScope.of(context);
    if (widget.initial == null || widget.initial!.shift != _shift) {
      return suggestedReminderSettings(_shift!, app.settings, habitId: _habit);
    }
    final cur = Settings.fromJson(app.settings.toJson());
    final old = app.plan?.mainHabitId;
    if (_shift == ShiftType.nightFixed && old != null && habitMoment(_habit) != habitMoment(old)) {
      final sug = suggestedReminderSettings(_shift!, cur, habitId: _habit);
      cur
        ..reminder1 = sug.reminder1
        ..reminder2 = sug.reminder2;
    }
    return cur;
  }

  // ---------- navigation ----------

  bool get _canNext => switch (_page) {
        _P.start || _P.signIn => true,
        _P.choices => _choices['useAnswers'] == true,
        // city is optional (Chi, thread 0004 fix 10)
        _P.work => _activity != null && _shift != null && _place != null,
        _P.now => _sleepMin > 0,
        // height and weight are optional (fix 9); a typed value must still be in range
        _P.body => (_height.text.trim().isEmpty || _heightCm != null) && (_weight.text.trim().isEmpty || _weightKg != null),
        _P.safety => _q1 != null && _q2 != null,
        _P.goals => _goals.isNotEmpty && _main != null,
        _P.picture => _domains.isNotEmpty,
        _P.plan => true,
        _P.step => _habit != null,
      };

  void _go(int to) {
    FocusScope.of(context).unfocus();
    setState(() => _index = to.clamp(0, _pages.length - 1));
    _enter();
  }

  /// Set the page's suggested defaults when a page is entered (BB suggests, user changes).
  void _enter() {
    switch (_page) {
      case _P.now:
        // Screen 5 starts from the shift picked on screen 4 (only a default).
        if (!_sleepSet && _shift != null) {
          final (start, wake) = suggestedSleepTimes(_shift!);
          _sleepStart = start;
          _wake = wake;
          // days off: a night-shift worker usually sleeps at night again (Chi's Ravi: 1:00 am to 8:30 am)
          final nights = _shift == ShiftType.nightFixed || _shift == ShiftType.rotating;
          _offStart = nights ? 60 : 23 * 60 + 30;
          _offWake = nights ? 8 * 60 + 30 : 7 * 60;
        }
      case _P.picture:
        if (_domains.isEmpty && _ready) _domains.add(suggestedStartDomain(_profile()));
      case _P.plan:
        if (_pace != _Pace.own) _ownTarget = _firstTarget(_profile());
      case _P.step:
        final sug = _suggestions();
        if (_habit == null || !sug.any((h) => h.id == _habit)) {
          _habit = sug.isEmpty ? null : sug.first.id;
          _backups
            ..clear()
            ..addAll(sug.skip(1).take(1).map((h) => h.id));
        }
        _backups.removeWhere((b) => b == _habit || !sug.any((h) => h.id == b));
      default:
        break;
    }
  }

  void _next() {
    if (_page == _P.goals && hasDangerSign(_motivation.text)) {
      _showDanger();
      return;
    }
    if (_page == _P.step) {
      _finish();
      return;
    }
    _go(_index + 1);
  }

  void _prev() {
    if (_index == 0) {
      if (widget.initial != null) Navigator.of(context).maybePop();
      return;
    }
    _go(_index - 1);
  }

  void _showDanger() => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(s.dangerTitle),
          content: Text(s.dangerBody),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(s.ok))],
        ),
      );

  Future<void> _finish() async {
    final app = AppScope.of(context);
    final p = _profile();
    final pl = _plan(p, now: p.startMinute);
    final st = _suggestedSettings();
    if (_reminder != null) st.reminder1 = _reminder!;
    st.breakMinute = p.shift == ShiftType.longOrSplit ? _break : -1;
    if (widget.initial == null) {
      await app.saveName(_name.text);
      app.choices = {..._choices};
    }
    await app.finishOnboarding(p, pl, st, markers: widget.initial == null ? _markers : null);
    widget.onDone?.call();
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    final step = switch (_page) {
      _P.work => 1,
      _P.now => 2,
      _P.body => 3,
      _P.safety => 4,
      _P.goals => 5,
      _ => 0,
    };
    final title = switch (_page) {
      _P.start => null,
      _P.signIn => s.signInHeader,
      _P.choices => s.choicesHeader,
      _P.work => s.workHeader,
      _P.now => s.nowHeader,
      _P.body => s.bodyHeader,
      _P.safety => s.safetyHeader,
      _P.goals => s.goalsHeader,
      _P.picture => '',
      _P.plan => _domains.contains(Domain.sleep) ? s.sleepPlanHeader : s.planHeader,
      _P.step => s.stepHeader,
    };
    final anyYes = _q1 == true || _q2 == true;
    final label = switch (_page) {
      _P.start => s.getStarted,
      _P.safety when anyYes => s.understandContinue,
      _P.step => s.startTomorrow,
      _ => s.continueLabel,
    };
    final Widget bottom = switch (_page) {
      _P.start => Column(mainAxisSize: MainAxisSize.min, children: [
          PrimaryButton(label: label, onPressed: _next),
          const SizedBox(height: 6),
          TextButton(key: const Key('haveAccount'), onPressed: _next, child: Text(s.haveAccount)),
          _languageRow(),
        ]),
      _P.signIn when AppScope.of(context).account.signedIn => PrimaryButton(label: s.continueLabel, onPressed: _next),
      _P.signIn => TextButton(
          key: const Key('tryWithout'),
          onPressed: _next,
          child: Text(s.tryWithout, style: const TextStyle(fontSize: 15)),
        ),
      _P.body => Column(mainAxisSize: MainAxisSize.min, children: [
          PrimaryButton(label: label, onPressed: _canNext ? _next : null),
          TextButton(
            key: const Key('skipBody'),
            onPressed: () {
              // Skip for now (Chi, thread 0004 fix 9): nothing from this screen is kept; add it later in More.
              setState(() {
                _height.clear();
                _weight.clear();
              });
              _next();
            },
            child: Text(s.skipForNow),
          ),
        ]),
      _ => PrimaryButton(label: label, onPressed: _canNext ? _next : null),
    };
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _prev();
      },
      child: BBPage(
        title: title,
        onBack: _page == _P.start ? null : _prev,
        step: step > 0 ? '$step / 5' : null,
        progress: step > 0 ? step / 5 : null,
        bottom: bottom,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(key: ValueKey(_page), child: _body()),
        ),
      ),
    );
  }

  Widget _body() => switch (_page) {
        _P.start => _startPage(),
        _P.signIn => _signInPage(),
        _P.choices => _choicesPage(),
        _P.work => _workPage(),
        _P.now => _nowPage(),
        _P.body => _bodyPage(),
        _P.safety => _safetyPage(),
        _P.goals => _goalsPage(),
        _P.picture => _ready ? _picturePage() : const SizedBox(),
        _P.plan => _ready ? _planPage() : const SizedBox(),
        _P.step => _ready ? _stepPage() : const SizedBox(),
      };

  Widget _list(List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: children,
      );

  TextTheme get _tt => Theme.of(context).textTheme;

  Widget _title(String t, [String? sub]) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: _tt.headlineSmall),
          if (sub != null) ...[const SizedBox(height: 6), Text(sub, style: _tt.bodyMedium?.copyWith(color: BBColors.muted))],
        ]),
      );

  Widget _q(String t, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Row(children: [Expanded(child: Text(t, style: _tt.titleSmall)), ?trailing]),
      );

  Widget _chips<T>(List<T> values, T? selected, String Function(T) label, ValueChanged<T> on) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final v in values)
            PillChip(label: label(v), selected: v == selected, onTap: () => setState(() => on(v))),
        ],
      );

  // 1 Start
  Widget _startPage() => ListView(padding: const EdgeInsets.fromLTRB(24, 32, 24, 16), children: [
        Center(
          child: Container(
            width: 150,
            height: 150,
            alignment: Alignment.center,
            // Chi's screen 1: a soft green circle, warm in the middle, with the sprout.
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                colors: [Color(0xFFFFF6DD), BBColors.primaryLight],
                stops: [0, 0.7],
              ),
            ),
            child: const SproutMark(key: Key('startLogo'), size: 96),
          ),
        ),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SproutMark(size: 34),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(s.appName, style: heading(36, color: BBColors.primary, weight: FontWeight.w800)),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        Text('${s.tagline1}\n${s.tagline2}',
            textAlign: TextAlign.center, style: heading(22, weight: FontWeight.w500).copyWith(height: 1.35)),
        const SizedBox(height: 14),
        Text(s.startBody, textAlign: TextAlign.center, style: _tt.bodyMedium?.copyWith(color: BBColors.muted)),
      ]);

  Widget _languageRow() => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(onPressed: () {}, child: Text(s.english)),
          const Text('|', style: TextStyle(color: BBColors.muted)),
          TextButton(
            key: const Key('arabic'),
            style: TextButton.styleFrom(foregroundColor: BBColors.ink),
            onPressed: () => showArabicSoon(context),
            child: Text(s.arabic, style: const TextStyle(fontFamily: kArabicFont, fontWeight: FontWeight.w400)),
          ),
        ]),
      );

  // 2 Sign in (thread 0003): Apple (iPhone), Google, email code; "Try without an account" works fully
  Widget _signInPage() {
    final account = AppScope.of(context).account;
    return _list([
      _title(s.signInTitle, s.signInBody),
      if (account.signedIn)
        BBCard(
          key: const Key('onboardSignedIn'),
          color: BBColors.primaryLight,
          border: BBColors.primaryBorder,
          child: Text('${s.signedInAs} ${account.view?.name?.isNotEmpty == true ? account.view!.name! : account.view?.email ?? ''}'),
        )
      else
        SignInButtons(name: () => _name.text.trim(), onSignedIn: _next),
      _q(s.nameQ),
      TextField(
        key: const Key('name'),
        controller: _name,
        maxLength: 30,
        textCapitalization: TextCapitalization.words,
        // First name or nickname only: no digits (never a phone number or ID).
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[0-9@]'))],
        decoration: InputDecoration(hintText: s.nameHint, counterText: ''),
      ),
      const SizedBox(height: 6),
      Text(s.nameNote, style: _tt.bodySmall),
      const SizedBox(height: 24),
      BBCard(
        color: BBColors.primaryLight,
        border: BBColors.primaryBorder,
        child: Row(children: [
          const Icon(Icons.lock_outline, color: BBColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(s.lockNote, style: _tt.bodySmall?.copyWith(color: BBColors.ink))),
        ]),
      ),
    ]);
  }

  // 3 Your choices
  Widget _choicesPage() {
    Widget toggle(String key, String title, String sub, {bool enabled = true}) => BBCard(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: _tt.titleSmall),
                Text(sub, style: _tt.bodySmall),
              ]),
            ),
            Switch(
              key: Key('choice_$key'),
              value: _choices[key] == true,
              onChanged: enabled ? (v) => setState(() => _choices[key] = v) : null,
            ),
          ]),
        );
    return _list([
      _title(s.choicesTitle, s.choicesBody),
      toggle('useAnswers', s.useAnswers, s.useAnswersSub),
      // Coming later: shown as designed, off, and they do nothing yet.
      toggle('sync', s.syncChoice, s.syncChoiceSub, enabled: false),
      toggle('share', s.shareChoice, s.shareChoiceSub, enabled: false),
      // Chi, thread 0007: help health research, anonymous, off by default; nothing is sent in this version.
      BBCard(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: ResearchSwitch(
          value: _choices['research'] == true,
          onChanged: (v) => setState(() => _choices['research'] = v),
        ),
      ),
      const SizedBox(height: 8),
      Text(s.choicesNote, style: _tt.bodySmall),
      if (_choices['useAnswers'] != true) ...[
        const SizedBox(height: 8),
        Text(s.useAnswersNeeded, style: _tt.bodySmall?.copyWith(color: BBColors.accent)),
      ],
    ]);
  }

  // 4 Work (B6: three axes + city)
  Widget _workPage() => _list([
        _title(s.workTitle, s.workBody),
        _q(s.activityQ),
        _chips(WorkActivity.values, _activity, s.activityChip, (v) => _activity = v),
        if (_activity != null) ...[
          const SizedBox(height: 6),
          Text(s.activityExample(_activity!), style: _tt.bodySmall),
        ],
        _q(s.shiftQ),
        _chips(ShiftType.values, _shift, s.shiftChip, (v) => _shift = v),
        if (_shift == ShiftType.rotating)
          _rowButton(s.obNextNightsQ, _nextNights == null ? s.pickDate : s.date(_nextNights!), () async {
            final now = AppScope.of(context).clock();
            final d = await showDatePicker(
              context: context,
              initialDate: _nextNights ?? now.add(const Duration(days: 3)),
              firstDate: DateTime(now.year, now.month, now.day),
              lastDate: now.add(const Duration(days: 120)),
            );
            if (d != null) setState(() => _nextNights = d);
          }),
        if (_shift == ShiftType.longOrSplit)
          _rowButton(s.obBreakQ, _break < 0 ? s.notSet : hhmm(_break), () async {
            final t = await pickTime(context, _break < 0 ? 13 * 60 : _break);
            if (t != null) setState(() => _break = t);
          }),
        _q(s.placeQ),
        _chips(WorkPlace.values, _place, s.placeChip, (v) => _place = v),
        _q(s.obCityQ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BBColors.line),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<City>(
              key: const Key('city'),
              isExpanded: true,
              value: _city,
              hint: Text(s.cityHint),
              borderRadius: BorderRadius.circular(14),
              items: [
                for (final c in City.values) DropdownMenuItem(value: c, child: Text(s.cityLabel(c))),
              ],
              onChanged: (c) => setState(() => _city = c),
            ),
          ),
        ),
      ]);

  Widget _rowButton(String label, String value, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: BBCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(children: [
            Expanded(child: Text(label, style: _tt.bodyMedium)),
            TextButton(onPressed: onTap, child: Text(value)),
          ]),
        ),
      );

  // 5 Sleep and movement now (A1)
  Widget _timeBox(Key key, String label, int minute, ValueChanged<int> set) => Expanded(
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final t = await pickTime(context, minute);
            if (t != null) setState(() => set(t));
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: BBColors.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: _tt.bodySmall),
              // time and day part on their own lines, so every box in a row has the same height
              Text(hhmm(minute), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              Text(s.dayPart(minute), style: _tt.bodySmall),
            ]),
          ),
        ),
      );

  Widget _nowPage() {
    final moderate = _activity == WorkActivity.moderate;
    return _list([
      _title(s.nowTitle, s.nowBody),
      BBCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(BBIcons.sleep, color: BBColors.data, size: 20),
            const SizedBox(width: 8),
            Text(s.sleepUsually, style: _tt.titleSmall),
          ]),
          const SizedBox(height: 10),
          Text(s.workDays, style: _tt.bodySmall?.copyWith(color: BBColors.ink, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(children: [
            _timeBox(const Key('sleepStart'), s.fallAsleepAt, _sleepStart, (t) {
              _sleepStart = t;
              _sleepSet = true;
            }),
            const SizedBox(width: 8),
            _timeBox(const Key('wakeTime'), s.wakeUpAt, _wake, (t) {
              _wake = t;
              _sleepSet = true;
            }),
          ]),
          const SizedBox(height: 10),
          Text(s.daysOff, style: _tt.bodySmall?.copyWith(color: BBColors.ink, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(children: [
            _timeBox(const Key('offSleepStart'), s.fallAsleepAt, _offStart, (t) {
              _offStart = t;
              _sleepSet = true;
            }),
            const SizedBox(width: 8),
            _timeBox(const Key('offWakeTime'), s.wakeUpAt, _offWake, (t) {
              _offWake = t;
              _sleepSet = true;
            }),
          ]),
          for (var i = 0; i < _naps.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                _timeBox(Key('napFrom$i'), '${s.nap} · ${s.fallAsleepAt.toLowerCase()}', _naps[i].$1,
                    (t) => _naps[i] = (t, _naps[i].$2)),
                const SizedBox(width: 8),
                _timeBox(Key('napTo$i'), s.wakeUpAt, _naps[i].$2, (t) => _naps[i] = (_naps[i].$1, t)),
                IconButton(
                  tooltip: s.removeNap,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _naps.removeAt(i)),
                ),
              ]),
            ),
          const SizedBox(height: 4),
          Row(children: [
            if (_naps.length < 2)
              TextButton(
                key: const Key('addNap'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => setState(() {
                  final from = (_wake + 6 * 60) % 1440;
                  _naps.add((from, (from + 30) % 1440));
                }),
                child: Text(s.addNap),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s.hoursOfSleep(_sleepMin),
                  key: const Key('sleepHours'), textAlign: TextAlign.end, style: _tt.titleSmall),
            ),
          ]),
          if (spreadFromBedtimes(_sleepStart, _offStart, rotating: _shift == ShiftType.rotating) case final sp?
              when sp >= 30) ...[
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: Text(s.spreadComputed(sp), key: const Key('spreadComputed'), style: _tt.bodySmall)),
              WhyButton(title: s.spreadTitle, source: kSpreadSource),
            ]),
          ],
        ]),
      ),
      BBCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(BBIcons.walk, color: BBColors.data, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(s.exerciseQ, style: _tt.titleSmall)),
            WhyButton(title: s.talkTest, source: kTalkTestSource),
          ]),
          const SizedBox(height: 4),
          Text(s.exerciseHint, style: _tt.bodySmall),
          const SizedBox(height: 10),
          Text(s.daysPerWeek, style: _tt.bodySmall),
          const SizedBox(height: 6),
          Row(children: [
            for (var d = 0; d <= 7; d++)
              Expanded(
                child: Center(
                  child: Semantics(
                    selected: _exDays == d,
                    button: true,
                    label: '${s.daysPerWeek}: $d',
                    child: InkWell(
                      key: Key('days_$d'),
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _exDays = d),
                      child: Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _exDays == d ? BBColors.primary : Colors.white,
                          border: Border.all(color: _exDays == d ? BBColors.primary : BBColors.line),
                        ),
                        child: Text('$d',
                            style: TextStyle(
                                color: _exDays == d ? Colors.white : BBColors.ink, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(s.minutesEachTime, style: _tt.bodySmall)),
            IconButton(
              key: const Key('minLess'),
              icon: const Icon(Icons.remove),
              onPressed: _exMin > 5 ? () => setState(() => _exMin -= 5) : null,
            ),
            SizedBox(
                width: 40,
                child: Text('$_exMin',
                    key: const Key('minEach'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18))),
            IconButton(
              key: const Key('minMore'),
              icon: const Icon(Icons.add),
              onPressed: _exMin < 180 ? () => setState(() => _exMin += 5) : null,
            ),
          ]),
          Text(s.exerciseTotal(_walkMin), style: _tt.bodySmall),
          if (moderate) ...[
            const Divider(height: 20),
            Text(s.obWorkBriskQ, style: _tt.bodySmall?.copyWith(color: BBColors.ink)),
            const SizedBox(height: 6),
            TextField(
              key: const Key('workBrisk'),
              controller: _workBrisk,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              decoration: InputDecoration(suffixText: 'min', helperText: s.obWorkBriskHint, helperMaxLines: 2),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ]),
      ),
    ]);
  }

  // 6 Body measures (A1, B1, D2)
  Widget _numBox(Key key, String label, TextEditingController c, String unit) => Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: BBColors.line),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: _tt.bodySmall),
            TextField(
              key: key,
              controller: c,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                suffixText: unit,
                hintText: '–',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ]),
        ),
      );

  String? _markerText(String key) => switch (key) {
        'bp' => _sys == null || _dia == null ? null : '$_sys / $_dia',
        'waist' => _waist == null ? null : '$_waist ${s.cm}',
        'hr' => _hr == null ? null : '$_hr ${s.bpm}',
        _ => _glu == null && _a1c == null
            ? null
            : [
                if (_glu != null) '$_glu ${_gluMgDl ? s.mgDl : s.mmolL}',
                if (_a1c != null) '$_a1c %',
              ].join(' · '),
      };

  Widget _bodyPage() {
    Widget row(String key, String label) {
      final v = _markerText(key);
      return BBCard(
        key: Key('marker_$key'),
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        onTap: () => _editMarker(key, label),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: _tt.titleSmall),
              if (v != null) Text(s.markerSource(_markerSrc[key] ?? MarkerSource.selfReport), style: _tt.bodySmall),
            ]),
          ),
          if (v != null)
            Text(v, style: const TextStyle(fontWeight: FontWeight.w700))
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: BBColors.line)),
              child: Text(s.dontKnow, style: _tt.bodySmall?.copyWith(color: BBColors.ink)),
            ),
        ]),
      );
    }

    return _list([
      _title(s.bodyTitle, s.bodyBody),
      Row(children: [
        _numBox(const Key('height'), s.obHeightQ, _height, s.cm),
        const SizedBox(width: 8),
        _numBox(const Key('weight'), s.obWeightQ, _weight, s.kg),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: CapsLabel(s.optionalLater)),
        WhyButton(title: s.bioTitle, source: kD2Source),
      ]),
      const SizedBox(height: 4),
      row('bp', s.bloodPressure),
      row('waist', s.waist),
      row('hr', s.restingHr),
      row('glucose', s.glucoseOrA1c),
      const SizedBox(height: 6),
      Text(s.bodySourceNote, style: _tt.bodySmall),
    ]);
  }

  Future<void> _editMarker(String key, String label) async {
    final a = TextEditingController(), b = TextEditingController();
    var src = _markerSrc[key] ?? MarkerSource.selfReport;
    var mg = _gluMgDl;
    switch (key) {
      case 'bp':
        a.text = _sys?.toString() ?? '';
        b.text = _dia?.toString() ?? '';
      case 'waist':
        a.text = _waist?.toString() ?? '';
      case 'hr':
        a.text = _hr?.toString() ?? '';
      default:
        a.text = _glu?.toString() ?? '';
        b.text = _a1c?.toString() ?? '';
    }
    InputDecoration dec(String l, String unit) => InputDecoration(labelText: l, suffixText: unit);
    List<TextInputFormatter> digits(bool dec) => [
          dec ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')) : FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(5),
        ];
    final saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (key == 'bp')
              Row(children: [
                Expanded(child: TextField(key: const Key('bpSys'), controller: a, keyboardType: TextInputType.number, inputFormatters: digits(false), decoration: dec(s.systolic, 'mmHg'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(key: const Key('bpDia'), controller: b, keyboardType: TextInputType.number, inputFormatters: digits(false), decoration: dec(s.diastolic, 'mmHg'))),
              ])
            else if (key == 'waist')
              TextField(controller: a, keyboardType: TextInputType.number, inputFormatters: digits(false), decoration: dec(s.waist, s.cm))
            else if (key == 'hr')
              TextField(controller: a, keyboardType: TextInputType.number, inputFormatters: digits(false), decoration: dec(s.restingHr, s.bpm))
            else ...[
              Wrap(spacing: 8, children: [
                PillChip(label: s.mmolL, selected: !mg, onTap: () => set(() => mg = false)),
                PillChip(label: s.mgDl, selected: mg, onTap: () => set(() => mg = true)),
              ]),
              const SizedBox(height: 8),
              TextField(controller: a, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: digits(true), decoration: dec(s.glucose, mg ? s.mgDl : s.mmolL)),
              const SizedBox(height: 8),
              TextField(controller: b, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: digits(true), decoration: dec(s.hba1c, '%')),
            ],
            const SizedBox(height: 12),
            Text(s.bioSourceQ, style: Theme.of(c).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final m in MarkerSource.values)
                PillChip(label: s.markerSource(m), selected: src == m, onTap: () => set(() => src = m)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c, false), child: Text(s.dontKnow))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.save))),
            ]),
          ]),
        ),
      ),
    );
    if (saved == null || !mounted) return;
    int? i(TextEditingController t) => saved ? int.tryParse(t.text.trim()) : null;
    double? d(TextEditingController t) => saved ? double.tryParse(t.text.trim().replaceAll(',', '.')) : null;
    setState(() {
      switch (key) {
        case 'bp':
          _sys = i(a);
          _dia = i(b);
          if (_sys == null || _dia == null) _sys = _dia = null;
        case 'waist':
          _waist = i(a);
        case 'hr':
          _hr = i(a);
        default:
          _glu = d(a);
          _a1c = d(b);
          _gluMgDl = mg;
      }
      if (_markerText(key) == null) {
        _markerSrc.remove(key);
      } else {
        _markerSrc[key] = src;
      }
    });
  }

  // 7 / 7b Safety (B3): a note, never a block
  Widget _yesNo(String q, bool? v, ValueChanged<bool> on, String key) => BBCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(q, style: _tt.titleSmall),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: PillChip(key: Key('${key}_yes'), label: s.yes, selected: v == true, expand: true, onTap: () => setState(() => on(true)))),
            const SizedBox(width: 8),
            Expanded(child: PillChip(key: Key('${key}_no'), label: s.no, selected: v == false, expand: true, onTap: () => setState(() => on(false)))),
          ]),
        ]),
      );

  Widget _safetyPage() => _list([
        _title(s.safetyTitle),
        _yesNo(s.safetyQ1, _q1, (v) => _q1 = v, 'q1'),
        _yesNo(s.safetyQ2, _q2, (v) => _q2 = v, 'q2'),
        if (_q1 == true || _q2 == true)
          BBCard(
            key: const Key('safetyNote'),
            color: BBColors.accentLight,
            border: const Color(0xFFF2DFAE),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.verified_user_outlined, color: BBColors.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.safetyNoteTitle, style: _tt.titleSmall),
                  const SizedBox(height: 2),
                  Text(s.safetyNoteBody, style: _tt.bodySmall),
                ]),
              ),
              WhyButton(title: s.safetyNoteTitle, source: _kSafetySource),
            ]),
          ),
      ]);

  // 8 Goals (B5): up to 3 cards, then the main one, then the reason
  Widget _goalsPage() {
    final groups = <String, List<GoalCard>>{};
    for (final c in kGoalCards) {
      (groups[c.group] ??= []).add(c);
    }
    return _list([
      _title(s.goalsTitle, s.goalsHint),
      for (final g in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Row(children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(color: BBColors.primaryLight, shape: BoxShape.circle),
              child: Icon(BBIcons.goalGroup(g.key), size: 15, color: BBColors.primary),
            ),
            const SizedBox(width: 8),
            Text(s.goalGroup(g.key), style: _tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in g.value)
            PillChip(
              key: Key('goal_${c.id}'),
              label: s.goal(c.id),
              selected: _goals.contains(c.id),
              onTap: () => setState(() {
                if (_goals.contains(c.id)) {
                  _goals.remove(c.id);
                  if (_main == c.id) _main = _goals.isEmpty ? null : _goals.first;
                } else if (_goals.length < 3) {
                  _goals.add(c.id);
                  _main ??= c.id;
                }
                _domains.clear();
              }),
            ),
        ]),
      ],
      if (_goals.isNotEmpty) ...[
        const Divider(height: 28),
        _q(s.mattersMost),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final id in _goals)
            PillChip(
              key: Key('main_$id'),
              label: s.goal(id),
              icon: _main == id ? Icons.star : null,
              selected: _main == id,
              onTap: () => setState(() {
                _main = id;
                _domains.clear();
              }),
            ),
        ]),
      ],
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '${s.whyMatters} ', style: _tt.titleSmall),
          TextSpan(text: s.optional, style: _tt.bodySmall),
        ])),
      ),
      TextField(
        key: const Key('motivation'),
        controller: _motivation,
        maxLength: 120,
        maxLines: 2,
        minLines: 1,
        decoration: InputDecoration(hintText: s.motivationHint),
      ),
    ]);
  }

  // 9 Your picture (C1 steps 1-2): neutral bars, BB suggests, the user picks
  Widget _picturePage() {
    final p = _profile();
    final suggested = suggestedStartDomain(p);
    final credit = workCredit(p);
    final move = currentWeeklyMovement(p);
    final goal = goalById(p.mainGoalId);
    final reason = p.activity == WorkActivity.heavy
        ? s.suggestHeavy
        : (goal.start == StartArea.both ? s.suggestGap : s.suggestGoal(s.goal(p.mainGoalId)));
    Widget level(IconData icon, String label, String value, String rec, double v, double marker, String source, {String? extra}) =>
        BBCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 20, color: BBColors.data),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: _tt.titleMedium)),
              WhyButton(title: label, source: source),
            ]),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(value, style: heading(22)),
              const SizedBox(width: 8),
              Expanded(child: Text(rec, textAlign: TextAlign.end, style: _tt.bodySmall)),
            ]),
            if (extra != null) Text(extra, style: _tt.bodySmall),
            const SizedBox(height: 6),
            LevelBar(value: v, marker: marker),
          ]),
        );
    final moveMax = move > 300 ? move.toDouble() : 300.0;
    return _list([
      _title(s.pictureTitle, s.pictureBody),
      level(BBIcons.sleep, s.domainLabel(Domain.sleep), s.hoursDecimal(p.selfSleepMinutes), s.recSleep,
          p.selfSleepMinutes / (9 * 60), kSleepGuideline / (9 * 60), kSleepLevelSource),
      level(BBIcons.walk, s.domainLabel(Domain.movement), '$move min', s.recMove, move / moveMax,
          kMoveGuideline / moveMax, kMoveLevelSource,
          extra: credit > 0 ? s.atWorkIncluded(credit) : null),
      BBCard(
        color: BBColors.primaryLight,
        border: BBColors.primaryBorder,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.suggestsStart(suggested), style: _tt.titleSmall),
              const SizedBox(height: 2),
              Text(reason, style: _tt.bodySmall?.copyWith(color: BBColors.ink)),
            ]),
          ),
          WhyButton(
            title: s.suggestsStart(suggested),
            source: p.activity == WorkActivity.heavy ? kHeavyWorkSource : goal.source,
          ),
        ]),
      ),
      _q(s.whereStart),
      Row(children: [
        for (final (i, opt) in [
          ({Domain.sleep}, s.domainLabel(Domain.sleep)),
          ({Domain.movement}, s.domainLabel(Domain.movement)),
          ({Domain.sleep, Domain.movement}, s.bothAreas),
        ].indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: PillChip(
              key: Key('area_$i'),
              label: opt.$2,
              expand: true,
              selected: _domains.length == opt.$1.length && _domains.containsAll(opt.$1),
              onTap: () => setState(() {
                _domains
                  ..clear()
                  ..addAll(opt.$1);
              }),
            ),
          ),
        ],
      ]),
    ]);
  }

  // 10 Your plan (C1 step 3, C2; Chi Q3/Q4)
  Widget _ladder(List<(String, String)> steps, {int highlight = -1}) => Row(children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const Icon(Icons.chevron_right, size: 14, color: BBColors.muted),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: i == highlight ? BBColors.primaryLight : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(children: [
                Text(steps[i].$1,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: i == steps.length - 1 || i == highlight ? BBColors.primary : BBColors.ink)),
                Text(steps[i].$2, style: _tt.bodySmall?.copyWith(fontSize: 11)),
              ]),
            ),
          ),
        ],
      ]);

  /// Sleep steps from [start] to 7 h with [inc] per step (1-2 weeks each).
  List<(String, String)> _sleepSteps(int start, int first, int inc) {
    final out = <(String, String)>[(s.hoursDecimal(start), s.nowShort)];
    var t = first, k = 1;
    while (true) {
      final last = t >= kSleepGuideline;
      out.add((s.hoursDecimal(t >= kSleepGuideline ? kSleepGuideline : t), last ? '≈ ${s.wk(2 * k - 1, 2 * k)}' : s.wk(2 * k - 1, 2 * k)));
      if (last || out.length >= 8) break;
      t += inc;
      k++;
    }
    if (out.length > 5) return [out.first, out[1], out[out.length ~/ 2], out.last];
    return out;
  }

  Widget _planPage() {
    final p = _profile();
    final pl = _plan(p);
    final sleep = _domains.contains(Domain.sleep);
    final move = _domains.contains(Domain.movement);
    final enoughSleep = sleepLevel(p.selfSleepMinutes) == SleepLevel.enough;
    final mt = movementTarget(pl);
    final credit = workCredit(p);
    // "A gentle path to 150 minutes" only under 150 (Chi, thread 0004, 14/11); screen 10b otherwise.
    final title = sleep
        ? (enoughSleep ? s.sleepKeepTitle : s.sleepPathTitle)
        : (_healthyRange ? s.moveHealthyTitle : s.movePathTitle);
    final bed = (_wake - pl.sleepTargetMinutes + 1440) % 1440;
    return _list([
      _title(title),
      if (sleep) ...[
        BBCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.keepWake, style: _tt.titleSmall),
                const SizedBox(height: 2),
                Text(s.keepWakeBody, style: _tt.bodySmall),
                const SizedBox(height: 4),
                Text(s.wakeLine(hhmm(_wake), hhmm(bed)), key: const Key('wakeLine'), style: _tt.bodySmall?.copyWith(color: BBColors.ink)),
              ]),
            ),
            WhyButton(title: s.keepWake, source: kSleepStepSource),
          ]),
        ),
        if (!enoughSleep)
          BBCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(s.suggestedPace, style: _tt.titleSmall)),
                Flexible(flex: 2, child: BBTag(s.bbSuggestion)),
                WhyButton(title: s.suggestedPace, source: '$kSleepStepSource\n\n$kSleepLevelSource'),
              ]),
              Text(s.paceRange, style: _tt.bodySmall),
              const SizedBox(height: 10),
              Text(s.pace30, style: _tt.bodySmall?.copyWith(color: BBColors.ink, fontWeight: FontWeight.w600)),
              _ladder(_sleepSteps(p.selfSleepMinutes, firstSleepTarget(p.selfSleepMinutes, 30), 30),
                  highlight: _pace == _Pace.follow ? 1 : -1),
              const SizedBox(height: 8),
              Text(s.pace15, style: _tt.bodySmall?.copyWith(color: BBColors.ink, fontWeight: FontWeight.w600)),
              _ladder(_sleepSteps(p.selfSleepMinutes, firstSleepTarget(p.selfSleepMinutes, 15), 15),
                  highlight: _pace == _Pace.slower ? 1 : -1),
            ]),
          ),
        if (!enoughSleep) ...[
          _q(s.howGo),
          RadioCard(
            key: const Key('pace_follow'),
            selected: _pace == _Pace.follow,
            title: s.followSuggestion,
            subtitle: s.perStep(30),
            onTap: () => setState(() => _pace = _Pace.follow),
          ),
          RadioCard(
            key: const Key('pace_slower'),
            selected: _pace == _Pace.slower,
            title: s.goSlower,
            subtitle: s.perStep(15),
            onTap: () => setState(() => _pace = _Pace.slower),
          ),
          RadioCard(
            key: const Key('pace_own'),
            selected: _pace == _Pace.own,
            title: s.ownPace,
            onTap: () => setState(() => _pace = _Pace.own),
          ),
          if (_pace == _Pace.own)
            BBCard(
              child: Column(children: [
                Row(children: [
                  Expanded(child: Text(s.ownFirstStep)),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _ownTarget > p.selfSleepMinutes ? () => setState(() => _ownTarget -= 15) : null,
                  ),
                  Text(s.hours(_ownTarget), style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _ownTarget < 9 * 60 ? () => setState(() => _ownTarget += 15) : null,
                  ),
                ]),
                Row(children: [
                  Expanded(child: Text(s.ownStepSize)),
                  for (final v in const [15, 30]) ...[
                    const SizedBox(width: 6),
                    PillChip(label: '+$v min', selected: _ownInc == v, onTap: () => setState(() => _ownInc = v)),
                  ],
                ]),
              ]),
            ),
        ],
      ],
      if (move)
        BBCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(BBIcons.walk, size: 20, color: BBColors.data),
              const SizedBox(width: 8),
              Expanded(child: Text(s.moveCardTitle, style: _tt.titleSmall)),
              // Chi Q4: the "?" cites HHS 2018 p. 90.
              WhyButton(title: s.moveCardTitle, source: '$kMoveStepSource\n\n$kMoveLevelSource'),
            ]),
            // "BloomBack suggestion" in full on its own line (Chi, thread 0004 fix 12);
            // screen 10b marks "Keep my rhythm" as suggested instead
            if (!_healthyRange) Padding(padding: const EdgeInsets.only(left: 28, top: 2), child: BBTag(s.bbSuggestion)),
            const SizedBox(height: 6),
            if (_healthyRange) ...[
              // Screen 10b: already 150-300 (or more). Keep is suggested; never a lower goal.
              if (sleep) Text(s.moveHealthyTitle, style: _tt.titleSmall?.copyWith(color: BBColors.primary)),
              Text(s.moveWhatNext, style: _tt.bodyMedium),
              const SizedBox(height: 6),
              RadioCard(
                key: const Key('moveKeep'),
                selected: _move == _Move.keep || _moveNow > kMoveUpper,
                title: s.keepRhythm,
                subtitle: s.aboutWeekly(_moveNow),
                trailing: BBTag(s.suggestedTag),
                onTap: () => setState(() => _move = _Move.keep),
              ),
              if (_moveNow <= kMoveUpper) ...[
                RadioCard(
                  key: const Key('move300'),
                  selected: _move == _Move.to300,
                  title: s.toward300,
                  subtitle: s.toward300Sub,
                  trailing: WhyButton(title: s.toward300, source: kHigherGoalSource),
                  onTap: () => setState(() => _move = _Move.to300),
                ),
                RadioCard(
                  key: const Key('moveStrength'),
                  selected: _move == _Move.strength,
                  title: s.addStrength,
                  subtitle: s.addStrengthSub,
                  trailing: WhyButton(title: s.addStrength, source: kStrengthSource),
                  onTap: () => setState(() => _move = _Move.strength),
                ),
              ] else
                Text(s.above300Note, style: _tt.bodySmall),
              const SizedBox(height: 4),
              Text(s.neverLower, style: _tt.bodySmall),
            ] else ...[
              Text(credit > 0
                  ? s.planMoveWork(_walkMin, credit, mt.holding, mt.perSession, mt.sessions, mt.weeklyMinutes, leisureTarget(pl))
                  : s.planMove(_walkMin, mt.holding, mt.perSession, mt.sessions, mt.weeklyMinutes)),
              if (credit > 0) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: Text(s.workCreditLine(credit), style: _tt.bodySmall)),
                  WhyButton(title: s.workCreditLine(credit), source: kWorkCreditSource),
                ]),
              ],
              if (_activity == WorkActivity.heavy)
                Row(children: [
                  Expanded(child: Text(s.heavyNote, style: _tt.bodySmall)),
                  WhyButton(title: s.heavyNote, source: kHeavyWorkSource),
                ]),
              if (_goals.contains('weight')) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Text(s.obGoalQ, style: _tt.titleSmall)),
                  WhyButton(title: s.obGoalQ, source: kHigherGoalSource),
                ]),
                Wrap(spacing: 8, children: [
                  PillChip(label: s.goal150, selected: !_goal300, onTap: () => setState(() => _goal300 = false)),
                  PillChip(label: s.goal300, selected: _goal300, onTap: () => setState(() => _goal300 = true)),
                ]),
              ],
            ],
            if (_doctorNote) ...[
              const SizedBox(height: 8),
              Text(s.doctorNote, style: _tt.bodyMedium?.copyWith(color: BBColors.accent, fontWeight: FontWeight.w600)),
            ],
          ]),
        ),
      const SizedBox(height: 4),
      Text(s.changeAnytime, style: _tt.bodySmall),
    ]);
  }

  // 11 Pick one small step (C1 steps 4-5, C3)
  Widget _stepPage() {
    final sug = _suggestions();
    final st = _suggestedSettings();
    final reminder = _reminder ?? st.reminder1;
    final anchor = _cueAnchor ?? (_habit == null ? '' : s.habitAnchor(_habit!));
    final action = _cueAction ?? (_habit == null ? '' : s.habitAction(_habit!));
    return _list([
      _title(s.stepTitle, s.stepFits(_shift!)),
      for (final h in sug)
        BBCard(
          key: Key('habit_${h.id}'),
          border: _habit == h.id ? BBColors.primary : BBColors.line,
          borderWidth: _habit == h.id ? 1.8 : 1,
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          onTap: () => setState(() {
            _habit = h.id;
            _backups.remove(h.id);
            _cueAnchor = null;
            _cueAction = null;
          }),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(BBIcons.habit(h), color: BBColors.primary, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.habit(h.id), style: _tt.titleSmall),
                if (_habit != h.id)
                  InkWell(
                    key: Key('backup_${h.id}'),
                    onTap: () => setState(() {
                      if (_backups.contains(h.id)) {
                        _backups.remove(h.id);
                      } else if (_backups.length < 2) {
                        _backups.add(h.id);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_backups.contains(h.id) ? Icons.check_box_outlined : Icons.check_box_outline_blank,
                            size: 18, color: _backups.contains(h.id) ? BBColors.primary : BBColors.muted),
                        const SizedBox(width: 4),
                        Text(s.backup, style: _tt.bodySmall),
                      ]),
                    ),
                  ),
              ]),
            ),
            WhyButton(
              title: s.habit(h.id),
              source: h.source,
              quote: kHabitQuotes[h.id],
              body: s.whyYouChose([for (final g in _goals) s.goal(g)], _shift!),
            ),
          ]),
        ),
      _q(s.partOfDay),
      BBCard(
        key: const Key('cue'),
        onTap: () => _editCue(anchor, action),
        child: Row(children: [
          Expanded(
            child: Text.rich(TextSpan(style: _tt.bodyMedium, children: [
              TextSpan(text: '${s.afterI} '),
              TextSpan(text: anchor, style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: ', ${s.iWill} '),
              TextSpan(text: action, style: const TextStyle(fontWeight: FontWeight.w700)),
              const TextSpan(text: '.'),
            ])),
          ),
          const Icon(Icons.edit_outlined, size: 18, color: BBColors.muted),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Expanded(child: Text(s.remindAt, style: _tt.titleSmall)),
          OutlinedButton.icon(
            key: const Key('remindAt'),
            onPressed: () async {
              final t = await pickTime(context, reminder);
              if (t != null) setState(() => _reminder = t);
            },
            icon: const Icon(Icons.expand_more, size: 18),
            label: Text(hhmm(reminder)),
          ),
        ]),
      ),
    ]);
  }

  Future<void> _editCue(String anchor, String action) async {
    final a = TextEditingController(text: anchor), b = TextEditingController(text: action);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.yourOwnWords, style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(controller: a, maxLength: 60, decoration: InputDecoration(labelText: s.afterI)),
          TextField(controller: b, maxLength: 60, decoration: InputDecoration(labelText: s.iWill)),
          const SizedBox(height: 8),
          PrimaryButton(label: s.save, onPressed: () => Navigator.pop(c, true)),
        ]),
      ),
    );
    if (ok != true || !mounted) return;
    final na = stripIdentifiers(a.text), nb = stripIdentifiers(b.text);
    if (hasDangerSign('$na $nb')) {
      _showDanger();
      return;
    }
    setState(() {
      _cueAnchor = na.isEmpty ? null : na;
      _cueAction = nb.isEmpty ? null : nb;
    });
  }
}

/// Arabic is not translated yet (needs a native check): say so instead of switching.
Future<void> showArabicSoon(BuildContext context) =>
    showPilotSheet(context, s.arabicSoonTitle, s.arabicSoonBody);
