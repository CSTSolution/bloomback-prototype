// "Your day" (Chi, thread 0008, design docs/design/your-day-shift-sleep-2026-11-18.png):
// 1 · Today: a timeline of today around the shift; past rows ticked, the next one highlighted; every row's "?" holds
//     NIOSH's (or AASM's) own words. The small step keeps its own card and check-in below.
// 2 · My shifts this week: 7 days, tap to cycle Night / Day / Off; shift times; what is coming up.
// 3 · Sleep from your band: the last main sleep (estimate) and 7 days on a 24-hour line with the planned window.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/strings.dart';
import '../rules/shift_week.dart';
import 'common.dart';

String _hm(int minuteOfDay) => hhmm(((minuteOfDay % 1440) + 1440) % 1440);

/// The local minute of day of a UTC unix minute.
int _localMod(int utcMinute) {
  final d = DateTime.fromMillisecondsSinceEpoch(utcMinute * 60000);
  return d.hour * 60 + d.minute;
}

/// 1 · The timeline on Today.
class YourDayCard extends StatelessWidget {
  final AppState app;
  const YourDayCard({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final p = app.profile!, st = app.settings;
    final now = app.clock();
    var nowMin = now.hour * 60 + now.minute;
    var day = now;
    // Before the end of last night's shift, the user is still in yesterday's plan.
    final yesterday = now.subtract(const Duration(days: 1));
    if (nowMin < st.nightShiftEnd && shiftOn(st, p, yesterday) == DayShift.night) {
      day = yesterday;
      nowMin += 1440;
    }
    final yd = buildYourDay(p: p, st: st, now: day, habitId: app.mainHabit?.id ?? '');
    final rows = yd.rows;
    final nextIdx = rows.indexWhere((r) => !rowPassed(r, rows, nowMin));
    final tt = Theme.of(context).textTheme;
    return Column(key: const Key('yourDay'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Row(children: [
          Expanded(child: CapsLabel(s.yourDayLabel(yd.today.name))),
          TextButton(
            key: const Key('openMyShifts'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MyShiftsScreen())),
            child: Text(s.myShifts),
          ),
        ]),
      ),
      for (var i = 0; i < rows.length; i++) _RowView(app: app, row: rows[i], passed: i < nextIdx || nextIdx < 0, next: i == nextIdx),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Text(
          weekOf(st, p).contains(DayShift.night) ? s.yourDayFooterNight : s.yourDayFooterDay,
          textAlign: TextAlign.center,
          style: tt.bodySmall,
        ),
      ),
    ]);
  }
}

class _RowView extends StatelessWidget {
  final AppState app;
  final DayRow row;
  final bool passed;
  final bool next;
  const _RowView({required this.app, required this.row, required this.passed, required this.next});

  IconData get _icon => switch (row.kind) {
        DayRowKind.mainSleep || DayRowKind.bedtime => Icons.bedtime_outlined,
        DayRowKind.nap => Icons.snooze_outlined,
        DayRowKind.shiftStart => Icons.work_outline,
        DayRowKind.coffee => Icons.coffee_outlined,
        DayRowKind.homeToBed => Icons.hotel_outlined,
        DayRowKind.wake => Icons.wb_sunny_outlined,
        DayRowKind.step => Icons.directions_walk,
        DayRowKind.windDown => Icons.nights_stay_outlined,
        DayRowKind.dayOff => Icons.beach_access_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final kind = row.kind.name;
    final title = s.dayRowTitle(kind, until: row.until == null ? null : _hm(row.until!), habit: s.habit(app.mainHabit?.id ?? ''));
    final line = switch (row.kind) {
      DayRowKind.mainSleep => '',
      DayRowKind.step => s.dayRowLine('', isStep: true).trim(),
      _ => s.dayRowLine(kind, isStep: row.isStep),
    };
    // the band's estimate of today's main sleep
    String? band;
    if (row.kind == DayRowKind.mainSleep) {
      final d = app.days.where((x) => x.day == app.today && x.sleep.found).firstOrNull;
      if (d != null) band = s.bandLine(_hm(_localMod(d.sleep.startMinute)), _hm(_localMod(d.sleep.endMinute)), d.sleep.sleepMinutes);
    }
    final time = row.kind == DayRowKind.dayOff ? '' : (row.at == null ? s.late : _hm(row.at!));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 50,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(time, style: tt.bodyMedium?.copyWith(color: BBColors.muted, fontWeight: FontWeight.w600)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10, right: 8),
          child: _Dot(passed: passed, next: next),
        ),
        Expanded(
          child: BBCard(
            key: Key('dayRow_$kind'),
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            border: next ? BBColors.primary : BBColors.line,
            borderWidth: next ? 1.8 : 1,
            onTap: row.kind == DayRowKind.mainSleep
                ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BandSleepScreen()))
                : null,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 2), child: Icon(_icon, size: 18, color: BBColors.primary)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: tt.titleSmall),
                  if (band != null) ...[
                    Text(band, key: const Key('bandLine'), style: tt.bodySmall),
                    const SizedBox(height: 2),
                    BBTag(s.estimate),
                  ],
                  if (line.isNotEmpty) Text(line, style: tt.bodySmall),
                ]),
              ),
              if (row.source.isNotEmpty) WhyButton(title: title, source: row.source),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool passed;
  final bool next;
  const _Dot({required this.passed, required this.next});

  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: passed ? BBColors.primary : Colors.white,
          border: Border.all(color: passed || next ? BBColors.primary : BBColors.line, width: next ? 2.5 : 1.5),
        ),
        child: passed ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
      );
}

