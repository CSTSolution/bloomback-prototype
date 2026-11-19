// The account, Pro and the coach against a pretend server: sign in from More with an email code, redeem a code, ask
// the coach (answer with its source, free questions count down, the fourth opens Pro), report an answer, sign out,
// delete the account. Checks for an exception after every tap.
import 'package:bloomback/app_state.dart';
import 'package:bloomback/data/models.dart';
import 'package:bloomback/data/store.dart';
import 'package:bloomback/l10n/strings.dart';
import 'package:bloomback/main.dart';
import 'package:bloomback/rules/plan.dart';
import 'package:bloomback/rules/reminders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_server.dart';

Future<(AppState, FakeServer)> _ready(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final now = DateTime(2026, 11, 14, 17, 0);
  final server = FakeServer();
  final app = AppState(MemoryStore(), clock: () => now, account: server.account());
  final nowMin = now.toUtc().millisecondsSinceEpoch ~/ 60000;
  final p = Profile(
    goalIds: ['tiredOnWaking', 'shiftSleep'],
    mainGoalId: 'tiredOnWaking',
    motivation: '',
    activity: WorkActivity.standingLight,
    shift: ShiftType.nightFixed,
    place: WorkPlace.indoor,
    selfSleepMinutes: 330,
    selfWalkMinutes: 60,
    startMinute: nowMin - 3 * 1440,
    heightCm: 172,
    weightKg: 74,
    city: City.abuDhabi,
  );
  await tester.runAsync(() async {
    await app.load();
    await app.finishOnboarding(
      p,
      initialPlan(profile: p, domains: {Domain.sleep}, mainHabitId: 'homeToBed', backupHabitIds: ['blackout'], nowMinute: nowMin),
      suggestedReminderSettings(p.shift, app.settings),
    );
    await app.checkIn(CheckinStatus.done);
  });
  await tester.pumpWidget(BloomBackApp(state: app));
  await tester.pumpAndSettle();
  return (app, server);
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, 150, scrollable: find.byType(Scrollable).hitTestable().first);
  }
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pumpAndSettle();
}

Future<void> _signInFromMore(WidgetTester tester) async {
  await _tap(tester, find.text(s.tabMore));
  expect(find.text(s.accountRowOut), findsOneWidget);
  await _tap(tester, find.byKey(const Key('more_account')));
  await _tap(tester, find.byKey(const Key('signInEmail')));
  await _type(tester, 'emailField', 'ravi@example.com');
  await _tap(tester, find.byKey(const Key('emailNext')));
  await _type(tester, 'codeField', '123456');
  await _tap(tester, find.byKey(const Key('emailNext')));
}

void main() {
  testWidgets('More › Account: email code sign-in, redeem a code, sign out', (tester) async {
    final (app, server) = await _ready(tester);
    await _signInFromMore(tester);
    expect(app.account.signedIn, isTrue);
    expect(find.byKey(const Key('accountCard')), findsOneWidget);
    expect(find.text('ravi@example.com'), findsOneWidget);
    expect(find.text(s.proRowOff), findsOneWidget);
    expect(find.text(s.askLeftFree(3)), findsOneWidget);

    // a wrong code shows the server's words; the right one turns Pro on
    await _tap(tester, find.byKey(const Key('redeemRow')));
    await _type(tester, 'redeemField', 'BB-NOPE-NOPE');
    await _tap(tester, find.byKey(const Key('redeemSend')));
    expect(find.textContaining('That code is not known'), findsOneWidget);
    await _type(tester, 'redeemField', 'BB-TEST-CODE');
    await _tap(tester, find.byKey(const Key('redeemSend')));
    expect(find.text(s.redeemDone(30)), findsOneWidget);
    expect(find.text(s.proUntil(DateTime(2026, 12, 31))), findsOneWidget);
    expect(app.account.standing.pro, isTrue);

    await _tap(tester, find.byKey(const Key('signOutRow')));
    expect(app.account.signedIn, isFalse);
    expect(find.byKey(const Key('signInEmail')), findsOneWidget);
    expect(server.token, isNull);
  });

  testWidgets('Delete my account asks first, then deletes on the server and signs out', (tester) async {
    final (app, server) = await _ready(tester);
    await _signInFromMore(tester);
    await _tap(tester, find.byKey(const Key('deleteAccountRow')));
    expect(find.text(s.deleteAccountBody), findsOneWidget);
    await _tap(tester, find.text(s.cancel));
    expect(server.deleted, isFalse);
    await _tap(tester, find.byKey(const Key('deleteAccountRow')));
    await _tap(tester, find.byKey(const Key('deleteAccountConfirm')));
    expect(server.deleted, isTrue);
    expect(app.account.signedIn, isFalse);
    expect(find.text(s.accountDeleted), findsOneWidget);
    // the plan on the phone stays
    expect(app.plan, isNotNull);
  });

  testWidgets('Ask BloomBack: sign in first; answers show their source; the fourth question opens Pro; report', (tester) async {
    final (app, server) = await _ready(tester);
    await _tap(tester, find.text(s.tabPlan));
    await _tap(tester, find.byKey(const Key('askCard')));
    expect(find.text(s.askSignIn), findsOneWidget);
    expect(find.byKey(const Key('askField')), findsNothing);
    await _tap(tester, find.byKey(const Key('back')));

    await _signInFromMore(tester);
    await _tap(tester, find.byKey(const Key('back')));
    await _tap(tester, find.byKey(const Key('more_ask')));
    expect(find.text(s.askLeftFree(3)), findsOneWidget);
    await _tap(tester, find.text(s.askSamples1));
    expect(find.byKey(const Key('askAnswer')), findsOneWidget);
    expect(find.textContaining('straight to bed'), findsWidgets);
    expect(find.textContaining('Source: NIOSH'), findsOneWidget);
    expect(find.text(s.askLeftFree(2)), findsOneWidget);
    // what went to the server: the question, the plan's habit ids and the shift; no name, email or health numbers
    expect(server.asked.single['question'], s.askSamples1);
    expect(server.asked.single['habits'], ['homeToBed', 'blackout']);
    expect(server.asked.single['shift'], 'nightFixed');
    expect(server.asked.single.keys.toSet(), {'question', 'habits', 'shift', 'lang'});

    // report the answer
    await _tap(tester, find.byKey(const Key('reportAnswer')));
    await _tap(tester, find.text(s.reportWrong));
    await _tap(tester, find.text(s.reportSend));
    expect(server.reports.single['reason'], 'wrong');
    expect(server.reports.single.containsKey('answer'), isFalse);
    expect(find.text(s.reportThanks), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // the thank-you note sits over the question field for a moment
    await tester.pumpAndSettle();

    for (var i = 0; i < 2; i++) {
      await _type(tester, 'askField', 'When should I walk on a work day?');
      await _tap(tester, find.byKey(const Key('askSend')));
    }
    expect(find.text(s.askLeftFree(0)), findsOneWidget);
    // with none left, the send button opens Pro
    await _tap(tester, find.byKey(const Key('askSend')));
    expect(find.text(s.proPitch), findsOneWidget);
    expect(app.account.standing.freeAsksLeft, 0);
  });
}
