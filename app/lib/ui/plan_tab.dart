// Plan tab (Chi's screen 20): main goal and reason, the sleep ladder ("this week"),
// the small step with its reminder, quiet hours and backup, and movement ("Add"
// when not started). Everything here is the user's to change.
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import '../rules/environment.dart';
import '../rules/habits.dart';
import '../rules/levels.dart';
import '../rules/plan.dart';
import '../rules/regularity.dart';
import '../rules/reminders.dart';
import 'ask.dart';
import 'common.dart';
import 'four_weeks.dart';
import 'icons.dart';
import 'today.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = app.profile!, pl = app.plan!;
    final tt = Theme.of(context).textTheme;
    final habit = habitById(pl.mainHabitId);
    final st = app.settings;
    final irregular = p.shift == ShiftType.irregular;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      Text(s.planTitle, style: tt.headlineSmall),
      const SizedBox(height: 8),
      BBCard(
        key: const Key('mainGoal'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.track_changes, color: BBColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CapsLabel(s.mainGoal),
                Text(s.goal(p.mainGoalId), style: tt.titleMedium),
              ]),
            ),
            TextButton(key: const Key('changeGoal'), onPressed: () => openChangePlan(context), child: Text(s.change)),
          ]),
          if (p.motivation.isNotEmpty)
            Text(s.yourReasonLine(p.motivation), style: tt.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
        ]),
      ),
      BBCard(
        key: const Key('askCard'),
        color: BBColors.accentLight,
        border: const Color(0xFFF2DFAE),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AskScreen())),
        child: Row(children: [
          const Icon(Icons.chat_bubble_outline, color: BBColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.askTitle, style: tt.titleSmall),
              Text(s.askRowSub, style: tt.bodySmall),
            ]),
          ),
          const Icon(Icons.chevron_right, color: BBColors.muted),
        ]),
      ),
      if (pl.domains.contains(Domain.sleep)) _SleepLadder(app: app) else _NotStarted(app: app, domain: Domain.sleep),
      BBCard(
        key: const Key('smallStep'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CapsLabel(s.yourSmallStep),
          const SizedBox(height: 4),
          Row(children: [
            Icon(BBIcons.habit(habit), color: BBColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(s.habit(habit.id), style: tt.titleSmall)),
            WhyButton(title: s.habit(habit.id), source: habit.source, onTap: () => showHabitWhy(context, app, habit)),
          ]),
          Text(s.cue(pl.cueAnchor ?? s.habitAnchor(habit.id), pl.cueAction ?? s.habitAction(habit.id)), style: tt.bodySmall),
          const SizedBox(height: 4),
          Text(
            irregular
                ? s.remindersFollowCheckins
                : s.reminderLine([for (final t in activeReminderTimes(st)) hhmm(t)], hhmm(st.quietStart), hhmm(st.quietEnd)),
            key: const Key('reminderLine'),
            style: tt.bodySmall,
          ),
          if (pl.backupHabitIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            CapsLabel(s.backup),
            for (final b in pl.backupHabitIds)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Icon(BBIcons.habit(habitById(b)), size: 18, color: BBColors.muted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.habit(b), style: tt.bodyMedium)),
                ]),
              ),
          ],
        ]),
      ),
      if (pl.domains.contains(Domain.movement)) _MovePlan(app: app) else _NotStarted(app: app, domain: Domain.movement),
      if (app.reviewDue)
        BBCard(
          onTap: () => openFourWeeks(context),
          child: Row(children: [
            Expanded(child: Text(s.fourWeeksHeader, style: tt.titleSmall)),
            const Icon(Icons.chevron_right),
          ]),
        ),
    ]);
  }
}

class _SleepLadder extends StatelessWidget {
  final AppState app;
  const _SleepLadder({required this.app});

