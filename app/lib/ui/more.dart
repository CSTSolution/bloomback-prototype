// More tab (Chi's screen 22) and the screens behind it: reminders, someone to cheer
// you on (16), Ramadan (17), band (23-24), language, what we use, download my data
// (FHIR), delete everything, sources, about, and the demo tools.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../l10n/strings.dart';
import '../rules/biomarkers.dart';
import '../rules/environment.dart';
import '../rules/goals.dart';
import '../rules/habits.dart';
import '../rules/levels.dart';
import '../rules/plan.dart';
import '../rules/regularity.dart';
import '../rules/reminders.dart';
import '../rules/sources.dart';
import 'account_ui.dart';
import 'after_step.dart';
import 'ask.dart';
import 'band_screen.dart';
import 'common.dart';
import 'demo.dart';
import 'four_weeks.dart';
import 'health_numbers.dart';
import 'onboarding.dart';
import 'today.dart';
import 'your_day.dart';

Future<int?> _editNumber(BuildContext context, String label, int? current, String unit, int lo, int hi) async {
  final c = TextEditingController(text: current == null ? '' : '$current');
  return showDialog<int>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
        decoration: InputDecoration(suffixText: unit, helperText: '$lo-$hi'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: Text(s.cancel)),
        FilledButton(
          onPressed: () {
            final x = int.tryParse(c.text.trim());
            if (x != null && x >= lo && x <= hi) Navigator.pop(d, x);
          },
          child: Text(s.ok),
        ),
      ],
    ),
  );
}

void _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  const _Row({super.key, required this.icon, required this.title, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(icon, color: BBColors.primary),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: subtitle == null ? null : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right, color: BBColors.muted),
        onTap: onTap,
      );
}