/// 2 · My shifts this week.
class MyShiftsScreen extends StatelessWidget {
  /// The tab it was opened from, shown selected in the bottom bar.
  final int fromTab;
  const MyShiftsScreen({super.key, this.fromTab = 0});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = app.profile!, st = app.settings;
    final tt = Theme.of(context).textTheme;
    final now = app.clock();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: weekdayIndex(now)));
    final week = weekOf(st, p);
    Future<void> cycle(int i) async {
      final next = switch (week[i]) { DayShift.night => DayShift.day, DayShift.day => DayShift.off, DayShift.off => DayShift.night };
      final w = [...week]..[i] = next;
      st.shiftWeek = [for (final x in w) x.name];
      await app.saveSettings(st);
    }

    final coming = comingUp(st, p, now);
    String dayList(List<DateTime> ds) {
      final names = [for (final d in ds) s.weekdayLong(weekdayIndex(d))];
      return names.length <= 1 ? names.join() : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    }

    return BBPage(
      title: s.myShiftsTitle,
      onBack: () => Navigator.of(context).pop(),
      navBar: BBTabBar(selected: fromTab),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
        Text(s.myShiftsBody, style: tt.bodyMedium),
        const SizedBox(height: 8),
        BBCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _DayChip(
                      key: Key('shiftDay_$i'),
                      label: s.weekdayShort(i),
                      date: monday.add(Duration(days: i)).day,
                      shift: week[i],
                      today: i == weekdayIndex(now),
                      onTap: () => cycle(i),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Text(
                  s.shiftTimes(hhmm(st.nightShiftStart), hhmm(st.nightShiftEnd), hhmm(st.dayShiftStart), hhmm(st.dayShiftEnd)),
                  style: tt.bodySmall?.copyWith(color: BBColors.ink),
                ),
              ),
              TextButton(key: const Key('editShiftTimes'), onPressed: () => _editTimes(context, app), child: Text(s.editTimes)),
            ]),
          ]),
        ),
        const SizedBox(height: 8),
        CapsLabel(s.comingUp),
        const SizedBox(height: 4),
        if (coming.isEmpty) Text(s.nothingComingUp, style: tt.bodySmall),
        for (final c in coming)
          if (c.kind == ComingKind.daysOffAfterNights)
            BBCard(
              key: const Key('comingDaysOff'),
              color: BBColors.accentLight,
              border: const Color(0xFFF2DFAE),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.daysOffTitle(dayList(c.days)), style: tt.titleSmall),
                    const SizedBox(height: 2),
                    Text(s.dayRowLine('dayOff'), style: tt.bodyMedium),
                    const SizedBox(height: 4),
                    Text(s.daysOffSourceShort, style: tt.bodySmall?.copyWith(color: BBColors.accent)),
                  ]),
                ),
                WhyButton(title: s.daysOffTitle(dayList(c.days)), source: kNioshDaysOff),
              ]),
            )
          else
            BBCard(
              key: const Key('comingNewShift'),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.newShiftTitle(s.weekdayLong(weekdayIndex(c.days.first)), c.to!.name), style: tt.titleSmall),
                    const SizedBox(height: 2),
                    Text(s.newShiftBody, style: tt.bodyMedium),
                    const SizedBox(height: 4),
                    Text(s.bbSuggestion, style: tt.bodySmall),
                  ]),
                ),
                WhyButton(title: s.newShiftBody, source: kNewShiftSource),
              ]),
            ),
      ]),
    );
  }

  Future<void> _editTimes(BuildContext context, AppState app) async {
    final st = app.settings;
    var ns = st.nightShiftStart, ne = st.nightShiftEnd, ds = st.dayShiftStart, de = st.dayShiftEnd;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) {
          Widget row(String label, int v, ValueChanged<int> on, String key) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(label),
                trailing: TextButton(
                  key: Key(key),
                  onPressed: () async {
                    final t = await pickTime(c, v);
                    if (t != null) set(() => on(t));
                  },
                  child: Text(hhmm(v)),
                ),
              );
          return AlertDialog(
            title: Text(s.editTimes),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.nightShift, style: Theme.of(c).textTheme.titleSmall),
              row(s.starts, ns, (x) => ns = x, 'nightStart'),
              row(s.ends, ne, (x) => ne = x, 'nightEnd'),
              Text(s.dayShift, style: Theme.of(c).textTheme.titleSmall),
              row(s.starts, ds, (x) => ds = x, 'dayStart'),
              row(s.ends, de, (x) => de = x, 'dayEnd'),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
              FilledButton(key: const Key('saveShiftTimes'), onPressed: () => Navigator.pop(c, true), child: Text(s.save)),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    st
      ..nightShiftStart = ns
      ..nightShiftEnd = ne
      ..dayShiftStart = ds
      ..dayShiftEnd = de;
    await app.saveSettings(st);
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final int date;
  final DayShift shift;
  final bool today;
  final VoidCallback onTap;
  const _DayChip({super.key, required this.label, required this.date, required this.shift, required this.today, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (shift) {
      DayShift.night => (const Color(0xFF34478F), Colors.white),
      DayShift.day => (const Color(0xFFF7D36B), BBColors.ink),
      DayShift.off => (BBColors.grey, BBColors.muted),
    };
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 12, color: today ? BBColors.primary : BBColors.muted, fontWeight: today ? FontWeight.w700 : FontWeight.w500)),
      const SizedBox(height: 4),
      Semantics(
        button: true,
        label: '$label $date: ${s.weekShiftChip(shift.name)}',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: today ? Border.all(color: BBColors.primary, width: 2.5) : null,
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$date', style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 15)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(s.weekShiftChip(shift.name), style: TextStyle(color: fg, fontSize: 11)),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

/// 3 · Sleep from your band.
class BandSleepScreen extends StatelessWidget {
  final int fromTab;
  const BandSleepScreen({super.key, this.fromTab = 0});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = app.profile!, st = app.settings;
    final tt = Theme.of(context).textTheme;
    final now = app.clock();
    final today = DateTime(now.year, now.month, now.day);
    final nights = [
      for (var i = 6; i >= 0; i--)
        (
          date: today.subtract(Duration(days: i)),
          summary: app.days.where((d) => d.day == app.today - i).firstOrNull,
        ),
    ];
    final last = app.days.where((d) => d.sleep.found).lastOrNull;
    final work = (p.selfSleepStart ?? 23 * 60, p.selfWakeTime ?? 7 * 60);
    final off = (p.selfOffSleepStart ?? work.$1, p.selfOffWakeTime ?? work.$2);
    // the planned window for the sleep that ends on [d]: after a night at work, the work-day window
    (int, int) planned(DateTime d) => shiftOn(st, p, d.subtract(const Duration(days: 1))) == DayShift.night ? work : off;
    bool afterNight(DateTime d) => shiftOn(st, p, d.subtract(const Duration(days: 1))) == DayShift.night;
    // averages for one sentence: after a night (or a work day) vs days off
    final workNights = <(int, int)>[], offNights = <(int, int)>[];
    for (final n in nights) {
      final sl = n.summary?.sleep;
      if (sl == null || !sl.found) continue;
      final start = _localMod(sl.startMinute);
      final shift = shiftOn(st, p, n.date.subtract(const Duration(days: 1)));
      (shift == DayShift.off ? offNights : workNights).add((sl.sleepMinutes, start));
    }
    int avg(List<(int, int)> xs, int Function((int, int)) f) => xs.isEmpty ? 0 : xs.map(f).reduce((a, b) => a + b) ~/ xs.length;
    // start times compared on a line from noon to noon, so 23:00 and 01:00 are 2 h apart
    int startKey((int, int) x) => (x.$2 + 720) % 1440;
    final hoursEarlier = workNights.isEmpty || offNights.isEmpty
        ? 0
        : ((avg(workNights, startKey) - avg(offNights, startKey)) / 60).round();
    final target = app.plan?.sleepTargetMinutes ?? 420;
    final nightWorker = weekOf(st, p).contains(DayShift.night);
    return BBPage(
      title: s.bandSleepTitle,
      onBack: () => Navigator.of(context).pop(),
      navBar: BBTabBar(selected: fromTab),
      trailing: st.bandId != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(border: Border.all(color: BBColors.primaryBorder), borderRadius: BorderRadius.circular(16)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.watch_outlined, size: 14, color: BBColors.primary),
                const SizedBox(width: 4),
                Text(s.connected2, style: const TextStyle(color: BBColors.primary, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ]),
            )
          : null,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
        BBCard(
          key: const Key('lastMainSleep'),
          child: last == null
              ? Text(s.noBandNights, style: tt.bodyMedium)
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: CapsLabel(s.lastMainSleepWhen(last.day == app.today ? s.todayWord : s.ago(now.difference(DateTime.fromMillisecondsSinceEpoch(last.sleep.endMinute * 60000)))))),
                    BBTag(s.estimate),
                    WhyButton(title: s.bandSleepTitle, source: kPlanSleepSource),
                  ]),
                  const SizedBox(height: 4),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(child: Text(s.hours(last.sleep.sleepMinutes), style: heading(30))),
                    Text('${_hm(_localMod(last.sleep.startMinute))} – ${_hm(_localMod(last.sleep.endMinute))}', style: tt.bodyLarge),
                  ]),
                  const SizedBox(height: 6),
                  Text(s.planThisWeek(_hm(planned(today).$1), _hm(planned(today).$2), target), style: tt.bodySmall?.copyWith(color: BBColors.ink)),
                ]),
        ),
        BBCard(
          key: const Key('sleep24h'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: CapsLabel(s.last7Title)),
              Text('0 · 6 · 12 · 18 · 24 h', style: tt.bodySmall),
            ]),
            const SizedBox(height: 8),
            for (final n in nights)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  SizedBox(width: 44, child: Text('${s.weekdayShort(weekdayIndex(n.date))} ${n.date.day}', style: tt.bodySmall)),
                  Expanded(
                    child: SizedBox(
                      height: 18,
                      child: CustomPaint(
                        painter: _NightBar(
                          start: n.summary != null && n.summary!.sleep.found ? _localMod(n.summary!.sleep.startMinute) : null,
                          end: n.summary != null && n.summary!.sleep.found ? _localMod(n.summary!.sleep.endMinute) : null,
                          planStart: planned(n.date).$1,
                          planEnd: planned(n.date).$2,
                          afterWork: afterNight(n.date) || shiftOn(st, p, n.date.subtract(const Duration(days: 1))) == DayShift.day,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(
                      n.summary != null && n.summary!.sleep.found ? s.hours(n.summary!.sleep.sleepMinutes) : '–',
                      textAlign: TextAlign.right,
                      style: tt.bodySmall,
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 4, children: [
              _legend(const Color(0xFF3E7CB1), nightWorker ? s.afterNight : s.workDayLegend),
              _legend(const Color(0xFF9CC2E5), s.dayOffLegend),
              _legend(null, s.plannedLegend),
            ]),
          ]),
        ),
        if (workNights.isNotEmpty && offNights.isNotEmpty)
          BBCard(
            key: const Key('bandCompare'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.compareWorkOff(avg(workNights, (x) => x.$1), avg(offNights, (x) => x.$1), hoursEarlier), style: tt.bodyLarge),
              const SizedBox(height: 4),
              Text(s.bandCompareNote, style: tt.bodySmall),
            ]),
          )
        else
          Padding(padding: const EdgeInsets.all(8), child: Text(s.bandCompareNote, style: tt.bodySmall)),
      ]),
    );
  }

  Widget _legend(Color? c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 12,
          height: 10,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
            border: c == null ? Border.all(color: BBColors.accent, width: 1.4) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: BBColors.ink)),
      ]);
}