  @override
  Widget build(BuildContext context) {
    final p = app.profile!, pl = app.plan!;
    final tt = Theme.of(context).textTheme;
    final next = pl.sleepTargetMinutes + pl.sleepIncrement;
    final steps = <(String, String)>[
      (s.hoursDecimal(p.selfSleepMinutes), s.startShort),
      (s.hoursDecimal(pl.sleepTargetMinutes), s.thisWeekShort),
      if (next < kSleepGuideline) (s.hoursDecimal(next), s.nextShort),
      if (pl.sleepTargetMinutes < kSleepGuideline) (s.hoursDecimal(kSleepGuideline), s.goalShort),
    ];
    return BBCard(
      key: const Key('sleepLadder'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(BBIcons.sleep, color: BBColors.data, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(s.domainLabel(Domain.sleep), style: tt.titleMedium)),
          WhyButton(
            title: s.domainLabel(Domain.sleep),
            source: '$kSleepStepSource\n\n$kSleepLevelSource',
            target: s.targetSleep(pl.sleepTargetMinutes),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const Icon(Icons.chevron_right, size: 14, color: BBColors.muted),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: i == 1 ? BBColors.primaryLight : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(children: [
                  Text(steps[i].$1,
                      style: TextStyle(fontWeight: FontWeight.w600, color: i == 1 ? BBColors.primary : BBColors.ink)),
                  Text(steps[i].$2,
                      style: tt.bodySmall?.copyWith(
                          fontSize: 11, color: i == 1 ? BBColors.primary : null, fontWeight: i == 1 ? FontWeight.w700 : null)),
                ]),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          BBTag(s.bbSuggestion),
          Text(s.perStep(pl.sleepIncrement), style: tt.bodySmall),
          TextButton(key: const Key('changePace'), onPressed: () => _changePace(context), child: Text(s.changePace)),
        ]),
        if (pl.spreadTargetMinutes != null)
          Row(children: [
            Expanded(child: Text(s.spreadTarget(pl.spreadTargetMinutes!), style: tt.bodySmall)),
            WhyButton(title: s.spreadTitle, source: kSpreadSource),
          ]),
      ]),
    );
  }

  /// Chi Q3: +30 (suggested) or +15 (gentler); changes the step size, never the target now.
  Future<void> _changePace(BuildContext context) async {
    final pl = app.plan!;
    final v = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(s.changePace, style: Theme.of(c).textTheme.titleLarge)),
              Flexible(flex: 2, child: BBTag(s.bbSuggestion)),
            ]),
            const SizedBox(height: 8),
            RadioCard(selected: pl.sleepIncrement == 30, title: s.pace30, onTap: () => Navigator.pop(c, 30)),
            RadioCard(selected: pl.sleepIncrement == 15, title: s.pace15, onTap: () => Navigator.pop(c, 15)),
            Text(s.changeAnytime, style: Theme.of(c).textTheme.bodySmall),
          ]),
        ),
      ),
    );
    if (v == null || v == pl.sleepIncrement) return;
    await app.savePlan(Plan.fromJson(pl.toJson())..sleepIncrement = v);
  }
}

class _MovePlan extends StatelessWidget {
  final AppState app;
  const _MovePlan({required this.app});

