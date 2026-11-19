// Today (Chi's screen 12): one small step with a one-tap check-in, sleep this week,
// the Lapse Radar card and a small garden. Nudges (C5) appear one at a time; the
// welcome back after a break is its own screen (14).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import '../rules/environment.dart';
import '../rules/habits.dart';
import '../rules/levels.dart';
import '../rules/plan.dart';
import '../rules/regularity.dart';
import '../rules/reminders.dart';
import '../rules/sources.dart';
import 'account_ui.dart';
import 'after_step.dart';
import 'common.dart';
import 'fasting.dart';
import 'four_weeks.dart';
import 'garden.dart';
import 'health_numbers.dart';
import 'step_timer.dart';
import 'today_hero.dart';
import 'your_day.dart';
import 'welcome_back.dart';

const kBandSleepSource =
    'Main sleep window adapted from the HDCZA method (van Hees et al. 2018, Sci Rep 8:12975) and '
    'the 5-degree / 5-minute rule (van Hees et al. 2015, PLoS ONE 10:e0142533).';

class TodayScreen extends StatelessWidget {
  final ValueChanged<int> openTab;
  const TodayScreen({super.key, required this.openTab});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    // Today runs edge to edge under the status bar (for the picture); the welcome-back screen has no picture
    if (app.nudge == Nudge.welcomeBack) return const SafeArea(bottom: false, child: WelcomeBackView());
    final pl = app.plan!;
    final tt = Theme.of(context).textTheme;
    final (label, greeting) = _greeting(app);
    final showSleep = pl.domains.contains(Domain.sleep) || app.minutes.isNotEmpty;
    final light = dayLightAt(app.clock());
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBarFor(light),
      child: ColoredBox(
        color: pageColorFor(light),
        child: RefreshIndicator(
          onRefresh: app.sync,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              TodayHero(
                app: app,
                label: label,
                greeting: greeting,
                onOpenGarden: () => openTab(2),
                onAvatar: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AccountScreen())),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Your day around today's shift (Chi, thread 0008)
                  YourDayCard(app: app),
                  for (final r in app.radar) _RadarCard(app: app, item: r, openPlan: () => openTab(1)),
                  _NudgeCard(app: app),
                  if (app.reviewDue && app.review[app.reviewKey] == null)
                    BBCard(
                      key: const Key('fourWeeksCard'),
                      color: BBColors.primaryLight,
                      border: BBColors.primaryBorder,
                      onTap: () => openFourWeeks(context),
                      child: Row(children: [
                        Expanded(child: Text(s.fourWeeksCard, style: tt.titleSmall)),
                        Text(s.answer, style: tt.labelLarge?.copyWith(color: BBColors.primary)),
                        const Icon(Icons.chevron_right, color: BBColors.primary),
                      ]),
                    ),
                  _StepCard(app: app, openTab: openTab),
                  if (app.stepMinutes() != null && (app.todayCheckin == null || app.changingCheckin)) _MoveMusicCard(app: app),
                  AfterStepCards(app: app),
                  if (showSleep) _SleepWeekCard(app: app),
                  if (pl.domains.contains(Domain.movement)) _MoveCard(app: app),
                  if (app.offerBiomarkers)
                    BBCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.bioOfferTitle, style: tt.titleSmall),
                        const SizedBox(height: 4),
                        Text(s.bioOfferBody, style: tt.bodySmall),
                        Wrap(spacing: 8, children: [
                          TextButton(
                            onPressed: () => Navigator.of(context)
                                .push(MaterialPageRoute<void>(builder: (_) => const HealthNumbersScreen())),
                            child: Text(s.add),
                          ),
                          TextButton(onPressed: app.hideBiomarkerOffer, child: Text(s.notNow)),
                        ]),
                      ]),
                    ),
                  GardenStrip(app: app, onTap: () => openTab(2)),
                  if (app.settings.bandId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            app.syncing
                                ? s.bandStatus(app.syncStep ?? '')
                                : (app.lastSync == null ? s.noBandData : s.lastSync(s.ago(app.clock().difference(app.lastSync!)))),
                            style: tt.bodySmall,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: app.syncing ? null : app.sync,
                          icon: const Icon(Icons.sync, size: 18),
                          label: Text(s.syncNow),
                        ),
                      ]),
                    ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Greeting by shift (Chi: "Shift done · Rest well, Ravi" after a night shift).
  static (String, String) _greeting(AppState app) {
    final name = app.displayName;
    final h = app.clock().hour;
    final night = app.profile!.shift == ShiftType.nightFixed || (app.todayRules?.firstNights ?? false);
    if (night) {
      if (h >= 6 && h < 14) return (s.shiftDone, s.restWell(name));
      if (h >= 14 && h < 20) return (s.beforeShift, h < 17 ? s.goodAfternoon(name) : s.goodEvening(name));
      return (s.onShift, h < 6 ? s.restWell(name) : s.goodEvening(name));
    }
    if (h < 12) return ('', s.goodMorning(name));
    if (h < 17) return ('', s.goodAfternoon(name));
    return ('', s.goodEvening(name));
  }
}

