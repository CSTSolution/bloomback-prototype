// 4 weeks in (Chi's screen 15, rules C6): one self-rated change question (PGIC
// style), week 1 -> week 4 numbers compared only with yourself, then the user
// decides: keep, step up or change.
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/strings.dart';
import '../rules/goals.dart';
import '../rules/plan.dart';
import 'common.dart';
import 'onboarding.dart';

void openFourWeeks(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FourWeeksScreen()),
    );

/// Opens onboarding at the work page with the current answers (Plan "Change").
void openChangePlan(BuildContext context) => pushChangePlan(Navigator.of(context), AppScope.of(context));

void pushChangePlan(NavigatorState nav, AppState app) {
  nav.push(MaterialPageRoute<void>(
    builder: (c) => AppScope(
      state: app,
      child: OnboardingScreen(initial: app.profile, onDone: () => Navigator.of(c).pop()),
    ),
  ));
}

class FourWeeksScreen extends StatelessWidget {
  const FourWeeksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = app.profile!;
    final tt = Theme.of(context).textTheme;
    final key = app.reviewKey;
    final answer = app.review[key] as int?;
    final weeks = app.weeks;
    final w1 = weeks.isEmpty ? null : weeks.first;
    final w4 = weeks.length >= 4 ? weeks[3] : (weeks.length > 1 ? weeks.last : null);
    final sleepCard = const ['fallAsleep', 'wakeAtNight', 'wakeTooEarly'].contains(p.mainGoalId);
    final d1 = app.daysDoneIn(app.firstDay);
    final d4 = app.daysDoneIn(app.firstDay + (weeks.length >= 4 ? 21 : ((weeks.length - 1).clamp(0, 99)) * 7));
    final canStep = (app.plan!.domains.isNotEmpty) && (canStepUpMovement(app.plan!) || canStepUpSleep(app.plan!));
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(label, style: tt.bodyLarge)),
            Text(value, style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        );
    return BBPage(
      title: s.fourWeeksHeader,
      onBack: () => Navigator.of(context).pop(),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
        Row(children: [
          Expanded(child: Text(s.howGoing, style: tt.headlineSmall)),
          WhyButton(
            title: s.review4w,
            source: 'Self-rated change in the style of the Patient Global Impression of Change (PGIC). '
                'No multi-question scale. ${goalById(p.mainGoalId).source}',
          ),
        ]),
        const SizedBox(height: 4),
        Text(s.comparedWith(s.goal(p.mainGoalId)), style: tt.bodyMedium?.copyWith(color: BBColors.muted)),
        const SizedBox(height: 8),
        for (var i = 0; i < s.review4wAnswers.length; i++)
          RadioCard(
            key: Key('pgic_$i'),
            selected: answer == i,
            title: s.review4wAnswers[i],
            onTap: () => app.saveReview({...app.review, key: i}),
          ),
        if (answer != null && sleepCard && answer >= 2)
          // Rules B5: sleep-trouble cards "same" or "worse" after 4 weeks -> suggest a doctor.
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(s.reviewDoctor, style: tt.bodyMedium?.copyWith(color: BBColors.accent, fontWeight: FontWeight.w600)),
          ),
        BBCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CapsLabel(s.numbersW1W4),
            const SizedBox(height: 6),
            if (w1?.avgSleepMinutes != null)
              row(s.sleepPerNight,
                  '${s.hoursDecimal(w1!.avgSleepMinutes!)} → ${w4?.avgSleepMinutes == null ? '–' : s.hoursDecimal(w4!.avgSleepMinutes!)}')
            else
              row(s.sleepPerNight, '${s.hoursDecimal(p.selfSleepMinutes)} (${s.sleepYouToldUs})'),
            row(s.daysDone, s.daysDoneWeek(d1, d4)),
            const SizedBox(height: 4),
            Text(s.sameSource, style: tt.bodySmall),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Text(s.whatNext, style: tt.titleSmall),
        ),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('review_keep'),
              onPressed: () async {
                await app.saveReview({...app.review, '${key}_next': 'keep'});
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(s.keep),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              key: const Key('review_stepUp'),
              onPressed: canStep
                  ? () async {
                      // The user agreed here (C5: step up only if the user agrees).
                      await app.savePlan(stepUp(app.plan!, app.nowMinute));
                      await app.saveReview({...app.review, '${key}_next': 'stepUp'});
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  : null,
              child: Text(s.stepUpShort),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              key: const Key('review_change'),
              onPressed: () async {
                final nav = Navigator.of(context);
                await app.saveReview({...app.review, '${key}_next': 'change'});
                nav.pop();
                pushChangePlan(nav, app);
              },
              child: Text(s.change),
            ),
          ),
        ]),
      ]),
    );
  }
}
