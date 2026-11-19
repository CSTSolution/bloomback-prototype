// Music while you move (Chi, thread 0007, design docs/design/music-while-you-move-2026-11-16.png):
// 2 · In progress: countdown ring, Pause, Finish now; the now-playing card (title, credit, pause, next) when music is on.
// 3 · Time is up (or Finish now): a soft chime, "How did it go?" → Done / Partly; the flower blooms on Today and the
//     day's question follows there. Nothing is saved until Done or Partly. Music only makes the step more pleasant
//     (no health claim); silent mode and quiet hours are respected by the sound layer.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import '../sound/after_sound.dart';
import 'after_step.dart';
import 'common.dart';
import 'icons.dart';

Future<void> openStepTimer(BuildContext context, AppState app, {ValueChanged<int>? openTab}) async {
  final minutes = app.stepMinutes();
  if (minutes == null) return;
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  await Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => StepTimerScreen(minutes: minutes, openTab: openTab)));
}

class StepTimerScreen extends StatefulWidget {
  final int minutes;
  /// Switches the home tab; the timer keeps the bottom bar (Chi, thread 0004 fix 11).
  final ValueChanged<int>? openTab;
  const StepTimerScreen({super.key, required this.minutes, this.openTab});

  @override
  State<StepTimerScreen> createState() => _StepTimerScreenState();
}

class _StepTimerScreenState extends State<StepTimerScreen> {
  late int _left = widget.minutes * 60;
  Timer? _tick;
  bool _paused = false;
  bool _over = false;
  bool _early = false;
  bool _started = false;
  bool _musicOn = false; // the session really started (not held back in quiet hours)
  AppState? _app;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app ??= AppScope.of(context);
    if (!_started) {
      _started = true;
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _second());
      WidgetsBinding.instance.addPostFrameCallback((_) => _startMusic());
    }
  }

  Future<void> _startMusic() async {
    final r = await _app!.playStepMusic();
    if (!mounted) return;
    setState(() => _musicOn = r == PlayResult.played);
    if (r == PlayResult.quietNeedsHeadphones) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(s.soundQuiet)));
    }
  }

  void _second() {
    if (_paused || _over) return;
    setState(() => _left--);
    if (_left <= 0) _finish(early: false);
  }

  Future<void> _finish({required bool early}) async {
    _tick?.cancel();
    setState(() {
      _over = true;
      _early = early;
      _left = math.max(_left, 0);
    });
    if (early) {
      await _app!.sound.stop();
    } else {
      await _app!.playTimeUpChime();
    }
  }

  Future<void> _togglePause() async {
    final snd = _app!.sound;
    setState(() => _paused = !_paused);
    if (_app!.settings.stepMusic == 'off') return;
    if (_paused) {
      await snd.pause();
    } else {
      await snd.resume();
    }
  }

  Future<void> _answer(CheckinStatus st) async {
    final app = _app!;
    final nav = Navigator.of(context);
    await app.sound.stop();
    await app.checkIn(st);
    nav.pop();
  }

  @override
  void dispose() {
    _tick?.cancel();
    final app = _app;
    if (app != null && !_over) unawaited(app.sound.stop());
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    if (_over) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.leaveTimerQ),
        content: Text(s.leaveTimerBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.keepGoing)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.stopTimer)),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return PopScope(
      canPop: _over,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmLeave()) nav.pop();
      },
      child: BBPage(
        onBack: () async {
          final nav = Navigator.of(context);
          if (await _confirmLeave()) nav.pop();
        },
        body: _over ? _done(context, app) : _running(context, app),
        navBar: NavigationBar(
          key: const Key('timerNavBar'),
          selectedIndex: 0,
          destinations: bbTabs(),
          onDestinationSelected: (i) async {
            final nav = Navigator.of(context);
            if (!await _confirmLeave()) return;
            nav.pop();
            if (i != 0) widget.openTab?.call(i);
          },
        ),
      ),
    );
  }

  Widget _running(BuildContext context, AppState app) {
    final tt = Theme.of(context).textTheme;
    final total = widget.minutes * 60;
    final mm = _left ~/ 60, ss = _left % 60;
    final music = app.settings.stepMusic != 'off';
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: [
      if (habit(app).isNotEmpty) Center(child: CapsLabel(habit(app))),
      const SizedBox(height: 16),
      Center(
        child: SizedBox(
          width: 240,
          height: 240,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: _left / total,
                strokeWidth: 12,
                backgroundColor: BBColors.primaryLight,
                color: BBColors.primary,
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$mm:${ss.toString().padLeft(2, '0')}', key: const Key('timerLeft'), style: heading(52)),
              Text(s.leftOf(widget.minutes), style: tt.bodyMedium),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 20),
      Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 8, children: [
        OutlinedButton.icon(
          key: const Key('timerPause'),
          onPressed: _togglePause,
          icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
          label: Text(_paused ? s.resume : s.pause),
        ),
        OutlinedButton(key: const Key('timerFinish'), onPressed: () => _finish(early: true), child: Text(s.finishNow)),
      ]),
      const SizedBox(height: 20),
      if (music) _NowPlaying(app: app, started: _musicOn, onStart: _startMusic),
      if (music) ...[
        const SizedBox(height: 6),
        Text(s.outdoorsVolume, style: tt.bodySmall, textAlign: TextAlign.center),
      ],
    ]);
  }

  /// "Brisk walk · you can talk but not sing" for walks (HHS talk test), the habit name otherwise.
  String habit(AppState app) {
    final id = app.mainHabit!.id;
    const walks = {'briskWalk', 'walkAfterMeal', 'indoorWalk', 'walkAfterIftar'};
    return walks.contains(id) ? '${s.habit(id)} · ${s.talkNotSing}' : '';
  }

  Widget _done(BuildContext context, AppState app) {
    final tt = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 20), children: [
      const Center(child: Icon(BBIcons.flower, size: 72, color: Color(0xFFF0A868))),
      const SizedBox(height: 12),
      Text(_early ? s.stoppedEarlyTitle : s.timeUpTitle(widget.minutes),
          key: const Key('timerDoneTitle'), textAlign: TextAlign.center, style: heading(26)),
      const SizedBox(height: 4),
      Text(s.howDidItGo, textAlign: TextAlign.center, style: tt.bodyLarge),
      const SizedBox(height: 20),
      PrimaryButton(key: const Key('timerDone'), label: s.checkinDone, icon: Icons.check, onPressed: () => _answer(CheckinStatus.done)),
      const SizedBox(height: 8),
      OutlinedButton(
        key: const Key('timerPartly'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        onPressed: () => _answer(CheckinStatus.partial),
        child: Text(s.checkinPartial),
      ),
      const SizedBox(height: 10),
      Text(s.stoppedEarlyNote, textAlign: TextAlign.center, style: tt.bodySmall),
      if (app.settings.quizPerDay > 0 && app.quizBank.isNotEmpty) ...[
        const SizedBox(height: 24),
        BBCard(
          child: Row(children: [
            const Icon(BBIcons.sprout, color: BBColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.thenQuestion, style: tt.titleSmall),
                Text(s.thenQuestionSub, style: tt.bodySmall),
              ]),
            ),
          ]),
        ),
      ],
    ]);
  }
}

