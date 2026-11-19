import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'data/open_store.dart';
import 'l10n/strings.dart';
import 'notify/notifier.dart';
import 'ui/common.dart';
import 'ui/demo.dart';
import 'ui/garden.dart';
import 'ui/more.dart';
import 'ui/onboarding.dart';
import 'ui/plan_tab.dart';
import 'ui/today.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifier = Notifier();
  await notifier.init();
  final store = await openStore();
  final app = AppState(store, notifier: notifier);
  runApp(BloomBackApp(state: app));
  await app.load();
}

final _navigatorKey = GlobalKey<NavigatorState>();

class BloomBackApp extends StatelessWidget {
  final AppState state;

  /// The web demo's "synthetic data" strip with the scenario picker (on by default on web).
  final bool demoBanner;
  const BloomBackApp({super.key, required this.state, this.demoBanner = kWebDemo});

  @override
  Widget build(BuildContext context) => AppScope(
        state: state,
        child: MaterialApp(
          title: s.appName,
          theme: bbTheme(),
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          builder: demoBanner
              ? (context, child) => DemoBanner(navigatorKey: _navigatorKey, child: child ?? const SizedBox())
              : null,
          home: const _Root(),
        ),
      );
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!app.loaded) return const Scaffold(body: SunBackground(child: Center(child: CircularProgressIndicator())));
    if (!app.onboarded) return const OnboardingScreen();
    return const HomeShell();
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  bool _autoSynced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync once when the app opens, if a band is paired.
    if (!_autoSynced) {
      _autoSynced = true;
      final app = AppScope.of(context);
      if (app.settings.bandId != null) Future.microtask(app.sync);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bottom bar: Today · Plan · Garden · More (Chi's design; UAE Design System: last item "More").
    AppScope.of(context).openTab = (i) => setState(() => _tab = i);
    final body = switch (_tab) {
      0 => TodayScreen(openTab: (i) => setState(() => _tab = i)),
      1 => const PlanScreen(),
      2 => const GardenScreen(),
      _ => const MoreScreen(),
    };
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
      backgroundColor: BBColors.background,
      // Today's picture runs under the status bar (Chi, thread 0006); the other tabs keep the safe area.
      body: SunBackground(child: SafeArea(top: _tab != 0, bottom: false, child: KeyedSubtree(key: ValueKey(_tab), child: body))),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: bbTabs(),
      ),
    ),
    );
  }
}