/// "Why this suggestion?" for today's habit (screen 13).
void showHabitWhy(BuildContext context, AppState app, Habit h) {
  final p = app.profile!, pl = app.plan!;
  final rules = app.todayRules;
  final change = rules == null || rules.change == HabitChange.none ? '' : ' ${s.changeNote(rules.change, s.habit(pl.mainHabitId))}';
  showWhy(
    context,
    s.habit(h.id),
    h.source,
    body: s.whyYouChose([for (final g in p.goalIds) s.goal(g)], p.shift) + change,
    quote: kHabitQuotes[h.id],
    target: h.area == HabitArea.movement
        ? s.targetMove(movementTarget(pl).weeklyMinutes)
        : (pl.domains.contains(Domain.sleep) ? s.targetSleep(pl.sleepTargetMinutes) : null),
  );
}

class _StepCard extends StatelessWidget {
  final AppState app;
  final ValueChanged<int> openTab;
  const _StepCard({required this.app, required this.openTab});

  @override
  Widget build(BuildContext context) {
    final pl = app.plan!;
    final habit = app.mainHabit!;
    final rules = app.todayRules!;
    final tt = Theme.of(context).textTheme;
    final dose = app.habitDose();
    final cue = habit.id == pl.mainHabitId
        ? s.cue(pl.cueAnchor ?? s.habitAnchor(habit.id), pl.cueAction ?? s.habitAction(habit.id))
        : null;
    Widget note(String text, String source) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(Icons.info_outline, size: 16, color: BBColors.accent),
            ),
            const SizedBox(width: 6),
            Expanded(child: Padding(padding: const EdgeInsets.only(top: 4), child: Text(text, style: tt.bodySmall?.copyWith(color: BBColors.ink)))),
            WhyButton(title: text, source: source),
          ]),
        );
    return BBCard(
      key: const Key('stepCard'),
      color: BBColors.primaryLight,
      border: BBColors.primaryBorder,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: CapsLabel(s.todayHabit)),
          WhyButton(
            key: const Key('stepWhy'),
            title: s.habit(habit.id),
            source: habit.source,
            onTap: () => showHabitWhy(context, app, habit),
          ),
        ]),
        Text(s.habit(habit.id), style: tt.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
        if (dose.isNotEmpty) Text(dose, style: tt.bodyMedium),
        if (cue != null) Text(cue, style: tt.bodySmall),
        if (rules.change != HabitChange.none)
          note(
              s.changeNote(rules.change, s.habit(pl.mainHabitId)),
              switch (rules.change) {
                HabitChange.firstNights => kNightsSource,
                HabitChange.outdoorHeat => kOutdoorHeatSource,
                HabitChange.heavyWork => kHeavyWorkSource,
                HabitChange.fasting => kFastingSource,
                _ => habit.source,
              }),
        if (rules.heatNote) note(s.heatNote, kHeatSource),
        if (rules.fasting && rules.change != HabitChange.fasting) note(s.fastingNote, kFastingSource),
        if (app.profile!.shift == ShiftType.irregular) note(s.irregularNote, kIrregularSource),
        if (app.profile!.shift == ShiftType.longOrSplit && habit.area == HabitArea.movement)
          note(s.longShiftNote, kLongShiftSource),
        const SizedBox(height: 12),
        _CheckinRow(app: app, openTab: openTab),
      ]),
    );
  }
}

