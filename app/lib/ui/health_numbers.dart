// A1 ① optional health numbers, offered after week 1 (B1). Every field has
// "Don't know". The numbers only decide the D2 "ask a doctor" note; they never
// change a level or a plan, never name a disease, and nothing is red.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../l10n/strings.dart';
import '../rules/biomarkers.dart';
import 'common.dart';

class HealthNumbersScreen extends StatefulWidget {
  const HealthNumbersScreen({super.key});

  @override
  State<HealthNumbersScreen> createState() => _HealthNumbersScreenState();
}

class _Field {
  final String key;
  final c = TextEditingController();
  bool unknown = true;
  _Field(this.key);
}

class _HealthNumbersScreenState extends State<HealthNumbersScreen> {
  final _waist = _Field('waist');
  final _sys = _Field('sys');
  final _dia = _Field('dia');
  final _hr = _Field('hr');
  final _glu = _Field('glu');
  final _a1c = _Field('a1c');
  bool _mgDl = false;
  MarkerSource _source = MarkerSource.selfReport;
  DateTime _measured = DateTime.now();
  bool _init = false;
  bool _saved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final b = AppScope.of(context).biomarkers;
    if (b == null) return;
    void set(_Field f, num? v) {
      if (v != null) {
        f.c.text = '$v';
        f.unknown = false;
      }
    }

    set(_waist, b.waistCm);
    set(_sys, b.systolic);
    set(_dia, b.diastolic);
    set(_hr, b.restingHr);
    set(_glu, b.glucose);
    set(_a1c, b.hba1c);
    _mgDl = b.glucoseMgDl;
    _source = b.source;
    _measured = DateTime.fromMillisecondsSinceEpoch(b.measuredMinute * 60000);
  }

  int? _int(_Field f) => f.unknown ? null : int.tryParse(f.c.text.trim());
  double? _dbl(_Field f) => f.unknown ? null : double.tryParse(f.c.text.trim().replaceAll(',', '.'));

  Biomarkers _value() => Biomarkers(
        waistCm: _int(_waist),
        systolic: _int(_sys),
        diastolic: _int(_dia),
        restingHr: _int(_hr),
        glucose: _dbl(_glu),
        glucoseMgDl: _mgDl,
        hba1c: _dbl(_a1c),
        source: _source,
        measuredMinute: DateTime(_measured.year, _measured.month, _measured.day, 12)
                .toUtc()
                .millisecondsSinceEpoch ~/
            60000,
      );

  Widget _row(_Field f, String label, String unit, {bool decimal = false}) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(children: [
          Expanded(
            child: TextField(
              key: Key('bio_${f.key}'),
              controller: f.c,
              enabled: !f.unknown,
              keyboardType: TextInputType.numberWithOptions(decimal: decimal),
              inputFormatters: [
                decimal
                    ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                    : FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              decoration: InputDecoration(labelText: label, suffixText: unit, border: const OutlineInputBorder()),
              onChanged: (_) => setState(() => _saved = false),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(s.dontKnow),
            selected: f.unknown,
            onSelected: (v) => setState(() {
              f.unknown = v;
              if (v) f.c.clear();
              _saved = false;
            }),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = app.profile;
    final flags = doctorNoteFlags(heightCm: p?.heightCm, weightKg: p?.weightKg, markers: _value());
    return Scaffold(
      appBar: AppBar(title: Text(s.bioTitle)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(s.bioIntro),
          WhyButton(title: s.bioTitle, source: kD2Source),
          _row(_waist, s.waist, s.cm),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(s.bloodPressure, style: Theme.of(context).textTheme.titleSmall),
          ),
          _row(_sys, s.systolic, 'mmHg'),
          _row(_dia, s.diastolic, 'mmHg'),
          _row(_hr, s.restingHr, s.bpm),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(children: [
              Expanded(child: Text(s.glucose, style: Theme.of(context).textTheme.titleSmall)),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(s.mmolL)),
                  ButtonSegment(value: true, label: Text(s.mgDl)),
                ],
                selected: {_mgDl},
                onSelectionChanged: (x) => setState(() => _mgDl = x.first),
              ),
            ]),
          ),
          _row(_glu, s.glucose, _mgDl ? s.mgDl : s.mmolL, decimal: true),
          _row(_a1c, s.hba1c, '%', decimal: true),
          const SizedBox(height: 16),
          Text(s.bioSourceQ, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<MarkerSource>(
            segments: [
              ButtonSegment(value: MarkerSource.selfReport, label: Text(s.srcSelf)),
              ButtonSegment(value: MarkerSource.checkup, label: Text(s.srcCheckup)),
            ],
            selected: {_source},
            onSelectionChanged: (x) => setState(() => _source = x.first),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.measuredOn),
            trailing: TextButton(
              onPressed: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: _measured,
                  firstDate: now.subtract(const Duration(days: 730)),
                  lastDate: now,
                );
                if (d != null) setState(() => _measured = d);
              },
              child: Text(s.date(_measured)),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              await app.saveBiomarkers(_value());
              setState(() => _saved = true);
            },
            child: Text(s.save),
          ),
          if (_saved) ...[
            const SizedBox(height: 12),
            Text(s.bioSaved),
            if (flags.isNotEmpty || (p?.askDoctorFirst ?? false))
              Text(s.doctorNote, style: const TextStyle(color: BBColors.accent)),
          ],
        ]),
      ),
    );
  }
}
