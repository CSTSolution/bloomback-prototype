// After the small step (Chi, thread 0007; design A-D in docs/design/new-features-2026-11-15.pdf):
// A  Today after Done or Partly: the "Now playing" card (if a sound is on) and the "Today's question" card.
// B  The question: 3-4 choices, no score; "Skip" anytime.
// C  The answer: the right choice has a check mark; the user's other pick only says "your answer" (never red);
//    "Good to know" in the source's words, its sources under "?", and the "ask your doctor" line for numbers.
// D  More › After my small step: Sound (Off / Chime / My song), Daily question (Off / 1 / 2 / 3), research switch.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../l10n/strings.dart';
import '../platform/song_file.dart';
import '../rules/quiz.dart';
import '../sound/after_sound.dart';
import 'common.dart';

/// Plays the chosen sound after Done or Partly and says why when it can't.
Future<void> playAfterStep(BuildContext context, AppState app) async {
  final msg = ScaffoldMessenger.maybeOf(context);
  final r = await app.playAfterStep();
  if (r == PlayResult.quietNeedsHeadphones) {
    msg?.hideCurrentSnackBar();
    msg?.showSnackBar(SnackBar(content: Text(s.soundQuiet)));
  } else if (r == PlayResult.failed) {
    msg?.hideCurrentSnackBar();
    msg?.showSnackBar(SnackBar(content: Text(s.soundFailed)));
  }
}

/// Design A: shown on Today under the step card once the step is Done or Partly.
class AfterStepCards extends StatelessWidget {
  final AppState app;
  const AfterStepCards({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    if (!app.didStepToday) return const SizedBox.shrink();
    final st = app.settings;
    final q = app.nextQuiz;
    final tt = Theme.of(context).textTheme;
    final soundOn = st.sound == 'chime' || st.sound == 'music' || (st.sound == 'song' && st.songPath != null);
    return Column(children: [
      if (soundOn)
        BBCard(
          key: const Key('nowPlayingCard'),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
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
                CapsLabel(switch (st.sound) { 'song' => s.nowPlayingSong, 'music' => s.nowPlayingMusic, _ => s.nowPlayingChime }),
                Text(
                    switch (st.sound) {
                      'song' => st.songName ?? '',
                      'music' => musicTrack(st.musicTrack).title,
                      _ => s.chimeName(st.chime),
                    },
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall),
                if (st.sound == 'music')
                  InkWell(
                    key: const Key('musicCredit'),
                    onTap: () => showMusicCredits(context),
                    child: Text(s.musicCreditShort, style: tt.bodySmall),
                  ),
              ]),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: app.sound.playing,
              builder: (context, playing, _) => IconButton.filled(
                key: const Key('playPause'),
                tooltip: playing ? 'Pause' : s.playSample,
                onPressed: () => playing ? app.sound.stop() : playAfterStep(context, app),
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              ),
            ),
          ]),
        ),
      if (q != null)
        BBCard(
          key: const Key('quizCard'),
          border: BBColors.primaryBorder,
          onTap: () => openQuiz(context, app),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.help_outline, color: BBColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.todaysQuestion, style: tt.titleSmall),
                Text(s.todaysQuestionSub(app.quizLeftToday), style: tt.bodySmall),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              TextButton(key: const Key('quizOpen'), onPressed: () => openQuiz(context, app), child: Text(s.open)),
              TextButton(
                key: const Key('quizSkipToday'),
                onPressed: app.skipQuizToday,
                style: TextButton.styleFrom(foregroundColor: BBColors.muted),
                child: Text(s.skipToday),
              ),
            ]),
          ]),
        ),
    ]);
  }
}

void openQuiz(BuildContext context, AppState app) {
  final q = app.nextQuiz;
  if (q == null) return;
  // The "Saved" note from Done would sit over the Check button.
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => QuizScreen(question: q)));
}

/// Designs B and C.
class QuizScreen extends StatefulWidget {
  final QuizQuestion question;
  const QuizScreen({super.key, required this.question});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int? _picked;
  bool _checked = false;

  QuizQuestion get q => widget.question;

