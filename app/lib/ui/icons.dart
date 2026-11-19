// Line icons (Material outlined) used across Chi's screens. No emoji in the UI.
import 'package:flutter/material.dart';

import '../rules/habits.dart';

class BBIcons {
  static const sprout = Icons.spa_outlined;
  static const sleep = Icons.bedtime_outlined;
  static const walk = Icons.directions_walk;
  static const today = Icons.home_outlined;
  static const plan = Icons.calendar_today_outlined;
  static const garden = Icons.local_florist_outlined;
  static const more = Icons.more_horiz;
  static const flower = Icons.local_florist;

  static IconData goalGroup(String g) => switch (g) {
        'night' => Icons.bedtime_outlined,
        'day' => Icons.wb_sunny_outlined,
        'mood' => Icons.favorite_border,
        'body' => Icons.directions_walk,
        _ => Icons.medical_services_outlined,
      };

  static IconData habit(Habit h) => switch (h.id) {
        'homeToBed' || 'bedEarlier' || 'bedWhenSleepy' || 'bedForSleep' => Icons.bed_outlined,
        'blackout' || 'dimLight' => Icons.visibility_off_outlined,
        'napBeforeShift' || 'sameWake' => Icons.schedule,
        'screensOff' => Icons.phonelink_off,
        'noCaffeine' => Icons.coffee_outlined,
        'quietRoom' => Icons.volume_off_outlined,
        'stairs' => Icons.stairs_outlined,
        'strength' => Icons.fitness_center,
        'stretch' => Icons.self_improvement,
        'breathing' => Icons.air,
        'standUp' => Icons.accessibility_new,
        _ => h.area == HabitArea.movement ? Icons.directions_walk : Icons.bedtime_outlined,
      };
}

/// The BloomBack sprout (with its small gold moon) from the app icon
/// (design/AppIcon.png, background made transparent, cropped). Decorative: the
/// app name is always written next to or under it.
class SproutMark extends StatelessWidget {
  final double size;
  const SproutMark({super.key, this.size = 28});

  static const asset = 'assets/images/sprout.png';

  @override
  Widget build(BuildContext context) => Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      );
}