Widget _group(List<Widget> rows) => BBCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(indent: 56), rows[i]],
      ]),
    );

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    final st = app.settings;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      Text(s.moreTitle, style: tt.headlineSmall),
      const SizedBox(height: 8),
      _group([
        _Row(
          key: const Key('more_account'),
          icon: Icons.person_outline,
          title: s.accountRow,
          subtitle: app.account.signedIn
              ? s.accountRowIn(app.account.view?.name?.isNotEmpty == true ? app.account.view!.name! : app.account.view?.email ?? '')
              : (app.displayName.isNotEmpty ? s.notSignedInName(app.displayName) : s.accountRowOut),
          onTap: () => _push(context, const AccountScreen()),
        ),
        _Row(
          key: const Key('more_ask'),
          icon: Icons.chat_bubble_outline,
          title: s.askTitle,
          subtitle: s.askRowSub,
          onTap: () => _push(context, const AskScreen()),
        ),
      ]),
      const SizedBox(height: 4),
      _group([
        _Row(
          key: const Key('more_reminders'),
          icon: Icons.notifications_none,
          title: s.remindersRow,
          subtitle: s.remindersRowSub,
          onTap: () => _push(context, const RemindersScreen()),
        ),
        _Row(
          key: const Key('more_afterStep'),
          icon: Icons.music_note_outlined,
          title: s.afterStepTitle,
          subtitle: s.afterStepRow(st.sound, st.quizPerDay),
          onTap: () => _push(context, const AfterStepScreen()),
        ),
        _Row(
          key: const Key('more_companion'),
          icon: Icons.people_outline,
          title: s.companionTitle,
          subtitle: s.notInvited,
          onTap: () => _push(context, const CompanionScreen()),
        ),
        _Row(
          key: const Key('more_ramadan'),
          icon: Icons.nightlight_outlined,
          title: s.ramadanTitle,
          subtitle: app.fasting == null ? s.fastingOff : s.fastingOnText(app.fasting!.from, app.fasting!.to),
          onTap: () => _push(context, const RamadanScreen()),
        ),
        _Row(
          key: const Key('more_band'),
          icon: Icons.watch_outlined,
          title: s.bandRow,
          subtitle: st.bandId == null ? s.notConnected : '${s.connected} · ${st.bandName ?? ''}',
          onTap: () => _push(context, const BandScreen()),
        ),
        _Row(
          key: const Key('more_bandSleep'),
          icon: Icons.bedtime_outlined,
          title: s.bandSleepRow,
          subtitle: s.bandSleepRowSub,
          onTap: () => _push(context, const BandSleepScreen(fromTab: 3)),
        ),
        _Row(
          key: const Key('more_myShifts'),
          icon: Icons.calendar_view_week_outlined,
          title: s.myShiftsTitle,
          subtitle: s.myShiftsBody,
          onTap: () => _push(context, const MyShiftsScreen(fromTab: 3)),
        ),
        _Row(
          key: const Key('more_language'),
          icon: Icons.language,
          title: s.languageRow,
          subtitle: s.english,
          onTap: () => showLanguageSheet(context),
        ),
      ]),
      Padding(padding: const EdgeInsets.fromLTRB(4, 10, 4, 2), child: CapsLabel(s.yourData)),
      _group([
        _Row(
          key: const Key('more_whatWeUse'),
          icon: Icons.lock_outline,
          title: s.whatWeUse,
          subtitle: s.whatWeUseSub,
          onTap: () => _push(context, const WhatWeUseScreen()),
        ),
        _Row(
          key: const Key('more_download'),
          icon: Icons.download_outlined,
          title: s.downloadData,
          subtitle: s.downloadDataSub,
          onTap: () async {
            if (app.days.isEmpty && app.checkins.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.noDataYet)));
              return;
            }
            await app.exportFhir();
          },
        ),
        _Row(
          key: const Key('more_delete'),
          icon: Icons.delete_outline,
          title: s.deleteEverything,
          subtitle: s.deleteEverythingSub,
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text(s.deleteEverything),
                content: Text(s.deleteEverythingQ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.deleteEverything)),
                ],
              ),
            );
            if (ok == true) await app.deleteEverything();
          },
        ),
      ]),
      const SizedBox(height: 6),
      _group([
        _Row(
          key: const Key('more_sources'),
          icon: Icons.menu_book_outlined,
          title: s.sourcesRow,
          subtitle: s.sourcesRowSub,
          onTap: () => _push(context, const SourcesScreen()),
        ),
        _Row(
          key: const Key('more_about'),
          icon: Icons.info_outline,
          title: s.aboutRow,
          subtitle: s.aboutRowSub,
          onTap: () => _push(context, const AboutScreen()),
        ),
      ]),
      Padding(padding: const EdgeInsets.fromLTRB(4, 10, 4, 2), child: CapsLabel(s.demoSection)),
      _group([
        SwitchListTile(
          key: const Key('fakeBandSwitch'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text(s.fakeBand, style: tt.titleSmall),
          subtitle: Text(kWebDemo ? s.webDemoBandOnly : s.fakeBandHint, style: tt.bodySmall),
          value: st.useFakeBand,
          onChanged: kWebDemo ? null : (v) => app.saveSettings(Settings.fromJson(st.toJson())..useFakeBand = v),
        ),
        if (st.useFakeBand)
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: ScenarioTile()),
      ]),
    ]);
  }
}