  Future<void> _check(AppState app) async {
    setState(() => _checked = true);
    await app.quizAnswered(q.id);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    final next = _checked ? app.nextQuiz : null;
    Widget choice(int i) {
      final right = i == q.answer;
      final mine = i == _picked;
      final Color fill, edge;
      Widget? trailing;
      if (!_checked) {
        fill = mine ? BBColors.primaryLight : Colors.white;
        edge = mine ? BBColors.primary : BBColors.line;
      } else if (right) {
        fill = BBColors.primaryLight;
        edge = BBColors.primary;
        trailing = const Icon(Icons.check, color: BBColors.primary, size: 20);
      } else if (mine) {
        // the user's other pick: no red, no "wrong" (Chi's rule)
        fill = BBColors.accentLight;
        edge = const Color(0xFFF2DFAE);
        trailing = Text(s.yourAnswer, style: tt.bodySmall);
      } else {
        fill = Colors.white;
        edge = BBColors.line;
      }
      return BBCard(
        key: Key('quizChoice_$i'),
        color: fill,
        border: edge,
        borderWidth: (!_checked && mine) || (_checked && right) ? 1.6 : 1,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: _checked ? null : () => setState(() => _picked = i),
        child: Semantics(
          selected: mine,
          child: Row(children: [
            Expanded(child: OrgText(q.choices[i], style: tt.bodyLarge)),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ]),
        ),
      );
    }

    return BBPage(
      onBack: () => Navigator.of(context).pop(),
      trailing: _checked
          ? null
          : TextButton(
              key: const Key('quizSkip'),
              onPressed: () async {
                final nav = Navigator.of(context);
                await app.skipQuizToday();
                nav.pop();
              },
              child: Text(s.skip),
            ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
        CapsLabel(s.quizLabel(q.topic.name)),
        const SizedBox(height: 6),
        OrgText(q.question, key: const Key('quizQuestion'), style: heading(21)),
        if (!_checked) ...[
          const SizedBox(height: 6),
          Text(s.quizNoScore, style: tt.bodySmall),
        ],
        const SizedBox(height: 10),
        if (!_checked)
          for (var i = 0; i < q.choices.length; i++) choice(i)
        else ...[
          // design C: the answer first, then the user's other pick
          choice(q.answer),
          if (_picked != null && _picked != q.answer) choice(_picked!),
        ],
        if (_checked) ...[
          BBCard(
            key: const Key('goodToKnow'),
            color: BBColors.accentLight,
            border: const Color(0xFFF2DFAE),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CapsLabel(s.goodToKnow, color: BBColors.accent),
              const SizedBox(height: 4),
              OrgText(q.explanation, style: tt.bodyMedium),
              const SizedBox(height: 8),
              InkWell(
                key: const Key('quizSources'),
                onTap: () => showQuizSources(context, q),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  WhyButton(title: q.question, source: '', onTap: () => showQuizSources(context, q)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(q.sources.map((x) => x.title).join(' · '), style: tt.bodySmall),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          if (q.askDoctor)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(s.askDoctorLine, key: const Key('askDoctorLine'), style: tt.bodyMedium),
            ),
        ],
      ]),
      bottom: _checked
          ? PrimaryButton(
              key: const Key('quizDone'),
              label: next != null ? s.nextQuestion : s.backToGarden,
              onPressed: () {
                if (next != null) {
                  Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => QuizScreen(question: next)));
                } else {
                  Navigator.of(context).pop();
                }
              },
            )
          : PrimaryButton(
              key: const Key('quizCheck'),
              label: s.check,
              onPressed: _picked == null ? null : () => _check(app),
            ),
    );
  }
}

/// The "?" under a question's answer: every official source with its link.
Future<void> showQuizSources(BuildContext context, QuizQuestion q) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) {
        final tt = Theme.of(c).textTheme;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.source, style: tt.titleLarge),
              for (final src in q.sources)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: const BoxDecoration(
                    color: BBColors.primaryLight,
                    border: Border(left: BorderSide(color: BBColors.primary, width: 3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(src.title, style: tt.titleSmall),
                    OrgNotes(src.title),
                    const SizedBox(height: 4),
                    SelectableText(src.url, style: tt.bodySmall),
                    TextButton.icon(
                      onPressed: () async {
                        // No browser plugin in the app: the link is copied to open anywhere.
                        await Clipboard.setData(ClipboardData(text: src.url));
                        if (c.mounted) {
                          ScaffoldMessenger.maybeOf(c)?.showSnackBar(SnackBar(content: Text(s.linkCopied(src.url))));
                        }
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: Text(s.openSource),
                    ),
                  ]),
                ),
              const SizedBox(height: 12),
              Text(kNotMedicalAdviceShort, style: tt.bodySmall),
            ]),
          ),
        );
      },
    );

