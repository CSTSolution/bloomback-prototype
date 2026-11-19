// Top of Today (Chi, thread 0006, approved 16/11): a UAE beach picture that follows the time of day, the greeting on
// the calm sky top-left, and the garden drawn by the app on the sand (one flower per day the step bloomed, today's
// bud with a dashed ring). Hours are BloomBack's own: dawn 05:30-08:00, noon 08:00-17:00, evening 17:00-19:00,
// night 19:00-05:30. The picture runs under a transparent status bar and fades into the page; at night the page
// below gets a light violet tint so the screen does not look split in two.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import 'common.dart';
import 'icons.dart';

enum DayLight { dawn, noon, evening, night }

DayLight dayLightAt(DateTime t) {
  final m = t.hour * 60 + t.minute;
  if (m >= 5 * 60 + 30 && m < 8 * 60) return DayLight.dawn;
  if (m >= 8 * 60 && m < 17 * 60) return DayLight.noon;
  if (m >= 17 * 60 && m < 19 * 60) return DayLight.evening;
  return DayLight.night;
}

String dayLightAsset(DayLight l) => 'assets/images/today-bg-${l.name}.jpg';

/// Page colour under the picture: the usual background, a light violet at night.
Color pageColorFor(DayLight l) => l == DayLight.night ? const Color(0xFFF0EDF8) : BBColors.background;

/// Status bar icons: light on the night sky, dark otherwise.
SystemUiOverlayStyle statusBarFor(DayLight l) => (l == DayLight.night ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
    .copyWith(statusBarColor: Colors.transparent);

const _petals = [Color(0xFFF2C14E), Color(0xFF8DB8E8), Color(0xFFB9A0E0), Color(0xFF7FC79A), Color(0xFFF0A868), Color(0xFFF4A3C0)];

class TodayHero extends StatelessWidget {
  final AppState app;
  final String label;
  final String greeting;
  final VoidCallback onOpenGarden;
  final VoidCallback? onAvatar;
  const TodayHero({
    super.key,
    required this.app,
    required this.label,
    required this.greeting,
    required this.onOpenGarden,
    this.onAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final light = dayLightAt(app.clock());
    final night = light == DayLight.night;
    final ink = night ? Colors.white : BBColors.ink;
    final top = MediaQuery.paddingOf(context).top;
    final tt = Theme.of(context).textTheme;
    final page = pageColorFor(light);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final h = top + w * 2 / 3;
      return SizedBox(
        key: const Key('todayHero'),
        height: h,
        child: Stack(fit: StackFit.expand, children: [
          Image.asset(
            dayLightAsset(light),
            key: Key('heroImage_${light.name}'),
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => ColoredBox(color: night ? const Color(0xFF4050A5) : BBColors.sun),
          ),
          // soft fade into the page: no hard cut under the picture
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [page.withValues(alpha: 0), page],
                ),
              ),
            ),
          ),
          // greeting on the calm sky, top-left
          Positioned(
            left: 20,
            right: 16,
            top: top + 12,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (label.isNotEmpty) Text(label, style: tt.bodySmall?.copyWith(color: ink)),
                  Text(greeting, key: const Key('greeting'), style: heading(26, color: ink)),
                ]),
              ),
              if (app.displayName.isNotEmpty)
                // the avatar opens More › Account (Chi, thread 0004 fix 7)
                InkWell(
                  key: const Key('avatar'),
                  customBorder: const CircleBorder(),
                  onTap: onAvatar,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white.withValues(alpha: 0.85),
                    child: Text(app.displayName.characters.first.toUpperCase(),
                        style: const TextStyle(color: BBColors.ink, fontWeight: FontWeight.w600)),
                  ),
                ),
            ]),
          ),
          // the garden on the sand
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            height: math.min(96, w * 2 / 3 * 0.36),
            child: GestureDetector(
              key: const Key('heroGarden'),
              behavior: HitTestBehavior.opaque,
              onTap: onOpenGarden,
              child: _SandGarden(app: app),
            ),
          ),
        ]),
      );
    });
  }
}

class _SandGarden extends StatelessWidget {
  final AppState app;
  const _SandGarden({required this.app});

  @override
  Widget build(BuildContext context) {
    final bloomedDays = [
      for (final e in app.byDay.entries)
        if (e.key >= app.planDay && (e.value == CheckinStatus.done || e.value == CheckinStatus.partial)) e.key,
    ]..sort();
    final today = app.today;
    final todayBloomed = bloomedDays.contains(today);
    final count = bloomedDays.length;
    return LayoutBuilder(builder: (context, c) {
      final flowerW = 30.0;
      // leave room for the label on the right (about 200 pt) and today's bud
      final room = ((c.maxWidth - 205 - (todayBloomed ? 0 : 36)) / flowerW).floor().clamp(2, 9);
      final shown = bloomedDays.length > room ? bloomedDays.sublist(bloomedDays.length - room) : bloomedDays;
      return Stack(children: [
        Positioned(
          left: 0,
          bottom: 0,
          top: 0,
          right: 0,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final d in shown) _Stem(color: _petals[d % _petals.length], height: c.maxHeight * 0.72 - (d % 3) * 7),
            if (!todayBloomed) _Bud(height: c.maxHeight * 0.62),
          ]),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            key: const Key('heroGardenLabel'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(BBIcons.sprout, size: 14, color: BBColors.primary),
              const SizedBox(width: 4),
              Text(s.heroGardenLabel(count, waiting: !todayBloomed),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: BBColors.primary)),
            ]),
          ),
        ),
      ]);
    });
  }
}

class _Stem extends StatelessWidget {
  final Color color;
  final double height;
  const _Stem({required this.color, required this.height});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 30,
        height: height.clamp(30, 200),
        child: Column(children: [
          Icon(BBIcons.flower, size: 24, color: color),
          Expanded(child: Container(width: 2.5, color: const Color(0xFF3E9A62))),
        ]),
      );
}

class _Bud extends StatelessWidget {
  final double height;
  const _Bud({required this.height});

  @override
  Widget build(BuildContext context) => SizedBox(
        key: const Key('heroBud'),
        width: 36,
        height: height.clamp(30, 200),
        child: Column(children: [
          CustomPaint(
            size: const Size(28, 28),
            painter: _DashedRing(),
            child: const SizedBox(
              width: 28,
              height: 28,
              child: Center(child: Icon(Icons.eco, size: 14, color: Color(0xFF3E9A62))),
            ),
          ),
          Expanded(child: Container(width: 2.5, color: const Color(0xFF3E9A62))),
        ]),
      );
}

class _DashedRing extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF3E9A62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final r = size.width / 2 - 1;
    const n = 14;
    for (var i = 0; i < n; i++) {
      final a = 2 * math.pi * i / n;
      canvas.drawArc(Rect.fromCircle(center: size.center(Offset.zero), radius: r), a, math.pi / n, false, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