class _SleepWeekCard extends StatelessWidget {
  final AppState app;
  const _SleepWeekCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final pl = app.plan!;
    final tt = Theme.of(context).textTheme;
    final band = app.sleepLast7;
    final goal = pl.sleepTargetMinutes;
    final spread = app.spreadOfferToday;
    final hasGoal = pl.domains.contains(Domain.sleep);
    final value = band ?? app.profile!.selfSleepMinutes;
    return BBCard(
      key: const Key('sleepWeek'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: CapsLabel('${s.sleepThisWeek} · ${band == null ? s.sleepYouToldUs : s.average}')),
          if (band != null) BBTag(s.estimate),
          WhyButton(
            title: s.sleepThisWeek,
            source: band == null ? kSleepLevelSource : '$kBandSleepSource\n\n$kSleepLevelSource',
            body: band == null ? null : s.bandSleepNote,
          ),
        ]),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(s.hm(value), style: heading(24)),
          const SizedBox(width: 8),
          if (hasGoal)
            Expanded(
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Flexible(child: Text(s.goalThisWeek(goal), textAlign: TextAlign.end, style: tt.bodySmall)),
                if (value >= goal) const Icon(Icons.check, size: 16, color: BBColors.primary),
              ]),
            ),
        ]),
        if (hasGoal) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: goal == 0 ? 1 : (value / goal).clamp(0.0, 1.0), minHeight: 8),
          ),
        ],
        const SizedBox(height: 6),
        Text(band == null ? s.noBandSleep : s.bandSleepNote, style: tt.bodySmall),
        if (hasGoal && pl.spreadTargetMinutes != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Expanded(child: Text(s.spreadTarget(pl.spreadTargetMinutes!), style: tt.bodySmall?.copyWith(color: BBColors.ink))),
              WhyButton(title: s.spreadTitle, source: kSpreadSource),
            ]),
          ),
        if (spread != null) ...[
          const Divider(height: 20),
          Row(children: [
            Expanded(child: Text(s.spreadTitle, style: tt.titleSmall)),
            Flexible(flex: 2, child: BBTag(s.bbSuggestion)),
            WhyButton(title: s.spreadTitle, source: kSpreadSource),
          ]),
          Text(s.spreadOffer(spread.current, app.currentSpread?.$2 == DataSource.watch, spread.target), style: tt.bodySmall),
          Wrap(spacing: 8, children: [
            TextButton(onPressed: () => app.acceptSpread(spread.target), child: Text(s.tryIt)),
            TextButton(onPressed: app.declineSpread, child: Text(s.notNow)),
          ]),
        ],
      ]),
    );
  }
}

class _MoveCard extends StatelessWidget {
  final AppState app;
  const _MoveCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final pl = app.plan!;
    final tt = Theme.of(context).textTheme;
    final credit = pl.workCredit;
    final mt = movementTarget(pl);
    final usual = pl.movementBaseWeekly;
    final healthy = usual >= kMoveGuideline;
    final keeping = healthy && mt.holding;