const kNotMedicalAdviceShort = 'General health knowledge, not medical advice. For your own health, ask your doctor.';

/// "?" next to the research switch: what is shared, with whom, why (Chi, thread 0007).
Future<void> showResearchWhy(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.researchWhyTitle, style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(s.researchWhy),
              const SizedBox(height: 16),
              PrimaryButton(label: s.ok, onPressed: () => Navigator.pop(c)),
            ]),
          ),
        ),
      ),
    );

/// The research switch row with its "?" (onboarding screen 3, More › What we use, design D).
class ResearchSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const ResearchSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.researchChoice, style: tt.titleSmall),
          Text(s.researchChoiceSub, style: tt.bodySmall),
        ]),
      ),
      WhyButton(
        key: const Key('researchWhy'),
        title: s.researchChoice,
        source: '',
        onTap: () => showResearchWhy(context),
      ),
      Switch(key: const Key('choice_research'), value: value, onChanged: onChanged),
    ]);
  }
}

/// Design D: More › After my small step.
class AfterStepScreen extends StatelessWidget {
  const AfterStepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final st = app.settings;
    final tt = Theme.of(context).textTheme;
    Future<void> save(void Function() f) async {
      f();
      await app.saveSettings(st);
    }

    Widget chip(String key, String label, bool on, VoidCallback onTap) => ChoiceChip(
          key: Key(key),
          label: Text(label),
          selected: on,
          showCheckmark: false,
          onSelected: (_) => onTap(),
        );

    Future<void> pick() async {
      final r = await pickSong(replacing: st.songPath);
      if (r == null) return;
      await save(() {
        st.songPath = r.$1;
        st.songName = r.$2;
        st.sound = 'song';
      });
    }

