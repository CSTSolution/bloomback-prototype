// Chi's design tokens ("Young leaf + early sun", docs/design/DESIGN-SPEC.md) and the
// small widget kit every screen is built from. No red anywhere (rules: no red);
// colour is never the only signal (always text or an icon too).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BBColors {
  static const primary = Color(0xFF278552); // young leaf green: buttons, selected chips, active tab
  static const primaryLight = Color(0xFFE3F4E9); // today's step card, source boxes
  static const primaryBorder = Color(0xFFC9E8D4);
  static const accent = Color(0xFF9A6A12); // early sun: motivation, "BloomBack suggestion", days bloomed
  static const accentLight = Color(0xFFFCF1D6); // motivation card, Lapse Radar card
  static const sun = Color(0xFFFDF0D2); // soft band at the top of every screen
  static const background = Color(0xFFF4FAF5);
  static const data = Color(0xFF3E7CB1); // neutral bars: current vs recommended
  static const ink = Color(0xFF1E2A24);
  static const muted = Color(0xFF66746C);
  static const line = Color(0xFFDCE7E0); // card borders, empty bar track
  static const grey = Color(0xFFE6ECE8); // garden days that did not bloom (never "missed")
}

const kHeadingFont = 'Baloo2';
const kBodyFont = 'BeVietnamPro';
const kArabicFont = 'NotoNaskhArabic';
/// Glyphs Be Vietnam Pro lacks (e.g. "→") come from the bundled fonts, never from the web.
const kFallbackFonts = [kHeadingFont, kArabicFont];

/// Baloo 2 is a variable font: the weight comes from the wght axis.
TextStyle heading(double size, {Color color = BBColors.ink, FontWeight weight = FontWeight.w700}) => TextStyle(
      fontFamily: kHeadingFont,
      fontSize: size,
      height: 1.2,
      fontWeight: weight,
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
      color: color,
    );

ThemeData bbTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: BBColors.primary).copyWith(
    primary: BBColors.primary,
    onPrimary: Colors.white,
    primaryContainer: BBColors.primaryLight,
    onPrimaryContainer: BBColors.ink,
    secondary: BBColors.accent,
    onSecondary: Colors.white,
    secondaryContainer: BBColors.accentLight,
    onSecondaryContainer: BBColors.ink,
    tertiary: BBColors.data,
    // Material uses "error" for warnings; it stays ochre, never red.
    error: BBColors.accent,
    onError: Colors.white,
    errorContainer: BBColors.accentLight,
    onErrorContainer: BBColors.ink,
    surface: Colors.white,
    onSurface: BBColors.ink,
    onSurfaceVariant: BBColors.muted,
    outline: BBColors.primaryBorder,
    outlineVariant: BBColors.line,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: kBodyFont);
  final body = base.textTheme.apply(
    fontFamily: kBodyFont,
    bodyColor: BBColors.ink,
    displayColor: BBColors.ink,
    fontFamilyFallback: kFallbackFonts,
  );
  final text = body.copyWith(
    headlineLarge: heading(30),
    headlineMedium: heading(26),
    headlineSmall: heading(22),
    titleLarge: heading(20),
    titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 16, height: 1.35),
    titleSmall: body.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 14, height: 1.35),
    bodyLarge: body.bodyLarge?.copyWith(fontSize: 15, height: 1.45),
    bodyMedium: body.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
    bodySmall: body.bodySmall?.copyWith(fontSize: 12.5, height: 1.4, color: BBColors.muted),
    labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
  );
  const pill = StadiumBorder();
  final btnShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: BBColors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: BBColors.ink,
      titleTextStyle: text.titleMedium,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: BBColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BBColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: BBColors.grey,
        disabledForegroundColor: BBColors.muted,
        minimumSize: const Size(48, 48),
        shape: btnShape,
        textStyle: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BBColors.ink,
        backgroundColor: Colors.white,
        side: const BorderSide(color: BBColors.line),
        minimumSize: const Size(48, 44),
        shape: btnShape,
        textStyle: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: BBColors.primary,
        textStyle: const TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: pill,
      side: const BorderSide(color: BBColors.line),
      backgroundColor: Colors.white,
      selectedColor: BBColors.primary,
      labelStyle: const TextStyle(fontFamily: kBodyFont, color: BBColors.ink, fontSize: 13),
      secondaryLabelStyle: const TextStyle(fontFamily: kBodyFont, color: Colors.white, fontSize: 13),
      checkmarkColor: Colors.white,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? BBColors.primary : BBColors.grey),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: BBColors.primaryLight,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: kBodyFont,
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? BBColors.primary : BBColors.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) =>
          IconThemeData(color: s.contains(WidgetState.selected) ? BBColors.primary : BBColors.muted)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: BBColors.line)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: BBColors.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: BBColors.primary, width: 1.5)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: BBColors.ink),
    dividerTheme: const DividerThemeData(color: BBColors.line, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: BBColors.primary, linearTrackColor: BBColors.grey),
  );
}

/// The soft "early sun" band at the top of every screen, fading into the background.
class SunBackground extends StatelessWidget {
  final Widget child;
  const SunBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Stack(children: [
        const Positioned.fill(child: ColoredBox(color: BBColors.background)),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 260,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [BBColors.sun, BBColors.background],
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ]);
}