    // No band (design 12b): progress from check-ins, never "0 min"; the user's own level in words.
    if (!app.hasBandData) {
      final week = app.weekCheckins;
      final did = week.where((d) => d.$2 == CheckinStatus.done || d.$2 == CheckinStatus.partial).length;
      final planned = mt.sessions.clamp(1, 7);
      const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      Widget dot(int i) {
        final (day, st) = week[i];
        // days still to come, and days before the plan started, are empty (never grey like a skipped day)
        final future = day > app.today || day < app.planDay;
        final (Color bg, Color border, Widget? mark) = switch (st) {
          CheckinStatus.done => (BBColors.primary, BBColors.primary, const Icon(Icons.check, size: 16, color: Colors.white)),
          CheckinStatus.partial =>
            (BBColors.primaryLight, BBColors.primaryBorder, const Text('~', style: TextStyle(color: BBColors.primary, fontWeight: FontWeight.w700))),
          _ => (future ? Colors.white : BBColors.grey, future ? BBColors.line : BBColors.grey, null),
        };
        return Expanded(
          child: Column(children: [
            Container(
              height: 26,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7), border: Border.all(color: border)),
              child: mark,
            ),
            const SizedBox(height: 3),
            Text(letters[i], style: tt.bodySmall),
          ]),
        );
      }

      return Column(children: [
        BBCard(
          key: const Key('moveCheckins'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: CapsLabel(s.thisWeekCaps)),
              Flexible(child: Text(s.fromCheckins, style: tt.bodySmall, textAlign: TextAlign.end)),
            ]),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Text(s.daysOfPlan(did, planned), key: const Key('daysOfPlan'), style: heading(22))),
              Text(s.yourPlan, style: tt.bodySmall),
            ]),
            const SizedBox(height: 8),
            Row(children: [for (var i = 0; i < 7; i++) dot(i)]),
          ]),
        ),
        if (usual > 0)
          BBCard(
            key: const Key('moveLevel'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CapsLabel(s.movementCaps),
              const SizedBox(height: 2),
              Text(keeping ? s.toldUsHealthy(usual) : s.toldUsTowards(usual, mt.weeklyMinutes), style: tt.bodyMedium),
              if (credit > 0)
                Row(children: [
                  Expanded(child: Text(s.workCreditLine(credit), style: tt.bodySmall)),
                  WhyButton(title: s.workCreditLine(credit), source: kWorkCreditSource),
                ]),
              if (app.showDoctorNote)
                Text(s.doctorNote, style: tt.bodySmall?.copyWith(color: BBColors.accent, fontWeight: FontWeight.w600)),
            ]),
          ),
      ]);
    }

    // With a band (design 12d): active minutes, labelled as from the band, against the user's usual level when
    // keeping the rhythm, otherwise this week's suggested target.
    final leisure = leisureTarget(pl);
    final compare = keeping ? usual - credit : leisure;
    return BBCard(
      key: const Key('moveCard'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: CapsLabel(s.activeMinutes7)),
          BBTag(s.fromTheBand),
          WhyButton(title: s.activeMinutes7, source: '${s.activeMinutesSource}\n\n$kMoveLevelSource\n\n$kMoveStepSource'),
        ]),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${app.weekModerate} min', key: const Key('bandMinutes'), style: heading(24)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                keeping
                    ? s.yourUsual(usual)
                    : (credit > 0 ? s.leisureVsTarget(app.weekModerate, leisure) : s.weekVsTarget(app.weekModerate, leisure)),
                textAlign: TextAlign.end,
                style: tt.bodySmall),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: compare <= 0 ? 1 : (app.weekModerate / compare).clamp(0.0, 1.0), minHeight: 8),
        ),
        const SizedBox(height: 4),
        Text(s.bandCountsWalking, style: tt.bodySmall),
        if (credit > 0)
          Row(children: [
            Expanded(child: Text(s.workCreditLine(credit), style: tt.bodySmall)),
            WhyButton(title: s.workCreditLine(credit), source: kWorkCreditSource),
          ]),
        if (app.showDoctorNote) Text(s.doctorNote, style: tt.bodySmall?.copyWith(color: BBColors.accent, fontWeight: FontWeight.w600)),
        Text('${s.stepsToday}: ${s.count(app.todaySummary?.steps ?? 0)} · ${s.fromBand}', style: tt.bodySmall),
      ]),
    );
  }
}

/// "22 min" under Start; stretching and light strength say "BloomBack suggestion" with a "?"; "Change minutes"
/// lets the user pick their own (Chi, thread 0007, 17/11).
class _MinutesRow extends StatelessWidget {
  final AppState app;
  final int minutes;
  const _MinutesRow({required this.app, required this.minutes});