  @override
  Widget build(BuildContext context) {
    final p = app.profile!, pl = app.plan!;
    final tt = Theme.of(context).textTheme;
    final mt = movementTarget(pl);
    // Already in the healthy range (design 20b): the user's choice from screen 10b, the others as chips; never a
    // "+10 a week up to 150" line and never a goal under the current level (Chi, thread 0004 fix 5).
    if (pl.movementBaseWeekly >= kMoveGuideline) {
      final usual = pl.movementBaseWeekly;
      final choice = pl.moveChoice ?? (pl.movementGoal == kMoveUpper ? 'to300' : 'keep');
      final options = usual > kMoveUpper ? const ['keep'] : const ['keep', 'to300', 'strength'];
      Future<void> choose(String c) => app.savePlan(Plan.fromJson(pl.toJson())
        ..moveChoice = c
        ..movementGoal = c == 'to300' ? kMoveUpper : kMoveGuideline);
      return BBCard(
        key: const Key('movePlan'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(BBIcons.walk, color: BBColors.data, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(s.domainLabel(Domain.movement), style: tt.titleMedium)),
            WhyButton(title: s.domainLabel(Domain.movement), source: '$kHigherGoalSource\n\n$kMoveLevelSource'),
          ]),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Text(s.healthyRangeLine(usual), style: heading(22))),
            Flexible(child: Text(s.healthyRange, style: tt.bodySmall, textAlign: TextAlign.end)),
          ]),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: s.moveChoiceLabel(choice), style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: ' · ${s.yourChoice}', style: tt.bodySmall),
            ]),
            key: const Key('moveChoice'),
          ),
          if (choice == 'to300') Text(s.moveLadderText(mt.perSession, mt.sessions, false, goal: kMoveUpper), style: tt.bodySmall),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in options.where((c) => c != choice))
              PillChip(key: Key('moveChoice_$c'), label: s.moveChoiceLabel(c), selected: false, onTap: () => choose(c)),
          ]),
          if (pl.workCredit > 0)
            Row(children: [
              Expanded(child: Text(s.workCreditLine(pl.workCredit), style: tt.bodySmall)),
              WhyButton(title: s.workCreditLine(pl.workCredit), source: kWorkCreditSource),
            ]),
        ]),
      );
    }
    return BBCard(
      key: const Key('movePlan'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(BBIcons.walk, color: BBColors.data, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(s.domainLabel(Domain.movement), style: tt.titleMedium)),
          Flexible(flex: 2, child: BBTag(s.bbSuggestion)),
          WhyButton(
            title: s.domainLabel(Domain.movement),
            source: '$kMoveStepSource\n\n$kMoveLevelSource',
            target: s.targetMove(mt.weeklyMinutes),
          ),
        ]),
        const SizedBox(height: 4),
        Text(s.movePace(mt.weeklyMinutes), style: heading(20)),
        Text(s.moveLadderText(mt.perSession, mt.sessions, pl.movementBaseWeekly <= 0, goal: pl.movementGoal), style: tt.bodySmall),
        if (pl.workCredit > 0)
          Row(children: [
            Expanded(child: Text(s.workCreditLine(pl.workCredit), style: tt.bodySmall)),
            WhyButton(title: s.workCreditLine(pl.workCredit), source: kWorkCreditSource),
          ]),
        if (p.goalIds.contains('weight')) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(s.weeklyGoal, style: tt.titleSmall)),
            WhyButton(title: s.obGoalQ, source: kHigherGoalSource),
          ]),
          Wrap(spacing: 8, children: [
            for (final g in const [kMoveGuideline, kMoveUpper])
              PillChip(
                label: g == kMoveGuideline ? s.goal150 : s.goal300,
                selected: pl.movementGoal == g,
                onTap: () => app.savePlan(Plan.fromJson(pl.toJson())..movementGoal = g),
              ),
          ]),
        ],
      ]),
    );
  }
}

/// An area not chosen yet: "Not started yet. Add when you're ready." (the user decides).
class _NotStarted extends StatelessWidget {
  final AppState app;
  final Domain domain;
  const _NotStarted({required this.app, required this.domain});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final move = domain == Domain.movement;
    return BBCard(
      key: Key(move ? 'moveNotStarted' : 'sleepNotStarted'),
      child: Row(children: [
        Icon(move ? BBIcons.walk : BBIcons.sleep, color: BBColors.data, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.domainLabel(domain), style: tt.titleSmall),
            Text(move ? s.moveNotStarted : s.sleepNotStarted, style: tt.bodySmall),
          ]),
        ),
        TextButton(key: Key(move ? 'addMove' : 'addSleep'), onPressed: () => _add(context), child: Text(s.add)),
      ]),
    );
  }

  Future<void> _add(BuildContext context) async {
    final pl = app.plan!;
    final move = domain == Domain.movement;
    final mt = movementTarget(pl);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(move ? s.addMoveTitle : s.addSleepTitle, style: Theme.of(c).textTheme.titleLarge)),
              Flexible(flex: 2, child: BBTag(s.bbSuggestion)),
              WhyButton(
                title: move ? s.addMoveTitle : s.addSleepTitle,
                source: move ? '$kMoveStepSource\n\n$kMoveLevelSource' : '$kSleepStepSource\n\n$kSleepLevelSource',
              ),
            ]),
            const SizedBox(height: 8),
            Text(move ? s.addMoveBody(mt.perSession, mt.sessions) : s.addSleepBody(pl.sleepTargetMinutes)),
            const SizedBox(height: 16),
            PrimaryButton(label: move ? s.addMoveConfirm : s.addSleepTitle, onPressed: () => Navigator.pop(c, true)),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    await app.savePlan(Plan.fromJson(pl.toJson())..domains = {...pl.domains, domain});
  }
}
