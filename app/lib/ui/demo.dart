// Demo scenarios picker (Settings > Debug, demo band only) and the web demo banner.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../demo/scenarios.dart';
import '../l10n/strings.dart';
import 'common.dart';

/// The web build is a demo: demo band only, in-memory data, no reminders.
const kWebDemo = kIsWeb;

/// Lists the scenarios with their one-line descriptions; picking one (after a
/// confirm) resets the app's data to it.
Future<void> showScenarioPicker(BuildContext context, AppState app) async {
  final sc = await showModalBottomSheet<DemoScenario>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(s.demoScenarios, style: Theme.of(c).textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(s.demoScenariosHint, style: Theme.of(c).textTheme.bodySmall),
          ),
          for (final x in DemoScenario.values)
            ListTile(
              key: Key('scenario_${x.name}'),
              title: Text(s.scenarioTitle(x)),
              subtitle: Text(s.scenarioDescription(x)),
              onTap: () => Navigator.pop(c, x),
            ),
        ]),
      ),
    ),
  );
  if (sc == null || !context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(s.scenarioTitle(sc)),
      content: Text(s.demoScenarioQ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.ok)),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final msg = ScaffoldMessenger.maybeOf(context);
  await app.applyScenario(sc);
  msg?.showSnackBar(SnackBar(content: Text(s.demoLoaded(s.scenarioTitle(sc)))));
}

/// Settings > Debug row that opens the picker (shown only with the demo band on).
class ScenarioTile extends StatelessWidget {
  const ScenarioTile({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final loading = app.loadingScenario != null;
    return ListTile(
      key: const Key('demoScenarios'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.movie_outlined),
      title: Text(s.demoScenarios),
      subtitle: Text(loading ? s.demoLoading : s.demoScenariosHint),
      trailing: loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.chevron_right),
      onTap: loading ? null : () => showScenarioPicker(context, app),
    );
  }
}

/// Web demo: a strip above every screen (onboarding included) with the
/// synthetic-data notice and the scenario picker.
class DemoBanner extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  const DemoBanner({super.key, required this.navigatorKey, required this.child});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final loading = app.loadingScenario != null;
    final mq = MediaQuery.of(context);
    return Column(children: [
      Material(
        color: BBColors.primaryLight,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, mq.padding.top + 6, 8, 6),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 18, color: BBColors.ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s.demoBanner,
                  key: const Key('demoBanner'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BBColors.ink)),
            ),
            if (app.settings.useFakeBand)
              TextButton.icon(
                key: const Key('bannerScenarios'),
                onPressed: loading
                    ? null
                    : () {
                        final c = navigatorKey.currentContext;
                        if (c != null) showScenarioPicker(c, app);
                      },
                icon: loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.movie_outlined, size: 18),
                label: Text(s.demoScenariosShort),
              ),
          ]),
        ),
      ),
      Expanded(
        child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
      ),
    ]);
  }
}
