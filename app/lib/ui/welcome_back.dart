// Welcome back (Chi's screen 14, rules C5): after 2 days without the habit. The
// user's own reason word for word, an optional "what got in the way", and three
// ways to restart small. No blame, nothing is reset.
import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../rules/plan.dart';
import 'common.dart';
import 'icons.dart';
import 'today.dart';

enum _Restart { smaller, swap, move }

class WelcomeBackView extends StatefulWidget {
  const WelcomeBackView({super.key});

  @override
  State<WelcomeBackView> createState() => _WelcomeBackViewState();
}

class _WelcomeBackViewState extends State<WelcomeBackView> {
  final Set<String> _barriers = {};
  _Restart _choice = _Restart.smaller;
  bool _busy = false;

  Future<void> _restart() async {
    final app = AppScope.of(context);
    setState(() => _busy = true);
    try {
      if (_barriers.isNotEmpty) {
        await app.saveReview({
          ...app.review,
          'barriers': [...?(app.review['barriers'] as List?), ..._barriers],
        });
      }
      if (!mounted) return;
      final ctx = context;
      final ok = switch (_choice) {
        _Restart.smaller => await app
            .savePlan(stepDown(app.plan!, app.nowMinute, app.profile!.selfSleepMinutes))
            .then((_) => true),
        // ignore: use_build_context_synchronously
        _Restart.swap => await swapToBackup(ctx, app, dismiss: false),
        // ignore: use_build_context_synchronously
        _Restart.move => await showMoveReminderSheet(ctx, app, dismiss: false),
      };
      if (ok) await app.dismissNudge();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = app.profile!, pl = app.plan!;
    final tt = Theme.of(context).textTheme;
    final backup = pl.backupHabitIds.isEmpty ? null : pl.backupHabitIds.first;
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // The title takes all the room left of "?" (an earlier Flexible + Spacer gave it
            // only half, so "Welcome back, Ravi" wrapped on a 411 dp phone). The sprout is
            // part of the text, joined to the last word (U+2060), so a long name wraps
            // with the sprout still next to it.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${s.welcomeBackName(app.displayName)}⁠'),
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(BBIcons.sprout, key: Key('welcomeBackSprout'), color: BBColors.accent, size: 22),
                      ),
                    ),
                  ]),
                  key: const Key('welcomeBack'),
                  style: tt.headlineSmall,
                ),
              ),
            ),
            WhyButton(title: s.welcomeBackTitle, source: kLapseSource),
          ]),
          const SizedBox(height: 4),
          Text(s.bloomedStillHere(app.daysBloomed), style: tt.bodyMedium?.copyWith(color: BBColors.muted)),
          const SizedBox(height: 12),
          if (p.motivation.isNotEmpty)
            BBCard(
              key: const Key('yourReason'),
              color: BBColors.accentLight,
              border: const Color(0xFFF2DFAE),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CapsLabel(s.yourReason, color: BBColors.accent),
                const SizedBox(height: 4),
                Text('"${p.motivation}"', style: heading(19, weight: FontWeight.w500)),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '${s.whatGotInWay} ', style: tt.titleSmall),
              TextSpan(text: s.optional, style: tt.bodySmall),
            ])),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final b in s.barriersChi)
              PillChip(
                label: b,
                selected: _barriers.contains(b),
                onTap: () => setState(() => _barriers.contains(b) ? _barriers.remove(b) : _barriers.add(b)),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 6),
            child: Text(s.restartSmallTitle, style: tt.titleSmall),
          ),
          RadioCard(
            key: const Key('restart_smaller'),
            selected: _choice == _Restart.smaller,
            title: s.shrink,
            subtitle: s.makeSmallerSub,
            onTap: () => setState(() => _choice = _Restart.smaller),
          ),
          if (backup != null)
            RadioCard(
              key: const Key('restart_swap'),
              selected: _choice == _Restart.swap,
              title: s.swapShort,
              subtitle: s.swapSub(s.habit(backup)),
              onTap: () => setState(() => _choice = _Restart.swap),
            ),
          RadioCard(
            key: const Key('restart_move'),
            selected: _choice == _Restart.move,
            title: s.moveTime,
            subtitle: s.moveTimeSub,
            onTap: () => setState(() => _choice = _Restart.move),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: PrimaryButton(label: s.restartToday, onPressed: _busy ? null : _restart),
      ),
    ]);
  }
}
