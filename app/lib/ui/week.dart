// Week 1 -> now (rules C6), neutral words, no scores. Band numbers are only
// compared with band numbers; self-report is shown on its own (B1).
import 'package:flutter/material.dart';

import '../analytics/daily.dart';
import '../l10n/strings.dart';
import 'common.dart';

class WeekScreen extends StatelessWidget {
  const WeekScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final weeks = app.weeks;
    final first = weeks.isEmpty ? null : weeks.first;
    final last = weeks.length > 1 ? weeks.last : null;
    final p = app.profile!;

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Text(s.weekIntro, style: Theme.of(context).textTheme.bodyMedium),
        ),
        if (first == null || app.minutes.isEmpty)
          SectionCard(children: [Text(s.noBandData)])
        else
          SectionCard(
            title: last == null ? s.weekLabel(0) : '${s.weekLabel(0)} → ${s.weekLabel(last.index)}',
            children: [
              _row(context, s.avgSleep, _h(first.avgSleepMinutes), last == null ? null : _h(last.avgSleepMinutes)),
              _row(context, s.brisk, s.minutes(first.moderateMinutes), last == null ? null : s.minutesSoFar(last.moderateMinutes, last.days)),
              _row(context, s.avgSteps, first.avgSteps == null ? '–' : s.count(first.avgSteps!),
                  last == null ? null : (last.avgSteps == null ? '–' : s.count(last.avgSteps!))),
              _row(context, s.onsetSpread, _h(first.onsetSpreadMinutes), last == null ? null : _h(last.onsetSpreadMinutes)),
              _row(context, s.habitDays, '${first.checkinsDoneOrPartial}', last == null ? null : '${last.checkinsDoneOrPartial}'),
              const SizedBox(height: 8),
              Text(s.bandSleepNote, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        for (final w in weeks.length > 2 ? weeks.sublist(1, weeks.length - 1) : const <WeekSummary>[])
          SectionCard(title: s.weekLabel(w.index), children: [
            _row(context, s.avgSleep, _h(w.avgSleepMinutes), null),
            _row(context, s.brisk, s.minutes(w.moderateMinutes), null),
          ]),
        SectionCard(title: s.youToldUs, children: [
          _row(context, s.avgSleep, s.hours(p.selfSleepMinutes), null),
          _row(context, s.brisk, s.perWeek(p.selfWalkMinutes), null),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(s.daysBloomed(app.daysBloomed)),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: app.days.isEmpty ? null : app.exportFhir,
            icon: const Icon(Icons.ios_share),
            label: Text(s.exportFhir),
          ),
        ),
      ],
    );
  }

  static String _h(int? minutes) => minutes == null ? '–' : s.hours(minutes);

  Widget _row(BuildContext context, String label, String a, String? b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(flex: 4, child: Text(label)),
          Expanded(flex: 3, child: Text(a, textAlign: TextAlign.right)),
          if (b != null) ...[
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, size: 16)),
            Expanded(flex: 3, child: Text(b, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ]),
      );
}