  @override
  Widget build(BuildContext context) {
    final id = app.mainHabit!.id;
    final own = id == 'stretch' || id == 'strength';
    final custom = app.settings.stepMins.containsKey(id);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
        Text(s.stepMinutesLine(minutes), key: const Key('stepMinutes'), style: Theme.of(context).textTheme.bodySmall),
        if (own && !custom) BBTag(s.bbSuggestion),
        if (!custom && (own || id == 'breathing'))
          WhyButton(
            key: const Key('stepMinutesWhy'),
            title: s.minutesTitle,
            source: own ? s.timerOwnSource : s.timerBreathSource,
          ),
        TextButton(
          key: const Key('changeMinutes'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: () => _pick(context),
          child: Text(s.changeMinutes),
        ),
      ]),
    );
  }

  Future<void> _pick(BuildContext context) async {
    var m = minutes;
    final suggested = app.suggestedStepMinutes()!;
    final r = await showDialog<int>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(s.minutesTitle),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(s.minutesBody),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(key: const Key('minLess1'), onPressed: m > 1 ? () => set(() => m--) : null, icon: const Icon(Icons.remove_circle_outline)),
              Text('$m min', key: const Key('minValue'), style: heading(24)),
              IconButton(key: const Key('minMore1'), onPressed: m < 90 ? () => set(() => m++) : null, icon: const Icon(Icons.add_circle_outline)),
            ]),
            TextButton(onPressed: () => Navigator.pop(c, -1), child: Text('${s.useSuggested} ($suggested min)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(s.cancel)),
            FilledButton(key: const Key('minSave'), onPressed: () => Navigator.pop(c, m), child: Text(s.save)),
          ],
        ),
      ),
    );
    if (r == null) return;
    await app.setStepMinutes(r == -1 ? null : r);
  }
}

/// "Music while you move · BloomBack music · gentle · Change" under a timed step (Chi's design, screen 1).
class _MoveMusicCard extends StatelessWidget {
  final AppState app;
  const _MoveMusicCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final st = app.settings;
    return BBCard(
      key: const Key('moveMusicCard'),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(children: [
        const Icon(Icons.music_note_outlined, color: BBColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CapsLabel(s.musicWhileYouMove),
            Text(s.stepMusicChoice(st.stepMusic, st.songName), style: tt.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        TextButton(
          key: const Key('moveMusicChange'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AfterStepScreen())),
          child: Text(s.change),
        ),
      ]),
    );
  }
}

/// Done / Partly / Not today. After a check-in the three buttons give way to the result and a small "Change"
/// for a mistaken tap (Chi, thread 0004 fix 8); they come back on the next day (local midnight).
class _CheckinRow extends StatelessWidget {
  final AppState app;
  final ValueChanged<int> openTab;
  const _CheckinRow({required this.app, required this.openTab});