/// One day on a 0-24 h track: the band's sleep (solid) and the planned window (dashed frame).
class _NightBar extends CustomPainter {
  final int? start, end;
  final int planStart, planEnd;
  final bool afterWork;
  _NightBar({required this.start, required this.end, required this.planStart, required this.planEnd, required this.afterWork});

  /// [a, b) in minutes of the day, wrapping past midnight, as up to two pieces on the track.
  List<(double, double)> _pieces(int a, int b) =>
      b > a ? [(a / 1440, b / 1440)] : [(a / 1440, 1.0), (0.0, b / 1440)];

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, r), Paint()..color = BBColors.grey);
    if (start != null && end != null) {
      final paint = Paint()..color = afterWork ? const Color(0xFF3E7CB1) : const Color(0xFF9CC2E5);
      for (final (x0, x1) in _pieces(start!, end!)) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(x0 * size.width, 2, x1 * size.width, size.height - 2), r),
          paint,
        );
      }
    }
    final dash = Paint()
      ..color = BBColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final (x0, x1) in _pieces(planStart, planEnd)) {
      final rect = Rect.fromLTRB(x0 * size.width, 0.7, x1 * size.width, size.height - 0.7);
      final path = Path()..addRRect(RRect.fromRectAndRadius(rect, r));
      for (final m in path.computeMetrics()) {
        for (var d = 0.0; d < m.length; d += 6) {
          canvas.drawPath(m.extractPath(d, math.min(d + 3.5, m.length)), dash);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NightBar old) =>
      old.start != start || old.end != end || old.planStart != planStart || old.planEnd != planEnd || old.afterWork != afterWork;
}