    return BBPage(
      title: s.afterStepTitle,
      onBack: () => Navigator.of(context).pop(),
      body: ListView(padding: const EdgeInsets.fromLTRB(0, 0, 0, 16), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Text(s.afterStepBody, style: tt.bodyMedium),
        ),
        SectionCard(
          title: s.soundTitle,
          children: [
            Wrap(spacing: 8, runSpacing: 6, children: [
              chip('sound_off', s.soundOff, st.sound == 'off', () async {
                await app.sound.stop();
                await save(() => st.sound = 'off');
              }),
              chip('sound_chime', s.soundChime, st.sound == 'chime', () => save(() => st.sound = 'chime')),
              chip('sound_music', s.soundMusic, st.sound == 'music', () => save(() => st.sound = 'music')),
              chip('sound_song', s.soundSong, st.sound == 'song', () async {
                if (st.songPath == null) {
                  if (songPickerAvailable) await pick();
                } else {
                  await save(() => st.sound = 'song');
                }
              }),
            ]),
            if (st.sound == 'chime') ...[
              const SizedBox(height: 8),
              for (final id in kChimes.keys)
                RadioCard(
                  key: Key('chime_$id'),
                  selected: st.chime == id,
                  title: s.chimeName(id),
                  onTap: () => save(() => st.chime = id),
                  trailing: IconButton(
                    tooltip: s.playSample,
                    icon: const Icon(Icons.play_circle_outline, color: BBColors.primary),
                    onPressed: () async {
                      await save(() => st.chime = id);
                      if (context.mounted) await playAfterStep(context, app);
                    },
                  ),
                ),
            ],
            if (st.sound == 'music') ...[
              const SizedBox(height: 8),
              _TrackList(
                selected: st.musicTrack,
                onSelect: (id) => save(() => st.musicTrack = id),
                onPlay: (id) async {
                  await save(() => st.musicTrack = id);
                  if (context.mounted) await playAfterStep(context, app);
                },
              ),
              const SizedBox(height: 4),
              Text(s.musicNote, style: tt.bodySmall),
              _CreditRow(),
            ],
            if (st.sound == 'song' || !songPickerAvailable) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                decoration: BoxDecoration(color: BBColors.background, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      !songPickerAvailable
                          ? s.songWeb
                          : (st.songName == null ? s.songNone : s.songFromPhone(st.songName!)),
                      key: const Key('songName'),
                      style: tt.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (songPickerAvailable)
                    TextButton(
                      key: const Key('songChange'),
                      onPressed: pick,
                      child: Text(st.songPath == null ? s.songPick : s.songChange),
                    ),
                ]),
              ),
              if (songPickerAvailable) ...[
                const SizedBox(height: 6),
                Text(s.songNote, style: tt.bodySmall),
              ],
            ],
            const SizedBox(height: 6),
            Text(s.soundRules, style: tt.bodySmall),
          ],
        ),
        SectionCard(
          title: s.stepMusicTitle,
          children: [
            Text(s.stepMusicBody, style: tt.bodySmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              chip('stepMusic_off', s.stepMusicOff, st.stepMusic == 'off', () => save(() => st.stepMusic = 'off')),
              chip('stepMusic_music', s.soundMusic, st.stepMusic == 'music', () => save(() => st.stepMusic = 'music')),
              if (songPickerAvailable)
                chip('stepMusic_song', s.soundSong, st.stepMusic == 'song', () async {
                  if (st.songPath == null) await pick();
                  if (st.songPath != null) await save(() => st.stepMusic = 'song');
                }),
            ]),
            if (st.stepMusic == 'music') _CreditRow(),
            const SizedBox(height: 6),
            Text(s.soundRules, style: tt.bodySmall),
          ],
        ),
        SectionCard(
          title: s.quizTitle,
          children: [
            Wrap(spacing: 8, runSpacing: 6, children: [
              chip('quiz_0', s.quizOff, st.quizPerDay == 0, () => save(() => st.quizPerDay = 0)),
              for (final n in [1, 2, 3])
                chip('quiz_$n', s.quizChip(n), st.quizPerDay == n, () => save(() => st.quizPerDay = n)),
            ]),
            const SizedBox(height: 6),
            Text(s.quizSettingsNote, style: tt.bodySmall),
          ],
        ),
        Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 2), child: CapsLabel(s.yourData)),
        SectionCard(children: [
          ResearchSwitch(
            value: app.choices['research'] == true,
            onChanged: (v) => app.saveChoices({...app.choices, 'research': v}),
          ),
        ]),
      ]),
    );
  }
}


/// The 9 BloomBack tracks with their length and a play button.
class _TrackList extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onPlay;
  const _TrackList({required this.selected, required this.onSelect, required this.onPlay});

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final m in kMusic)
          RadioCard(
            key: Key('track_${m.id}'),
            selected: selected == m.id,
            title: m.title,
            subtitle: s.trackLength(m.seconds),
            onTap: () => onSelect(m.id),
            trailing: IconButton(
              tooltip: s.playSample,
              icon: const Icon(Icons.play_circle_outline, color: BBColors.primary),
              onPressed: () => onPlay(m.id),
            ),
          ),
      ]);
}

/// "Music: Kevin MacLeod · CC BY 4.0" with "?" for every track's full credit.
class _CreditRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(s.musicCreditShort, style: Theme.of(context).textTheme.bodySmall)),
        WhyButton(key: const Key('musicCreditsWhy'), title: s.musicCreditTitle, source: '', onTap: () => showMusicCredits(context)),
      ]);
}

/// The credit CC BY 4.0 asks for, for every track (Chi's wording, thread 0007).
Future<void> showMusicCredits(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) {
        final tt = Theme.of(c).textTheme;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.85),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.musicCreditTitle, style: tt.titleLarge),
                const SizedBox(height: 6),
                Text(s.musicCreditBody, style: tt.bodyMedium),
                const SizedBox(height: 8),
                for (final m in kMusic)
                  Padding(padding: const EdgeInsets.only(top: 6), child: SelectableText(m.credit, style: tt.bodySmall)),
              ]),
            ),
          ),
        );
      },
    );