  @override
  Widget build(BuildContext context) {
    final cur = app.todayCheckin;
    if (cur != null && !app.changingCheckin) return _result(context, cur);
    final minutes = app.stepMinutes();
    if (minutes != null) return _start(context, minutes);
    Widget b(CheckinStatus st, String label, IconData icon) {
      final on = cur == st;
      // One line on narrow phones: "Not today" wrapped onto two lines on a 1080 px screen.
      final text = FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, softWrap: false));
      const pad = EdgeInsets.symmetric(horizontal: 8);
      final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Semantics(
            selected: on,
            child: on
                ? FilledButton.icon(
                    style: FilledButton.styleFrom(padding: pad, shape: shape),
                    onPressed: () => _tap(context, st),
                    icon: Icon(icon, size: 18),
                    label: text)
                : OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: pad, shape: shape),
                    onPressed: () => _tap(context, st),
                    icon: Icon(icon, size: 18),
                    label: text),
          ),
        ),
      );
    }

    return Row(children: [
      b(CheckinStatus.done, s.checkinDone, Icons.check),
      b(CheckinStatus.partial, s.checkinPartial, Icons.timelapse),
      b(CheckinStatus.notToday, s.checkinNotToday, Icons.close),
    ]);
  }

  /// A step with a time (Chi, thread 0007 "music while you move"): Start opens the timer; the usual answers stay
  /// as small links for someone who already did it.
  Widget _start(BuildContext context, int minutes) {
    final music = app.settings.stepMusic != 'off';
    Widget link(String key, String label, CheckinStatus st) => TextButton(
          key: Key(key),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: () => _tap(context, st),
          child: Text(label),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FilledButton.icon(
        key: const Key('stepStart'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        onPressed: () => openStepTimer(context, app, openTab: openTab),
        icon: const Icon(Icons.play_arrow),
        label: Text(s.startStep(minutes, music: music)),
      ),
      _MinutesRow(app: app, minutes: minutes),
      Wrap(alignment: WrapAlignment.center, children: [
        link('checkinAlready', s.didItAlready, CheckinStatus.done),
        link('checkinPartlyLink', s.checkinPartial, CheckinStatus.partial),
        link('checkinNotTodayLink', s.checkinNotToday, CheckinStatus.notToday),
      ]),
    ]);
  }

  Widget _result(BuildContext context, CheckinStatus st) {
    final tt = Theme.of(context).textTheme;
    final habit = s.habit(app.mainHabit!.id);
    final (icon, fill, fg) = switch (st) {
      CheckinStatus.done => (Icons.check, BBColors.primary, Colors.white),
      CheckinStatus.partial => (Icons.timelapse, BBColors.primary, Colors.white),
      CheckinStatus.notToday => (Icons.nightlight_outlined, BBColors.grey, BBColors.muted),
    };
    return Container(
      key: const Key('checkinResult'),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: fg),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.checkinResultTitle(st, habit), style: tt.titleSmall),
            Text(s.checkinResultLine(st), style: tt.bodySmall),
          ]),
        ),
        TextButton(
          key: const Key('checkinChange'),
          onPressed: app.startChangingCheckin,
          child: Text(s.change),
        ),
      ]),
    );
  }

  Future<void> _tap(BuildContext context, CheckinStatus st) async {
    final was = app.todayCheckin;
    if (st == was) {
      // the same answer again: nothing new, no second sound
      app.stopChangingCheckin();
      return;
    }
    await app.checkIn(st);
    // The chosen sound after Done or Partly (Chi, thread 0007), once per change.
    if ((st == CheckinStatus.done || st == CheckinStatus.partial) && context.mounted) {
      await playAfterStep(context, app);
    }
  }
}