Future<void> showLanguageSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.languageRow, style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 8),
            RadioCard(selected: true, title: s.english, onTap: () => Navigator.pop(c)),
            RadioCard(
              selected: false,
              title: s.arabic,
              subtitle: s.arabicSoonTitle,
              onTap: () {
                Navigator.pop(c);
                showArabicSoon(context);
              },
            ),
          ]),
        ),
      ),
    );

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final st = app.settings;
    final p = app.profile!;
    final tt = Theme.of(context).textTheme;
    Future<void> update(void Function(Settings x) f) async {
      final n = Settings.fromJson(st.toJson());
      f(n);
      await app.saveSettings(n);
    }

    Widget timeTile(String label, int value, void Function(Settings, int) set, {bool canTurnOff = false}) {
      final quiet = value >= 0 && inQuiet(value, st.quietStart, st.quietEnd);
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: quiet && canTurnOff ? Text(s.reminderInQuiet, style: tt.bodySmall) : null,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          TextButton(
            onPressed: () async {
              final t = await pickTime(context, value);
              if (t != null) await update((x) => set(x, t));
            },
            child: Text(hhmm(value)),
          ),
          if (canTurnOff && value >= 0)
            IconButton(
              tooltip: s.off,
              icon: const Icon(Icons.notifications_off_outlined),
              onPressed: () => update((x) => set(x, -1)),
            ),
        ]),
      );
    }

    final irregular = p.shift == ShiftType.irregular;
    return BBPage(
      title: s.remindersRow,
      onBack: () => Navigator.of(context).pop(),
      body: ListView(padding: const EdgeInsets.fromLTRB(0, 4, 0, 16), children: [
        SectionCard(
          title: s.reminders,
          trailing: WhyButton(
            title: s.reminders,
            source: 'BloomBack rules C4: at most 2 reminders a day, never in sleep hours, no '
                'catch-up if one was missed; quiet hours follow the shift (B6, ILO Convention 171).',
          ),
          children: [
            if (kWebDemo) Text(s.webNoReminders, key: const Key('webNoReminders'), style: tt.bodySmall),
            if (irregular) ...[
              Text(s.remindersFollowCheckins, style: tt.bodySmall),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.irregularGap),
                trailing: TextButton(
                  onPressed: () async {
                    final h = await _editNumber(context, s.irregularGap, st.irregularGapMinutes ~/ 60, s.hoursUnit, 1, 12);
                    if (h != null) await update((x) => x.irregularGapMinutes = h * 60);
                  },
                  child: Text(s.hours(st.irregularGapMinutes)),
                ),
              ),
              Row(children: [
                Expanded(child: Text(s.irregularNote, style: tt.bodySmall)),
                WhyButton(title: s.irregularGap, source: kIrregularSource),
              ]),
            ] else ...[
              timeTile(s.reminder1, st.reminder1, (x, t) => x.reminder1 = t, canTurnOff: true),
              timeTile(s.reminder2, st.reminder2, (x, t) => x.reminder2 = t, canTurnOff: true),
            ],
            const Divider(),
            Text(s.quietHours, style: tt.titleSmall),
            timeTile(s.quietFrom, st.quietStart, (x, t) => x.quietStart = t),
            timeTile(s.quietTo, st.quietEnd, (x, t) => x.quietEnd = t),
            timeTile(s.dayEnd, st.dayEnd, (x, t) => x.dayEnd = t),
            if (p.shift == ShiftType.longOrSplit)
              timeTile(s.obBreakQ, st.breakMinute, (x, t) => x.breakMinute = t, canTurnOff: true),
          ],
        ),
      ]),
    );
  }
}

class WhatWeUseScreen extends StatelessWidget {
  const WhatWeUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = app.profile!;
    final tt = Theme.of(context).textTheme;
    Future<void> updateProfile(void Function(Profile x) f) async {
      final n = p.copy();
      f(n);
      await app.saveProfile(n);
    }

