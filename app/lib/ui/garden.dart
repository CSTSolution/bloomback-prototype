// Garden (Chi's screen 21, Q5): a flower for each day the step was done, even
// partly. Grey days never count against you, nothing wilts, nothing resets. "Days
// bloomed" is shown quietly, never as a big number; no streak, no ranking.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import 'common.dart';
import 'four_weeks.dart';
import 'icons.dart';
import 'week.dart';

/// Soft flower colours (no red).
const _petals = [Color(0xFFF2C14E), Color(0xFF8DB8E8), Color(0xFFB9A0E0), Color(0xFF7FC79A), Color(0xFFF0A868)];

DateTime _dateOfDay(int day) => DateTime.utc(1970, 1, 1).add(Duration(days: day));

bool _bloomed(CheckinStatus? st) => st == CheckinStatus.done || st == CheckinStatus.partial;

class _Flower extends StatelessWidget {
  final int day;
  final CheckinStatus? status;
  final double size;
  final bool future;
  /// Before the plan started: blank (no grey circle), unless a check-in bloomed.
  final bool beforeStart;
  const _Flower({required this.day, required this.status, this.size = 36, this.future = false, this.beforeStart = false});

  @override
  Widget build(BuildContext context) {
    final bloom = _bloomed(status);
    if (beforeStart && !bloom) {
      return SizedBox(key: Key('gardenBlank_$day'), width: size, height: size);
    }
    return Semantics(
      label: s.dayDoneLabel(_dateOfDay(day).day, status),
      child: Container(
        key: Key(bloom ? 'gardenBloom_$day' : (future ? 'gardenFuture_$day' : 'gardenGrey_$day')),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bloom ? BBColors.primaryLight : (future ? Colors.transparent : BBColors.grey),
          border: future ? Border.all(color: BBColors.line) : null,
        ),
        child: bloom ? Icon(BBIcons.flower, size: size * 0.62, color: _petals[day % _petals.length]) : null,
      ),
    );
  }
}

/// The small garden on Today: the last 10 days and "N days bloomed".
class GardenStrip extends StatelessWidget {
  final AppState app;
  final VoidCallback onTap;
  const GardenStrip({super.key, required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return BBCard(
      key: const Key('gardenStrip'),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: CapsLabel(s.yourGarden)),
          const Icon(BBIcons.sprout, size: 16, color: BBColors.accent),
          const SizedBox(width: 4),
          Text(s.daysBloomedN(app.daysBloomed), style: tt.bodySmall?.copyWith(color: BBColors.accent, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var d = app.today - 9; d <= app.today; d++)
            _Flower(day: d, status: app.byDay[d], size: 26, beforeStart: d < app.planDay),
        ]),
        const SizedBox(height: 8),
        Text(s.gardenNote, style: tt.bodySmall),
      ]),
    );
  }
}

class GardenScreen extends StatelessWidget {
  const GardenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    final now = app.clock();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstDay = app.today - (now.day - 1);
    final lastDay = firstDay + daysInMonth - 1;
    // Start at the week of the first day shown (the plan's start or the 1st), Monday first, so days before the
    // plan leave no blank block (Chi, thread 0004 fix 15). Local day 0 (1 Jan 1970) was a Thursday.
    final startDay = math.max(firstDay, math.min(app.planDay, lastDay));
    final gridStart = startDay - (startDay + 3) % 7;
    final weeks = app.weeks;
    final bandFirst = weeks.isEmpty ? null : weeks.first.avgSleepMinutes;
    // "Now" = the last 7 days (band estimate), only once week 1 is behind us.
    final bandLast = app.today - app.firstDay >= 7 ? app.sleepLast7 : null;
    final p = app.profile!;
    final w1 = app.daysDoneIn(app.firstDay);
    final wNow = app.daysDoneIn(app.today - 6); // the last 7 days
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(label, style: tt.bodyLarge)),
            Text(value, style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        );
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      Text(s.gardenTitle, style: tt.headlineSmall),
      const SizedBox(height: 4),
      Text(s.gardenBody, style: tt.bodyMedium?.copyWith(color: BBColors.muted)),
      const SizedBox(height: 8),
      BBCard(
        key: const Key('monthGrid'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: CapsLabel(s.monthName(now.month))),
            const Icon(BBIcons.sprout, size: 16, color: BBColors.accent),
            const SizedBox(width: 4),
            Text(s.daysBloomedN(app.daysBloomed), style: tt.bodySmall?.copyWith(color: BBColors.accent, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 4,
            children: [
              for (var d = gridStart; d <= lastDay; d++)
                if (d < firstDay)
                  const SizedBox()
                else
                  Center(
                    child: _Flower(
                      day: d,
                      status: app.byDay[d],
                      future: d > app.today,
                      beforeStart: d < app.planDay,
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 8),
          Text(s.greyNote, style: tt.bodySmall),
        ]),
      ),
      BBCard(
        key: const Key('week1Now'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CapsLabel(s.week1Now),
          const SizedBox(height: 6),
          if (bandFirst != null)
            row(s.sleep24, bandLast == null ? s.hoursDecimal(bandFirst) : '${s.hoursDecimal(bandFirst)} → ${s.hoursDecimal(bandLast)}')
          else
            row(s.sleep24, '${s.hoursDecimal(p.selfSleepMinutes)} (${s.sleepYouToldUs})'),
          row(s.daysDone, s.daysDoneWeek(w1, wNow)),
          row(s.cameBack, s.times(app.comeBackCount)),
          const SizedBox(height: 4),
          Text(s.sameSource, style: tt.bodySmall),
          if (bandFirst != null) Text(s.bandSleepNote, style: tt.bodySmall),
        ]),
      ),
      if (app.reviewDue)
        BBCard(
          onTap: () => openFourWeeks(context),
          child: Row(children: [
            Expanded(child: Text(s.fourWeeksHeader, style: tt.titleSmall)),
            const Icon(Icons.chevron_right),
          ]),
        ),
      BBCard(
        key: const Key('weekByWeek'),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => BBPage(
            title: s.weekByWeek,
            onBack: () => Navigator.of(context).pop(),
            body: const WeekScreen(),
          ),
        )),
        child: Row(children: [
          Expanded(child: Text(s.weekByWeek, style: tt.titleSmall)),
          const Icon(Icons.chevron_right),
        ]),
      ),
    ]);
  }
}