/// Gentle, one-at-a-time suggestions (C5) and the end-of-week-1 recalibration (B4).
class _NudgeCard extends StatelessWidget {
  final AppState app;
  const _NudgeCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final pl = app.plan!;
    final now = app.nowMinute;
    final tt = Theme.of(context).textTheme;
    switch (app.nudge) {
      case Nudge.welcomeBack:
        return const SizedBox.shrink(); // its own screen
      case Nudge.difficulty:
        return BBCard(
          key: const Key('difficulty'),
          color: BBColors.accentLight,
          border: const Color(0xFFF2DFAE),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(s.difficultyTitle, style: tt.titleSmall)),
              WhyButton(title: s.difficultyTitle, source: kStepUpSource),
            ]),
            Text(s.difficultyBody, style: tt.bodySmall?.copyWith(color: BBColors.ink)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final b in s.barriersChi)
                PillChip(
                  label: b,
                  selected: (app.review['barriers'] as List?)?.contains(b) ?? false,
                  onTap: () => app.saveReview({
                    ...app.review,
                    'barriers': [...?(app.review['barriers'] as List?), b],
                  }),
                ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(
                onPressed: () async {
                  await app.savePlan(stepDown(pl, now, app.profile!.selfSleepMinutes));
                  await app.dismissNudge();
                },
                child: Text(s.shrink),
              ),
              if (pl.backupHabitIds.isNotEmpty)
                OutlinedButton(onPressed: () => swapToBackup(context, app), child: Text(s.swap)),
              OutlinedButton(onPressed: () => showMoveReminderSheet(context, app), child: Text(s.move)),
            ]),
          ]),
        );
      case Nudge.stepUp:
        return BBCard(
          key: const Key('stepUp'),
          color: BBColors.primaryLight,
          border: BBColors.primaryBorder,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(s.stepUpTitle, style: tt.titleSmall)),
              Flexible(flex: 2, child: BBTag(s.bbSuggestion)),
              WhyButton(title: s.stepUpTitle, source: '$kStepUpSource\n\n$kMoveStepSource'),
            ]),
            Text(s.stepUpBody, style: tt.bodySmall?.copyWith(color: BBColors.ink)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              FilledButton(onPressed: () => app.savePlan(stepUp(pl, now)), child: Text(s.stepUpYes)),
              TextButton(onPressed: app.dismissNudge, child: Text(s.keepAsIs)),
            ]),
          ]),
        );
      case Nudge.none:
        return _recalibration(context);
    }
  }

  Widget _recalibration(BuildContext context) {
    final pl = app.plan!;
    final w = app.weeks;
    if (!pl.domains.contains(Domain.movement) || w.isEmpty || w.first.days < 7) {
      return const SizedBox.shrink();
    }
    if (app.review['recalibrated'] == true) return const SizedBox.shrink();
    final measured = w.first.moderateMinutes;
    if (!shouldOfferRecalibration(app.profile!.selfWalkMinutes, measured)) {
      return const SizedBox.shrink();
    }
    return BBCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.recalibrate(measured)),
        Wrap(spacing: 8, children: [
          TextButton(
            onPressed: () async {
              final np = Plan.fromJson(pl.toJson())
                ..movementBaseWeekly = moveLevel(measured) == MoveLevel.inactive ? 0 : measured
                ..movementStep = 0
                ..stepStartMinute = app.nowMinute;
              await app.savePlan(np);
              await app.saveReview({...app.review, 'recalibrated': true});
            },
            child: Text(s.adjust),
          ),
          TextButton(
            onPressed: () => app.saveReview({...app.review, 'recalibrated': true}),
            child: Text(s.keepAsIs),
          ),
        ]),
      ]),
    );
  }
}

/// C5 "Swap": pick one of the user's own backups as the main habit.
Future<bool> swapToBackup(BuildContext context, AppState app, {bool dismiss = true}) async {
  final pl = app.plan!;
  final id = pl.backupHabitIds.length == 1
      ? pl.backupHabitIds.first
      : await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (c) => SafeArea(
            child: ListView(shrinkWrap: true, children: [
              for (final b in pl.backupHabitIds)
                ListTile(
                  title: Text(s.habit(b)),
                  subtitle: Text(habitById(b).source),
                  onTap: () => Navigator.pop(c, b),
                ),
            ]),
          ),
        );
  if (id == null) return false;
  final np = Plan.fromJson(pl.toJson())
    ..backupHabitIds = [...pl.backupHabitIds.where((x) => x != id), pl.mainHabitId]
    ..mainHabitId = id
    ..cueAnchor = null
    ..cueAction = null;
  await app.savePlan(np);
  if (dismiss) await app.dismissNudge();
  return true;
}

/// C5 Lapse Radar: a heads-up a day or two before nights, before Ramadan, before the heat.
class _RadarCard extends StatelessWidget {
  final AppState app;
  final RadarItem item;
  final VoidCallback openPlan;
  const _RadarCard({required this.app, required this.item, required this.openPlan});

