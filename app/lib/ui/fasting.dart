// C4 Ramadan: BloomBack suggests the region's dates, the user confirms or picks
// other dates. Only "fasting mode on, from - to" is stored (never a religion).
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models.dart';
import '../rules/environment.dart';

Future<void> useSuggestedFasting(AppState app, RamadanDates r) =>
    app.saveFasting(FastingMode(dateKey(r.from), dateKey(r.to)));

Future<void> pickFastingDates(BuildContext context, AppState app) async {
  final now = DateTime.now();
  final sug = suggestedRamadan(now, app.profile?.city);
  final cur = app.fasting;
  final range = await showDateRangePicker(
    context: context,
    firstDate: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30)),
    lastDate: now.add(const Duration(days: 500)),
    initialDateRange: cur != null
        ? DateTimeRange(start: parseDateKey(cur.from)!, end: parseDateKey(cur.to)!)
        : (sug == null ? null : DateTimeRange(start: sug.from, end: sug.to)),
  );
  if (range != null) await app.saveFasting(FastingMode(dateKey(range.start), dateKey(range.end)));
}
