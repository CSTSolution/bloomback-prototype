// BloomBack band (Chi's screens 23-24), optional: BloomBack works fully without it.
// Pairing: the band shows a 6-digit code. With the demo band the code is typed here;
// with a real band the phone's own Bluetooth dialog asks for it (OS bonding).
// Connected: sleep is an "estimate" with Chi's wording (Q2); brisk minutes are shown
// next to the user's own number, never instead of it.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../band/band_link.dart';
import '../l10n/strings.dart';
import 'common.dart';
import 'icons.dart';
import 'today.dart';

/// The code the demo band "shows" on its screen.
const kDemoBandCode = '482913';

class BandScreen extends StatelessWidget {
  const BandScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final paired = app.settings.bandId != null;
    return BBPage(
      title: s.bandHeader,
      onBack: () => Navigator.of(context).maybePop(),
      body: paired ? const _Connected() : const _Pair(),
    );
  }
}

class _Pair extends StatefulWidget {
  const _Pair();

  @override
  State<_Pair> createState() => _PairState();
}

class _PairState extends State<_Pair> {
  final _code = List.generate(6, (_) => TextEditingController());
  final _focus = List.generate(6, (_) => FocusNode());
  StreamSubscription<List<FoundBand>>? _scan;
  List<FoundBand> _found = [];
  bool _scanning = false;
  bool _pairing = false;
  String? _error;

  @override
  void dispose() {
    _scan?.cancel();
    for (final c in _code) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  String get _typed => _code.map((c) => c.text).join();

  void _startScan(AppState app) {
    setState(() {
      _scanning = true;
      _found = [];
      _error = null;
    });
    _scan?.cancel();
    _scan = app.link.scan().listen(
          (list) => setState(() => _found = list),
          onError: (Object e) => setState(() {
            _error = e.toString();
            _scanning = false;
          }),
          onDone: () => setState(() => _scanning = false),
        );
  }

  Future<void> _pairDemo(AppState app) async {
    setState(() => _pairing = true);
    try {
      final found = await app.link.scan().first;
      if (found.isNotEmpty) await app.pair(found.first);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _pairing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    final demo = app.link.isFake;
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
          Text(s.pairTitle, style: tt.headlineSmall),
          const SizedBox(height: 4),
          Text(s.pairBody, style: tt.bodyMedium?.copyWith(color: BBColors.muted)),
          if (demo) Text(s.demoBand, style: tt.bodySmall),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 124,
              height: 150,
              decoration: BoxDecoration(color: const Color(0xFF1F2A25), borderRadius: BorderRadius.circular(32)),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
                child: Text(demo ? '482 913' : '··· ···',
                    style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 1.5)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(s.holdButton, textAlign: TextAlign.center, style: tt.bodySmall),
          const SizedBox(height: 16),
          if (demo) ...[
            Text(s.enterCode, style: tt.titleSmall),
            const SizedBox(height: 8),
            Row(children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    key: Key('code_$i'),
                    controller: _code[i],
                    focusNode: _focus[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)],
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(vertical: 14)),
                    onChanged: (v) {
                      if (v.isNotEmpty && i < 5) _focus[i + 1].requestFocus();
                      setState(() {});
                    },
                  ),
                ),
              ],
            ]),
          ] else ...[
            Text(s.realBandCodeHint, style: tt.bodyMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _scanning ? null : () => _startScan(app),
              icon: const Icon(Icons.bluetooth_searching),
              label: Text(_scanning ? s.bandScanning : s.bandScan),
            ),
            for (final b in _found)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.watch_outlined),
                title: Text(b.name),
                subtitle: Text('${b.rssi} dBm'),
                trailing: FilledButton(
                  onPressed: () async {
                    await app.link.stopScan();
                    await app.pair(b);
                  },
                  child: Text(s.bandConnect),
                ),
              ),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!)),
          const SizedBox(height: 16),
          BBCard(
            color: BBColors.primaryLight,
            border: BBColors.primaryBorder,
            child: Row(children: [
              const Icon(Icons.lock_outline, color: BBColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(s.bandPrivacy, style: tt.bodySmall?.copyWith(color: BBColors.ink))),
            ]),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (demo)
            PrimaryButton(
              key: const Key('pairBand'),
              label: s.pairBand,
              onPressed: _typed.length == 6 && !_pairing ? () => _pairDemo(app) : null,
            ),
          TextButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(s.notNow)),
        ]),
      ),
    ]);
  }
}