/// Title, "Kevin MacLeod · CC BY 4.0" (the licence asks for credit), pause and next.
class _NowPlaying extends StatelessWidget {
  final AppState app;
  /// Starts the music when nothing is loaded yet (for example it was held back in quiet hours).
  final Future<void> Function() onStart;
  final bool started;
  const _NowPlaying({required this.app, required this.started, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final snd = app.sound;
    return ValueListenableBuilder<String?>(
      valueListenable: snd.nowAsset,
      builder: (context, asset, _) {
        final song = app.settings.stepMusic == 'song';
        // before anything plays (quiet hours): the track the music will start with
        final track = trackOfAsset(asset) ?? (song ? null : musicTrack(app.settings.musicTrack));
        final idx = track == null ? 0 : kMusic.indexOf(track) + 1;
        return BBCard(
          key: const Key('stepNowPlaying'),
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: BBColors.accentLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.music_note_outlined, color: BBColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CapsLabel(song || track == null ? s.nowPlayingSong : s.nowPlayingOf(idx, kMusic.length)),
                Text(song ? (app.settings.songName ?? '') : (track?.title ?? ''),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleSmall),
                if (!song) InkWell(onTap: () => showMusicCredits(context), child: Text(s.musicCreditShort, style: tt.bodySmall)),
              ]),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: snd.playing,
              builder: (context, playing, _) => IconButton(
                key: const Key('musicPause'),
                tooltip: playing ? s.pause : s.resume,
                onPressed: () => playing ? snd.pause() : (started ? snd.resume() : onStart()),
                icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: BBColors.primary),
              ),
            ),
            if (!song)
              IconButton(
                key: const Key('musicNext'),
                tooltip: s.nextTrack,
                onPressed: snd.next,
                icon: const Icon(Icons.skip_next, color: BBColors.primary),
              ),
          ]),
        );
      },
    );
  }
}
