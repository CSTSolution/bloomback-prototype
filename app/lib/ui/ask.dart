// Ask BloomBack: the coach (Pro; three questions free with an account). The question, the ids of the plan's habits,
// the shift type and the language go to our server; the answer comes back with the habits it used and their sources
// (the server attaches them from Chi's list, never the model). A flag reports a bad answer (Google Play's AI rule).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../account/account.dart';
import '../account/api.dart';
import '../l10n/strings.dart';
import 'account_ui.dart';
import 'common.dart';

class AskScreen extends StatefulWidget {
  const AskScreen({super.key});

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _Turn {
  _Turn(this.question);
  final String question;
  CoachAnswer? answer;
  String? problem;
}

class _AskScreenState extends State<AskScreen> {
  final _q = TextEditingController();
  final _turns = <_Turn>[];
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => AppScope.of(context).account.refresh());
  }

  Future<void> _ask([String? preset]) async {
    final app = AppScope.of(context);
    final text = (preset ?? _q.text).trim();
    if (text.length < 3 || _asking) return;
    final turn = _Turn(text);
    setState(() {
      _turns.insert(0, turn);
      _asking = true;
      _q.clear();
    });
    try {
      final plan = app.plan;
      turn.answer = await app.account.ask(
        text,
        habits: plan == null ? const [] : [plan.mainHabitId, ...plan.backupHabitIds].take(6).toList(),
        shift: app.profile?.shift.name,
      );
    } on ApiProblem catch (p) {
      turn.problem = p.words;
      if (p.problem == 'no_asks_left' && mounted) showProSheet(context);
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final account = app.account;
    final tt = Theme.of(context).textTheme;
    final st = account.standing;
    final canAsk = account.signedIn && st.asksLeft > 0 && !_asking;

    return BBPage(
      title: s.askTitle,
      onBack: () => Navigator.pop(context),
      trailing: account.signedIn
          ? Text(st.pro ? s.askLeftPro(st.proAsksLeftToday) : s.askLeftFree(st.freeAsksLeft),
              key: const Key('askLeft'), style: tt.bodySmall)
          : null,
      bottom: !account.signedIn
          ? PrimaryButton(
              key: const Key('askSignIn'),
              label: s.signInWith,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AccountScreen())),
            )
          : Row(children: [
              Expanded(
                child: TextField(
                  key: const Key('askField'),
                  controller: _q,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 400,
                  enabled: !_asking,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(hintText: s.askHint, counterText: ''),
                  onSubmitted: (_) => _ask(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                key: const Key('askSend'),
                tooltip: s.askSend,
                onPressed: canAsk ? _ask : (st.asksLeft == 0 ? () => showProSheet(context) : null),
                icon: const Icon(Icons.arrow_upward),
              ),
            ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
        if (_turns.isEmpty) ...[
          BBCard(
            color: BBColors.primaryLight,
            border: BBColors.primaryBorder,
            child: Text(s.askIntro, style: tt.bodyMedium),
          ),
          if (!account.signedIn) Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.askSignIn, style: tt.bodyMedium)),
          if (account.signedIn) ...[
            const SizedBox(height: 8),
            for (final q in [s.askSamples1, s.askSamples2, s.askSamples3])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ActionChip(label: Text(q), onPressed: canAsk ? () => _ask(q) : null),
              ),
          ],
          const SizedBox(height: 8),
          Text(s.askPrivacy, style: tt.bodySmall),
        ],
        if (_asking)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Text(s.askThinking, style: tt.bodyMedium),
            ]),
          ),
        for (final t in _turns) _TurnCard(turn: t),
      ]),
    );
  }
}

class _TurnCard extends StatelessWidget {
  const _TurnCard({required this.turn});
  final _Turn turn;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final a = turn.answer;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: BBColors.primary, borderRadius: BorderRadius.circular(16)),
          child: Text(turn.question, style: tt.bodyMedium?.copyWith(color: Colors.white)),
        ),
      ),
      if (turn.problem != null)
        BBCard(child: Text(turn.problem!, key: const Key('askProblem'), style: tt.bodyMedium?.copyWith(color: BBColors.accent))),
      if (a != null)
        BBCard(
          key: const Key('askAnswer'),
          color: a.kind == 'see_doctor' ? BBColors.accentLight : Colors.white,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (a.kind == 'see_doctor') ...[
              Text(s.askSeeDoctor, style: tt.titleSmall),
              const SizedBox(height: 4),
            ],
            Text(a.text, style: tt.bodyMedium),
            if (a.habits.isNotEmpty) ...[
              const SizedBox(height: 10),
              CapsLabel(s.askHabitsUsed),
              const SizedBox(height: 4),
              for (final h in a.habits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    onTap: h.link == null
                        ? null
                        : () async {
                            await Clipboard.setData(ClipboardData(text: h.link!));
                            if (context.mounted) {
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(s.linkCopied(h.link!))));
                            }
                          },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: BBColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(h.title, style: tt.titleSmall),
                        Text('${s.source}: ${h.source}', style: tt.bodySmall),
                      ]),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(a.note, style: tt.bodySmall)),
              IconButton(
                key: const Key('reportAnswer'),
                tooltip: s.reportAnswer,
                icon: const Icon(Icons.flag_outlined, size: 20, color: BBColors.muted),
                onPressed: () => _report(context, a),
              ),
            ]),
          ]),
        ),
    ]);
  }
}

Future<void> _report(BuildContext context, CoachAnswer a) {
  final account = AppScope.of(context).account;
  String? reason;
  var withAnswer = false;
  final note = TextEditingController();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(sheet).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.reportAnswer, style: Theme.of(sheet).textTheme.titleLarge),
          RadioGroup<String>(
            groupValue: reason,
            onChanged: (v) => set(() => reason = v),
            child: Column(children: [
              for (final (id, label) in [('harmful', s.reportHarmful), ('wrong', s.reportWrong), ('other', s.reportOther)])
                RadioListTile<String>(contentPadding: EdgeInsets.zero, value: id, title: Text(label)),
            ]),
          ),
          TextField(controller: note, maxLength: 500, decoration: InputDecoration(labelText: s.reportNote)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: withAnswer,
            onChanged: (v) => set(() => withAnswer = v),
            title: Text(s.reportIncludeAnswer),
          ),
          PrimaryButton(
            label: s.reportSend,
            onPressed: reason == null
                ? null
                : () async {
                    try {
                      await account.report(reason: reason!, note: note.text, answer: withAnswer ? a.text : null);
                      if (sheet.mounted) Navigator.pop(sheet);
                      if (context.mounted) {
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(s.reportThanks)));
                      }
                    } on ApiProblem catch (p) {
                      if (context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(p.words)));
                    }
                  },
          ),
        ]),
      ),
    ),
  );
}