class _Connected extends StatelessWidget {
  const _Connected();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    final info = app.lastInfo;
    final sleep = app.lastSleepDay;
    Widget stat(String label, String value, {String? sub}) => Expanded(
          child: BBCard(
            margin: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CapsLabel(label),
              const SizedBox(height: 4),
              Text(value, style: heading(22)),
              if (sub != null) Text(sub, style: tt.bodySmall),
            ]),
          ),
        );
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
      Row(children: [
        Expanded(child: Text(s.yourBand, style: tt.headlineSmall)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: BBColors.primary, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(s.connected, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
      Wrap(spacing: 12, children: [
        Text(app.settings.bandName ?? '', style: tt.bodySmall),
        if (app.lastSync != null) Text(s.syncedAgo(s.ago(app.clock().difference(app.lastSync!))), style: tt.bodySmall),
        if (info != null) Text(s.bandBattery(info.battery), style: tt.bodySmall),
      ]),
      if (app.link.isFake) Text(s.demoBand, style: tt.bodySmall),
      const SizedBox(height: 8),
      BBCard(
        key: const Key('lastSleep'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(BBIcons.sleep, color: BBColors.data, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(s.lastMainSleep, style: tt.titleSmall)),
            BBTag(s.estimate),
            WhyButton(title: s.lastMainSleep, source: kBandSleepSource, body: s.bandSleepNote),
          ]),
          const SizedBox(height: 4),
          if (sleep == null)
            Text(s.noSleepWindow, style: tt.bodySmall)
          else
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(s.hm(sleep.sleep.sleepMinutes), style: heading(22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(s.sleepWindow(clockOf(sleep.sleep.startMinute), clockOf(sleep.sleep.endMinute)),
                    textAlign: TextAlign.end, style: tt.bodySmall),
              ),
            ]),
          const SizedBox(height: 4),
          Text(s.fromWrist, style: tt.bodySmall),
        ]),
      ),
      const SizedBox(height: 6),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          stat(s.stepsToday, s.count(app.todaySummary?.steps ?? 0)),
          const SizedBox(width: 8),
          stat(s.briskMin7, '${app.weekModerate}', sub: s.nextToOwn(app.profile?.selfWalkMinutes ?? 0)),
        ]),
      ),
      const SizedBox(height: 6),
      Container(
        key: const Key('whyEstimate'),
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: BBColors.primaryLight,
          border: Border(left: BorderSide(color: BBColors.primary, width: 3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.whyEstimate, style: tt.titleSmall),
          const SizedBox(height: 4),
          Text(s.bandSleepNote, style: tt.bodySmall?.copyWith(color: BBColors.ink)),
        ]),
      ),
      if (app.syncing) ...[
        const SizedBox(height: 10),
        const LinearProgressIndicator(),
        Text(s.bandStatus(app.syncStep ?? ''), style: tt.bodySmall),
      ],
      if (app.bandMessage != null)
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(app.bandMessage!, style: tt.bodySmall)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: OutlinedButton(
            key: const Key('syncNow'),
            onPressed: app.syncing ? null : app.sync,
            child: Text(s.syncNow),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            key: const Key('bandSettings'),
            onPressed: () => _settings(context, app),
            child: Text(s.bandSettings),
          ),
        ),
      ]),
    ]);
  }

  Future<void> _settings(BuildContext context, AppState app) async {
    final info = app.lastInfo;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(s.bandSettings, style: Theme.of(c).textTheme.titleLarge),
          ),
          if (info != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text(s.bandInfo(info.battery, info.fw, info.days), style: Theme.of(c).textTheme.bodySmall),
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(s.bandDelete),
            onTap: () => Navigator.pop(c, 'delete'),
          ),
          ListTile(
            leading: const Icon(Icons.link_off),
            title: Text(s.bandForget),
            onTap: () => Navigator.pop(c, 'forget'),
          ),
        ]),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          content: Text(s.bandDeleteQ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.ok)),
          ],
        ),
      );
      if (ok == true) await app.deleteOnBand();
    } else {
      final fake = app.link.isFake;
      await app.forgetBand();
      if (!context.mounted || fake || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          content: Text(s.bandForgetIos),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(s.ok))],
        ),
      );
    }
  }
}