/// Round white back button (Chi's screens: "‹" in a circle).
class BackCircle extends StatelessWidget {
  final VoidCallback onTap;
  const BackCircle({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Back',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            key: const Key('back'),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: BBColors.line),
            ),
            child: const Icon(Icons.chevron_left, size: 20, color: BBColors.ink),
          ),
        ),
      );
}

/// A screen with the sun band, an optional header row (back, title, step "1 / 5",
/// progress) and an optional bottom area for the one primary button.
class BBPage extends StatelessWidget {
  final String? title;
  final VoidCallback? onBack;
  final String? step;
  final double? progress;
  final Widget body;
  final Widget? bottom;
  final Widget? trailing;
  /// The app's bottom tab bar on a pushed page (the step timer keeps it, Chi's design 16/11).
  final Widget? navBar;
  const BBPage({
    super.key,
    this.title,
    this.onBack,
    this.step,
    this.progress,
    required this.body,
    this.bottom,
    this.trailing,
    this.navBar,
  });

  @override
  Widget build(BuildContext context) {
    final showHeader = title != null || onBack != null || trailing != null;
    // Dark status bar icons on every light page; only Today's night picture switches them to light.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        bottomNavigationBar: navBar,
      backgroundColor: BBColors.background,
      body: SunBackground(
        child: SafeArea(
          child: Column(children: [
            if (showHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(children: [
                  if (onBack != null) ...[BackCircle(onTap: onBack!), const SizedBox(width: 12)],
                  Expanded(
                    child: Text(title ?? '', style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                  ),
                  if (step != null) Text(step!, style: Theme.of(context).textTheme.bodySmall),
                  ?trailing,
                ]),
              ),
            if (progress != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: progress, minHeight: 4),
                ),
              ),
            Expanded(child: body),
            if (bottom != null) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: bottom),
          ]),
        ),
      ),
    ),
    );
  }
}

/// The one primary button at the bottom of a screen.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: icon == null
            ? FilledButton(onPressed: onPressed, child: Text(label))
            : FilledButton.icon(onPressed: onPressed, icon: Icon(icon, size: 20), label: Text(label)),
      );
}

/// Rounded card (radius 18) with a thin border.
class BBCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color border;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final double borderWidth;
  const BBCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.border = BBColors.line,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.onTap,
    this.borderWidth = 1,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: margin,
        child: Material(
          color: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: border, width: borderWidth),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

/// Pill chip: selected = green with white text; otherwise white with a border.
class PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool expand;
  const PillChip({super.key, required this.label, required this.selected, this.onTap, this.icon, this.expand = false});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : BBColors.ink;
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(fontFamily: kBodyFont, fontFamilyFallback: kFallbackFonts, fontSize: 13.5, color: fg, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
    );
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? BBColors.primary : Colors.white,
        shape: StadiumBorder(side: BorderSide(color: selected ? BBColors.primary : BBColors.line)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
              Flexible(child: text),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Small pill tag, e.g. "BloomBack suggestion" or "estimate" (accent on accent light).
class BBTag extends StatelessWidget {
  final String text;
  const BBTag(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: BBColors.accentLight, borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: kBodyFont, fontSize: 11.5, fontWeight: FontWeight.w600, color: BBColors.accent)),
      );
}

/// Small caps label, e.g. "TODAY'S SMALL STEP".
class CapsLabel extends StatelessWidget {
  final String text;
  final Color color;
  const CapsLabel(this.text, {super.key, this.color = BBColors.muted});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(fontFamily: kBodyFont, fontFamilyFallback: kFallbackFonts, fontSize: 11.5, letterSpacing: 0.6, color: color, fontWeight: FontWeight.w500),
      );
}

/// A choice card with a radio mark (Chi's "Follow the suggestion", "Make it smaller").
class RadioCard extends StatelessWidget {
  final bool selected;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  const RadioCard({super.key, required this.selected, required this.title, this.subtitle, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) => BBCard(
        onTap: onTap,
        border: selected ? BBColors.primary : BBColors.line,
        borderWidth: selected ? 1.6 : 1,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Semantics(
          selected: selected,
          child: Row(children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 20, color: selected ? BBColors.primary : BBColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.w500, fontSize: 14.5)),
                if (subtitle != null) Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            ?trailing,
          ]),
        ),
      );
}

/// A bar comparing the current level with the recommendation (neutral blue, never red).
class LevelBar extends StatelessWidget {
  final double value; // 0..1 of the bar
  final double marker; // 0..1 position of the recommendation line
  const LevelBar({super.key, required this.value, required this.marker});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 18,
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          return Stack(alignment: Alignment.centerLeft, children: [
            Container(height: 10, decoration: BoxDecoration(color: BBColors.grey, borderRadius: BorderRadius.circular(6))),
            Container(
              width: w * value.clamp(0.0, 1.0),
              height: 10,
              decoration: BoxDecoration(color: BBColors.data, borderRadius: BorderRadius.circular(6)),
            ),
            Positioned(left: (w * marker.clamp(0.0, 1.0) - 1).clamp(0.0, w - 2), child: Container(width: 2, height: 18, color: BBColors.ink)),
          ]);
        }),
      );
}
