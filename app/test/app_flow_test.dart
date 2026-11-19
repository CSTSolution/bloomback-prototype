// End to end without hardware: onboarding result -> pair FakeBand -> sync ->
// Today/Week numbers -> check-in -> FHIR -> delete.
import 'package:bloomback/analytics/fhir.dart';
import 'package:bloomback/app_state.dart';
import 'package:bloomback/data/models.dart';
import 'package:bloomback/data/store.dart';
import 'package:bloomback/rules/plan.dart';
import 'package:bloomback/rules/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Ravi with the demo band', () async {
    final now = DateTime(2026, 11, 13, 17, 0);
    final store = MemoryStore();
    final app = AppState(store, clock: () => now);
    await app.load();
    expect(app.onboarded, isFalse);

    final nowMin = now.toUtc().millisecondsSinceEpoch ~/ 60000;
    final p = Profile(
      goalIds: ['tiredOnWaking', 'shiftSleep'],
      mainGoalId: 'tiredOnWaking',
      motivation: 'So I still have energy to video-call my kids',
      activity: WorkActivity.standingLight,
      shift: ShiftType.nightFixed,
      place: WorkPlace.indoor,
      selfSleepMinutes: 330,
      selfWalkMinutes: 60,
      startMinute: nowMin,
    );
    final pl = initialPlan(profile: p, domains: {Domain.sleep}, mainHabitId: 'homeToBed', nowMinute: nowMin);
    await app.finishOnboarding(p, pl, suggestedReminderSettings(p.shift, app.settings));
    expect(app.onboarded, isTrue);
    expect(app.settings.useFakeBand, isTrue);

    final found = await app.link.scan().first;
    expect(found.single.name, startsWith('BloomBack-'));
    await app.pair(found.single);
    expect(app.bandMessage, contains('Synced'));
    expect(app.minutes.length, 14 * 1440);
    expect(await store.syncCursor(), nowMin - 1);
    expect(app.lastSleepDay, isNotNull);
    expect(app.lastSleepDay!.sleep.sleepMinutes, inInclusiveRange(240, 480));
    expect(app.weeks.length, greaterThanOrEqualTo(2));
    expect(app.weekModerate, greaterThan(0));
    // Band history from before onboarding is not a lapse: no "welcome back" on day 1.
    expect(app.nudge, isNot(Nudge.welcomeBack));

    // A second sync right away brings nothing new and keeps the cursor.
    await app.sync();
    expect(app.minutes.length, 14 * 1440);

    await app.checkIn(CheckinStatus.partial);
    expect(app.todayCheckin, CheckinStatus.partial);

    // Switching to a real band clears the demo's band data, keeps own check-ins.
    await app.saveSettings(Settings.fromJson(app.settings.toJson())..useFakeBand = false);
    expect(app.minutes, isEmpty);
    expect(await store.syncCursor(), 0);
    expect(app.checkins.every((c) => c.source == DataSource.selfReport), isTrue);
    expect(app.todayCheckin, CheckinStatus.partial);
    await app.saveSettings(Settings.fromJson(app.settings.toJson())..useFakeBand = true);
    await app.pair((await app.link.scan().first).single);
    expect(app.minutes.length, 14 * 1440);

    final bundle = buildFhirBundle(
        days: app.days, checkins: app.checkins, tzMinutes: app.tz, bandName: 'BloomBack-DEMO', profile: p);
    expect((bundle['entry'] as List).length, greaterThan(14 * 2));

    await app.deleteOnBand();
    await app.deleteAllOnPhone();
    expect(app.onboarded, isFalse);
    expect(store.minutes, isEmpty);
  });
}
