// Local notifications for the 2 daily reminders (rules C4): at most 2 a day,
// never inside quiet hours, no catch-up if one is missed. Nothing leaves the phone.
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../l10n/strings.dart';

class Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('notifications unavailable: $e');
    }
  }

  Future<void> requestPermission() async {
    if (!_ready) return;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
  }

  /// Replaces the schedule with one-off notifications at the given local times
  /// (rules/environment.dart reminderSchedule: at most 2 a day, none in quiet
  /// hours, each day from its own rules). Refreshed whenever the app opens, a
  /// check-in is saved or a setting changes. Up to 7 days ahead (iOS allows 64).
  Future<void> schedule(List<(DateTime, String)> reminders) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    const details = NotificationDetails(
      android: AndroidNotificationDetails('habit', 'Habit reminders',
          importance: Importance.defaultImportance, priority: Priority.defaultPriority),
      iOS: DarwinNotificationDetails(),
    );
    for (var i = 0; i < reminders.length && i < 60; i++) {
      final (at, body) = reminders[i];
      await _plugin.zonedSchedule(
        i + 1,
        s.appName,
        body,
        tz.TZDateTime.from(at, tz.UTC),
        details,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelAll() async {
    if (_ready) await _plugin.cancelAll();
  }
}