    Widget toggle(String title, String sub, bool value) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: tt.titleSmall),
          subtitle: Text(sub, style: tt.bodySmall),
          value: value,
          onChanged: null,
        );
    return BBPage(
      title: s.whatWeUse,
      onBack: () => Navigator.of(context).pop(),
      body: ListView(padding: const EdgeInsets.fromLTRB(0, 4, 0, 16), children: [
        SectionCard(title: s.choicesTitle, children: [
          toggle(s.useAnswers, '${s.useAnswersSub}. ${s.deleteEverythingSub}: More > ${s.deleteEverything}.',
              app.choices['useAnswers'] == true),
          toggle(s.syncChoice, s.syncChoiceSub, false),
          toggle(s.shareChoice, s.shareChoiceSub, false),
          ResearchSwitch(
            value: app.choices['research'] == true,
            onChanged: (v) => app.saveChoices({...app.choices, 'research': v}),
          ),
          const SizedBox(height: 6),
          Text(s.choicesNote, style: tt.bodySmall),
          const SizedBox(height: 4),
          Text(s.retention, style: tt.bodySmall),
        ]),
        SectionCard(title: s.yourAnswers, children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.nameQ),
            trailing: TextButton(
              key: const Key('editName'),
              onPressed: () async {
                final c = TextEditingController(text: app.displayName);
                final v = await showDialog<String>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: Text(s.nameQ),
                    content: TextField(
                      controller: c,
                      maxLength: 30,
                      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[0-9@]'))],
                      decoration: InputDecoration(hintText: s.nameHint, helperText: s.nameNote, helperMaxLines: 3),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d), child: Text(s.cancel)),
                      FilledButton(onPressed: () => Navigator.pop(d, c.text), child: Text(s.save)),
                    ],
                  ),
                );
                if (v != null) await app.saveName(v);
              },
              child: Text(app.displayName.isEmpty ? s.notSet : app.displayName),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.obHeightQ),
            trailing: TextButton(
              onPressed: () async {
                final v = await _editNumber(context, s.obHeightQ, p.heightCm, s.cm, 100, 250);
                if (v != null) await updateProfile((x) => x.heightCm = v);
              },
              child: Text(p.heightCm == null ? s.notSet : '${p.heightCm} ${s.cm}'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.obWeightQ),
            trailing: TextButton(
              onPressed: () async {
                final v = await _editNumber(context, s.obWeightQ, p.weightKg, s.kg, 30, 300);
                if (v != null) await updateProfile((x) => x.weightKg = v);
              },
              child: Text(p.weightKg == null ? s.notSet : '${p.weightKg} ${s.kg}'),
            ),
          ),
          Text(s.obCityQ, style: tt.titleSmall),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final c in City.values)
              PillChip(label: s.cityLabel(c), selected: p.city == c, onTap: () => updateProfile((x) => x.city = c)),
          ]),
          if (p.shift == ShiftType.rotating)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.obNextNightsQ),
              trailing: TextButton(
                onPressed: () async {
                  final now = app.clock();
                  final d = await showDatePicker(
                    context: context,
                    initialDate: now.add(const Duration(days: 3)),
                    firstDate: DateTime(now.year, now.month, now.day),
                    lastDate: now.add(const Duration(days: 120)),
                  );
                  if (d != null) await updateProfile((x) => x.nextNightsDate = dateKey(d));
                },
                child: Text(s.dateK(p.nextNightsDate)),
              ),
            ),
          if (p.activity == WorkActivity.moderate)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.workBrisk),
              subtitle: Text(s.obWorkBriskHint, style: tt.bodySmall),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton(
                  onPressed: () async {
                    final v = await _editNumber(context, s.workBrisk, p.workBriskMinutes, 'min', 0, 2000);
                    if (v != null) await updateProfile((x) => x.workBriskMinutes = v);
                  },
                  child: Text('${p.workBriskMinutes} min'),
                ),
                WhyButton(title: s.workBrisk, source: kWorkCreditSource),
              ]),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.monitor_heart_outlined),
            title: Text(s.bioTitle),
            onTap: () => _push(context, const HealthNumbersScreen()),
          ),
          ListTile(
            key: const Key('changePlan'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_outlined),
            title: Text(s.changePlan),
            onTap: () => openChangePlan(context),
          ),
        ]),
      ]),
    );
  }
}

/// Someone to cheer you on (screen 16). Sharing needs a server: the invite explains
/// "available in the pilot" and nothing is stored.
class CompanionScreen extends StatefulWidget {
  const CompanionScreen({super.key});

