import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../l10n/strings.dart';
import '../rules/org_names.dart';
import '../rules/sources.dart';
import 'icons.dart';
import 'theme.dart';

export 'theme.dart';

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// "Why this suggestion?" (Chi's screen 13): why it was suggested, the source
/// (with a short quote where checked), the target, the disclaimer and the link.
Future<void> showWhy(
  BuildContext context,
  String title,
  String source, {
  String? body,
  String? quote,
  String? target,
}) {
  final link = sourceLinkFor(source);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) {
      final tt = Theme.of(c).textTheme;
      Widget box(String label, String text, {String? q}) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: const BoxDecoration(
              color: BBColors.primaryLight,
              border: Border(left: BorderSide(color: BBColors.primary, width: 3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: tt.titleSmall),
              const SizedBox(height: 2),
              Text(text, style: tt.bodyMedium?.copyWith(fontSize: 13)),
              if (q != null) ...[
                const SizedBox(height: 4),
                Text('"$q"', style: tt.bodyMedium?.copyWith(fontStyle: FontStyle.italic, fontSize: 13)),
              ],
            ]),
          );
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.whyTitle, style: tt.titleLarge),
              const SizedBox(height: 4),
              Text(title, style: tt.titleSmall),
              if (body != null) ...[const SizedBox(height: 6), Text(body, style: tt.bodyMedium)],
              box(s.source, source, q: quote),
              OrgNotes(source),
              if (target != null) box(s.yourTarget, target),
              const SizedBox(height: 12),
              Text(kNotMedicalAdvice, style: tt.bodySmall),
              const SizedBox(height: 12),
              if (link != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('openSource'),
                    onPressed: () async {
                      // No browser plugin in the app: the link is copied to open anywhere.
                      await Clipboard.setData(ClipboardData(text: link.url));
                      if (c.mounted) {
                        ScaffoldMessenger.maybeOf(c)?.showSnackBar(SnackBar(content: Text(s.linkCopied(link.url))));
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(s.openSource),
                  ),
                ),
              if (link != null) ...[
                const SizedBox(height: 6),
                SelectableText(link.url, style: tt.bodySmall),
              ],
            ]),
          ),
        ),
      );
    },
  );
}

/// The round "?" next to every piece of advice; opens its source.
class WhyButton extends StatelessWidget {
  final String title;
  final String source;
  final String? body;
  final String? quote;
  final String? target;
  /// Replaces the default sheet (e.g. today's habit, which adds the user's cards).
  final VoidCallback? onTap;
  const WhyButton(
      {super.key, required this.title, required this.source, this.body, this.quote, this.target, this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: s.why,
        child: Tooltip(
          message: s.why,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap ?? () => showWhy(context, title, source, body: body, quote: quote, target: target),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: BBColors.primary, width: 1.6),
                ),
                child: const Text('?',
                    style: TextStyle(color: BBColors.primary, fontWeight: FontWeight.w700, fontSize: 13, height: 1.1)),
              ),
            ),
          ),
        ),
      );
}

/// A rounded card with an optional title row (kept for the settings-style screens).
class SectionCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final List<Widget> children;
  final Color? color;
  const SectionCard({super.key, this.title, this.trailing, required this.children, this.color});

  @override
  Widget build(BuildContext context) => BBCard(
        color: color ?? Colors.white,
        border: color == null || color == Colors.white
            ? BBColors.line
            : (color == BBColors.accentLight ? const Color(0xFFF2DFAE) : BBColors.primaryBorder),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Row(children: [
                Expanded(child: Text(title!, style: Theme.of(context).textTheme.titleMedium)),
                ?trailing,
              ]),
            if (title != null) const SizedBox(height: 8),
            ...children,
          ],
        ),
      );
}

String hhmm(int minuteOfDay) {
  if (minuteOfDay < 0) return s.off;
  final h = minuteOfDay ~/ 60, m = minuteOfDay % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Local clock text for a UTC unix minute.
String clockOf(int utcMinute) {
  final d = DateTime.fromMillisecondsSinceEpoch(utcMinute * 60000);
  return hhmm(d.hour * 60 + d.minute);
}

Future<int?> pickTime(BuildContext context, int current) async {
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: current < 0 ? 8 : current ~/ 60, minute: current < 0 ? 0 : current % 60),
  );
  return t == null ? null : t.hour * 60 + t.minute;
}

/// "Coming with the pilot" sheet for things that need a server (sign-in, sharing).
Future<void> showPilotSheet(BuildContext context, String title, String body, {String? action, VoidCallback? onAction}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body),
          const SizedBox(height: 16),
          PrimaryButton(
            label: action ?? s.ok,
            onPressed: () {
              Navigator.pop(c);
              onAction?.call();
            },
          ),
        ]),
      ),
    ),
  );
}


/// Text where short organisation names ("CDC", "WHO", "DoH"…) can be tapped for the full name (Chi, 16/11).
class OrgText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const OrgText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final parts = splitOrgNames(text);
    if (!parts.any((p) => p.$2)) return Text(text, style: base);
    return Text.rich(TextSpan(style: base, children: [
      for (final (part, org) in parts)
        if (!org)
          TextSpan(text: part)
        else
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            // a tap opens a small sheet that stays until closed, on phones and on the web (Chi, thread 0004 fix 13)
            child: Semantics(
              button: true,
              label: '$part: ${kOrgNames[part]}',
              child: GestureDetector(
              key: Key('org_$part'),
              behavior: HitTestBehavior.opaque,
              onTap: () => showOrgName(context, part),
              child: Text(part,
                  style: base.copyWith(
                    color: BBColors.primary,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: BBColors.primary,
                  )),
              ),
            ),
          ),
    ]));
  }
}

/// Under a source: who each short name is, and the reuse lines the source asks for (CDC terms, CC BY 4.0).
class OrgNotes extends StatelessWidget {
  final String source;
  const OrgNotes(this.source, {super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final names = orgNamesIn(source);
    final lines = <String>[
      for (final n in names) '$n: ${kOrgNames[n]}',
      if (needsCdcLine(source)) kCdcAttribution,
      if (isCcBy4(source)) 'Licence: CC BY 4.0 · $kCcBy4',
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final l in lines) Text(l, style: tt.bodySmall),
      ]),
    );
  }
}


/// "CDC: U.S. Centers for Disease Control and Prevention", until the user closes it.
Future<void> showOrgName(BuildContext context, String short) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$short: ${kOrgNames[short]}', key: const Key('orgFullName'), style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: 16),
            PrimaryButton(label: s.ok, onPressed: () => Navigator.pop(c)),
          ]),
        ),
      ),
    );


/// Today · Plan · Garden · More (Chi's design; UAE Design System: last item "More").
List<NavigationDestination> bbTabs() => [
      NavigationDestination(icon: const Icon(BBIcons.today), label: s.tabToday),
      NavigationDestination(icon: const Icon(BBIcons.plan), label: s.tabPlan),
      NavigationDestination(icon: const Icon(BBIcons.garden), label: s.tabGarden),
      NavigationDestination(icon: const Icon(BBIcons.more), label: s.tabMore),
    ];


/// The bottom tab bar on a page pushed over the home screen (Chi's designs keep it everywhere): a tab goes back to
/// the home screen and opens that tab.
class BBTabBar extends StatelessWidget {
  final int selected;
  const BBTabBar({super.key, this.selected = 0});

  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: selected,
        destinations: bbTabs(),
        onDestinationSelected: (i) {
          final app = AppScope.of(context);
          Navigator.of(context).popUntil((r) => r.isFirst);
          app.openTab?.call(i);
        },
      );
}