  @override
  Widget build(BuildContext context) {
    final inUae = app.profile?.city?.inUae ?? true;
    final tt = Theme.of(context).textTheme;
    final (title, body, source) = switch (item.kind) {
      RadarKind.nightsSoon => (s.radarNightsTitle, s.radarNightsBody(item.days), kNightsSource),
      RadarKind.nextNightsUnknown => (s.radarNextNightsTitle, s.radarNextNightsBody, kNightsSource),
      RadarKind.ramadanSoon => (s.radarRamadanTitle, s.radarRamadanBody(item.from!, item.to!, inUae), kFastingSource),
      RadarKind.heatSoon => (s.radarHeatTitle, s.radarHeatBody(item.days), kHeatSource),
    };
    return BBCard(
      color: BBColors.accentLight,
      border: const Color(0xFFF2DFAE),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.warning_amber_rounded, size: 20, color: BBColors.accent),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: tt.titleSmall)),
          if (item.kind == RadarKind.nightsSoon)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: BBColors.accent, visualDensity: VisualDensity.compact),
              onPressed: openPlan,
              child: const Text('Plan ›'),
            ),
          WhyButton(title: title, source: source),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text(body, style: tt.bodySmall?.copyWith(color: BBColors.ink)),
        ),
        Wrap(spacing: 4, runSpacing: 0, children: [
          if (item.kind == RadarKind.nextNightsUnknown)
            TextButton(
              onPressed: () async {
                final now = app.clock();
                final d = await showDatePicker(
                  context: context,
                  initialDate: now.add(const Duration(days: 3)),
                  firstDate: DateTime(now.year, now.month, now.day),
                  lastDate: now.add(const Duration(days: 120)),
                );
                if (d != null) await app.saveProfile(app.profile!.copy()..nextNightsDate = dateKey(d));
              },
              child: Text(s.addDate),
            ),
          if (item.kind == RadarKind.ramadanSoon) ...[
            TextButton(
              onPressed: () => useSuggestedFasting(app, RamadanDates(0, item.from!, item.to!)),
              child: Text(s.useDates),
            ),
            TextButton(onPressed: () => pickFastingDates(context, app), child: Text(s.pickDates)),
          ],
          TextButton(
            style: TextButton.styleFrom(foregroundColor: BBColors.muted),
            onPressed: () => app.hideRadar(item),
            child: Text(s.hide),
          ),
        ]),
      ]),
    );
  }
}

/// C5 "Move": change today's reminder time right here (one day, or keep it).
/// Returns true when a reminder was moved.
Future<bool> showMoveReminderSheet(BuildContext context, AppState app, {bool dismiss = true}) async {
  final irregular = app.profile!.shift == ShiftType.irregular;
  final st = app.settings;
  final today = app.todayRules!;
  final todayKey = dateKey(app.clock());
  var keep = false;
  final picked = await showModalBottomSheet<(int, int, bool)>(
    context: context,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setSheet) {
        Widget slot(int i, int current) => ListTile(
              key: Key('move_$i'),
              title: Text(irregular ? s.moveOneOff : s.reminderN(i)),
              trailing: Text(hhmm(current)),
              onTap: () async {
                final t = await pickTime(c, current < 0 ? 19 * 60 : current);
                if (t != null && c.mounted) Navigator.pop(c, (i, t, keep));
              },
            );
        final times = today.reminderTimes;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.moveTitle, style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(s.moveBody),
              if (irregular)
                slot(0, times.isEmpty ? -1 : times.first)
              else ...[
                slot(0, st.movedDate == todayKey && st.movedIndex == 0 ? st.movedTime : st.reminder1),
                slot(1, st.movedDate == todayKey && st.movedIndex == 1 ? st.movedTime : st.reminder2),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.moveKeep),
                  value: keep,
                  onChanged: (v) => setSheet(() => keep = v),
                ),
              ],
            ]),
          ),
        );
      },
    ),
  );
  if (picked == null || !context.mounted) return false;
  final (i, t, k) = picked;
  final msg = ScaffoldMessenger.of(context);
  if (inQuiet(t, today.quietStart, today.quietEnd)) {
    msg.showSnackBar(SnackBar(content: Text(s.reminderInQuiet)));
    return false;
  }
  await app.moveReminder(i, t, keep: k);
  if (dismiss) await app.dismissNudge();
  final heat = today.hot && today.habit.outdoor && inMidday(t);
  msg.showSnackBar(SnackBar(content: Text(heat ? s.moveMidday : s.moveSaved(hhmm(t)))));
  return true;
}