  @override
  State<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends State<CompanionScreen> {
  final _name = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    Widget item(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [Icon(icon, size: 18, color: BBColors.primary), const SizedBox(width: 8), Expanded(child: Text(text))]),
        );
    return BBPage(
      title: s.companionTitle,
      onBack: () => Navigator.of(context).pop(),
      bottom: PrimaryButton(
        key: const Key('sendInvite'),
        label: s.sendInvite,
        icon: Icons.link,
        onPressed: () => showPilotSheet(context, s.sharingPilot, s.invitePilotBody),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
        Text(s.inviteOne, style: tt.headlineSmall),
        const SizedBox(height: 4),
        Text(s.inviteBody, style: tt.bodyMedium?.copyWith(color: BBColors.muted)),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          maxLength: 30,
          decoration: InputDecoration(labelText: s.companionName, hintText: s.companionNameHint, counterText: ''),
        ),
        BBCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.theyWillSee, style: tt.titleSmall?.copyWith(color: BBColors.primary)),
            item(Icons.check, s.seeDone),
            item(Icons.check, s.seeBack(app.displayName)),
          ]),
        ),
        BBCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.neverSee, style: tt.titleSmall),
            item(Icons.visibility_off_outlined, s.neverMissed),
            item(Icons.visibility_off_outlined, s.neverNumbers),
          ]),
        ),
        BBCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.sharingOn, style: tt.titleSmall),
            subtitle: Text(s.sharingPilot, style: tt.bodySmall),
            value: false,
            onChanged: null,
          ),
        ),
        Text(s.cheerNote, style: tt.bodySmall),
      ]),
    );
  }
}

/// Ramadan (screen 17): Umm al-Qura dates suggested, the user confirms or picks
/// other dates; fasting mode on/off. Only "on, from - to" is stored, never a religion.
class RamadanScreen extends StatefulWidget {
  const RamadanScreen({super.key});

  @override
  State<RamadanScreen> createState() => _RamadanScreenState();
}

class _RamadanScreenState extends State<RamadanScreen> {
  bool _init = false;
  DateTime? _from, _to;
  bool _on = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final app = AppScope.of(context);
    final f = app.fasting;
    final sug = suggestedRamadan(app.clock(), app.profile?.city);
    _from = f == null ? sug?.from : parseDateKey(f.from);
    _to = f == null ? sug?.to : parseDateKey(f.to);
    _on = f != null;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    final city = app.profile?.city;
    final place = city == null || city == City.other || city == City.otherUae ? 'the UAE' : s.cityLabel(city);
    // "Your step during Ramadan": today's rules on a fasting day (habit 21 for walks).
    String? step;
    if (_from != null && _to != null && app.profile != null && app.plan != null) {
      final r = dayRules(
        profile: app.profile!,
        plan: app.plan!,
        settings: app.settings,
        fasting: FastingMode(dateKey(_from!), dateKey(_to!)),
        date: _from!,
      );
      step = s.habit(r.habitId);
      final h = habitById(r.habitId);
      if (h.area == HabitArea.movement && h.kind == HabitKind.main && h.id != 'standUp') {
        final mt = movementTarget(app.plan!);
        step = '$step · ${s.walkDose(mt.perSession, mt.sessions)}';
      }
    }
    return BBPage(
      title: s.ramadanTitle,
      onBack: () => Navigator.of(context).pop(),
      bottom: PrimaryButton(
        key: const Key('ramadanSave'),
        label: s.save,
        onPressed: () async {
          final nav = Navigator.of(context);
          final msg = ScaffoldMessenger.of(context);
          await app.saveFasting(_on && _from != null && _to != null ? FastingMode(dateKey(_from!), dateKey(_to!)) : null);
          msg.showSnackBar(SnackBar(content: Text(s.ramadanSaved)));
          nav.pop();
        },
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
        Row(children: [
          const Icon(Icons.nightlight_outlined, color: BBColors.accent, size: 32),
          const Spacer(),
          WhyButton(title: s.ramadanTitle, source: kFastingSource),
        ]),
        const SizedBox(height: 8),
        Text(s.ramadanComing, style: tt.headlineSmall),
        BBCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.expectedIn(place), style: tt.bodySmall),
            Text(_from == null || _to == null ? s.notSet : s.dateRange(_from!, _to!),
                key: const Key('ramadanDates'), style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            Text(s.ummAlQura, style: tt.bodySmall),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: FilledButton(
                  key: const Key('thatsRight'),
                  onPressed: _from == null ? null : () => setState(() => _on = true),
                  child: Text(s.thatsRight),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final now = app.clock();
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30)),
                      lastDate: now.add(const Duration(days: 500)),
                      initialDateRange: _from == null || _to == null ? null : DateTimeRange(start: _from!, end: _to!),
                    );
                    if (range != null) {
                      setState(() {
                        _from = range.start;
                        _to = range.end;
                        _on = true;
                      });
                    }
                  },
                  child: Text(s.pickDates),
                ),
              ),
            ]),
          ]),
        ),
        BBCard(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: SwitchListTile(
            key: const Key('fastingSwitch'),
            contentPadding: EdgeInsets.zero,
            title: Text(s.fastingTitle, style: tt.titleSmall),
            subtitle: Text(s.fastingModeSub, style: tt.bodySmall),
            value: _on,
            onChanged: _from == null ? null : (v) => setState(() => _on = v),
          ),
        ),
        Text(s.ramadanPrivacy, style: tt.bodySmall),
        if (step != null)
          BBCard(
            color: BBColors.primaryLight,
            border: BBColors.primaryBorder,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CapsLabel(s.yourStepRamadan),
              const SizedBox(height: 2),
              Text(step, key: const Key('ramadanStep'), style: tt.titleSmall),
            ]),
          ),
      ]),
    );
  }
}

class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    Widget item(String title, String source) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: tt.titleSmall),
          subtitle: Text(source, style: tt.bodySmall),
          trailing: WhyButton(title: title, source: source),
        );
    return BBPage(
      title: s.sourcesRow,
      onBack: () => Navigator.of(context).pop(),
      body: ListView(padding: const EdgeInsets.fromLTRB(0, 4, 0, 16), children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(s.sourcesIntro, style: tt.bodyMedium)),
        SectionCard(title: s.levelsSources, children: [
          item(s.domainLabel(Domain.sleep), kSleepLevelSource),
          item(s.suggestedPace, kSleepStepSource),
          item(s.domainLabel(Domain.movement), kMoveLevelSource),
          item(s.moveCardTitle, kMoveStepSource),
          item(s.stepUpTitle, kStepUpSource),
          item(s.welcomeBackTitle, kLapseSource),
          item(s.spreadTitle, kSpreadSource),
          item(s.talkTest, kTalkTestSource),
          item(s.bioTitle, kD2Source),
        ]),
        SectionCard(title: s.environmentSources, children: [
          item(s.workBrisk, kWorkCreditSource),
          item(s.heavyNote, kHeavyWorkSource),
          item(s.heatNote, kHeatSource),
          item(s.fastingTitle, kFastingSource),
          item(s.radarNightsTitle, kNightsSource),
          item(s.longShiftNote, kLongShiftSource),
          item(s.irregularNote, kIrregularSource),
        ]),
        SectionCard(title: s.bandSources, children: [item(s.estimate, '$kBandSleepSource\n\n${s.bandSleepNote}')]),
        SectionCard(title: s.goalsHeader, children: [for (final c in kGoalCards) item(s.goal(c.id), c.source)]),
        SectionCard(title: s.habitsSources, children: [for (final h in kHabits) item(s.habit(h.id), h.source)]),
      ]),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return BBPage(
      title: s.aboutRow,
      onBack: () => Navigator.of(context).pop(),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
        Text(s.appName, style: heading(28, color: BBColors.primary)),
        Text('${s.tagline1} ${s.tagline2}', style: tt.titleMedium),
        const SizedBox(height: 12),
        Text(s.aboutBody),
        const SizedBox(height: 12),
        Text(kNotMedicalAdvice, style: tt.bodySmall),
      ]),
    );
  }
}
