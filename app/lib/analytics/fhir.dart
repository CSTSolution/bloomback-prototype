// FHIR R4 Bundle of Observations (rules B1: every source stored as FHIR
// Observation, labelled with its source). Same shape as
// wearable/lib/bbcore/src/export.cpp, plus self-reported baseline values.
import 'dart:convert';

import '../data/models.dart';
import 'daily.dart';

const _loinc = 'http://loinc.org';
const _ucum = 'http://unitsofmeasure.org';

/// Local date-time text, e.g. "2026-11-13T07:05:00+07:00" (export.cpp formatLocal).
String formatLocal(int utcMinute, int tzMinutes) {
  final local = utcMinute + tzMinutes;
  final days = local >= 0 ? local ~/ 1440 : (local - 1439) ~/ 1440;
  final mod = local - days * 1440;
  final d = DateTime.utc(1970, 1, 1).add(Duration(days: days));
  String two(int v) => v.toString().padLeft(2, '0');
  final a = tzMinutes.abs();
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}'
      'T${two(mod ~/ 60)}:${two(mod % 60)}:00'
      '${tzMinutes < 0 ? '-' : '+'}${two(a ~/ 60)}:${two(a % 60)}';
}

Map<String, dynamic> _obs({
  required String id,
  required DataSource source,
  required String system,
  required String code,
  required String display,
  required String device,
  required Map<String, dynamic> body,
}) =>
    {
      'fullUrl': 'urn:uuid:$id',
      'resource': {
        'resourceType': 'Observation',
        'id': id,
        'status': 'final',
        'meta': {
          'tag': [
            {'system': 'urn:bloomback:source', 'code': source.code}
          ]
        },
        'category': [
          {
            'coding': [
              {
                'system': 'http://terminology.hl7.org/CodeSystem/observation-category',
                'code': 'activity'
              }
            ]
          }
        ],
        'code': {
          'coding': [
            {'system': system, 'code': code, 'display': display}
          ]
        },
        'device': {'display': device},
        ...body,
      }
    };

Map<String, dynamic> _qty(num v, String unit, String code) =>
    {'value': v, 'unit': unit, 'system': _ucum, 'code': code};

const _statusCode = {
  CheckinStatus.done: 'done',
  CheckinStatus.partial: 'partial',
  CheckinStatus.notToday: 'not-today',
};

Map<String, dynamic> buildFhirBundle({
  required List<DaySummary> days,
  required List<Checkin> checkins,
  required int tzMinutes,
  required String bandName,
  Profile? profile,
}) {
  final entries = <Map<String, dynamic>>[];
  for (final d in days.where((d) => d.hasData)) {
    final a = formatLocal(d.dayStartMinute, tzMinutes);
    final b = formatLocal(d.dayStartMinute + 1440, tzMinutes);
    final date = a.substring(0, 10);
    final period = {'start': a, 'end': b};
    entries.add(_obs(
      id: 'steps-$date',
      source: DataSource.watch,
      system: _loinc,
      code: '55423-8',
      display: 'Number of steps',
      device: bandName,
      body: {'effectivePeriod': period, 'valueQuantity': _qty(d.steps, 'steps', '{steps}')},
    ));
    entries.add(_obs(
      id: 'moderate-$date',
      source: DataSource.watch,
      system: _loinc,
      code: '55411-3',
      display: 'Exercise duration',
      device: bandName,
      body: {
        'effectivePeriod': period,
        'valueQuantity': _qty(d.moderateMinutes, 'min', 'min'),
        'note': [
          {
            'text': 'Minutes with at least 100 steps (moderate cadence). '
                'Recorded minutes: ${d.recordedMinutes}.'
          }
        ],
      },
    ));
    if (d.sleep.found) {
      entries.add(_obs(
        id: 'sleep-$date',
        source: DataSource.watch,
        system: _loinc,
        code: '93832-4',
        display: 'Sleep duration',
        device: bandName,
        body: {
          'effectivePeriod': {
            'start': formatLocal(d.sleep.startMinute, tzMinutes),
            'end': formatLocal(d.sleep.endMinute, tzMinutes),
          },
          'valueQuantity': _qty(d.sleep.sleepMinutes, 'min', 'min'),
          'note': [
            {'text': 'Estimate from wrist movement; the period is the main sleep window.'}
          ],
        },
      ));
    }
  }
  for (final c in checkins) {
    entries.add(_obs(
      id: 'checkin-${c.minute}',
      source: c.source,
      system: 'urn:bloomback:codes',
      code: 'habit-checkin',
      display: 'Daily habit check-in',
      device: c.source == DataSource.watch ? bandName : 'BloomBack app',
      body: {
        'effectiveDateTime': formatLocal(c.minute, tzMinutes),
        'valueCodeableConcept': {
          'coding': [
            {'system': 'urn:bloomback:checkin', 'code': _statusCode[c.status]}
          ]
        },
      },
    ));
  }
  if (profile != null) {
    final when = formatLocal(profile.startMinute, tzMinutes);
    entries.add(_obs(
      id: 'self-sleep-${profile.startMinute}',
      source: DataSource.selfReport,
      system: _loinc,
      code: '93832-4',
      display: 'Sleep duration',
      device: 'BloomBack app',
      body: {
        'effectiveDateTime': when,
        'valueQuantity': _qty(profile.selfSleepMinutes, 'min', 'min'),
        'note': [
          {'text': 'Self-reported usual sleep per 24 hours at the start.'}
        ],
      },
    ));
    entries.add(_obs(
      id: 'self-moderate-${profile.startMinute}',
      source: DataSource.selfReport,
      system: _loinc,
      code: '55411-3',
      display: 'Exercise duration',
      device: 'BloomBack app',
      body: {
        'effectiveDateTime': when,
        'valueQuantity': _qty(profile.selfWalkMinutes, 'min/wk', 'min/wk'),
        'note': [
          {'text': 'Self-reported moderate activity minutes per week at the start.'}
        ],
      },
    ));
  }
  return {'resourceType': 'Bundle', 'type': 'collection', 'entry': entries};
}

String fhirJson(Map<String, dynamic> bundle) =>
    const JsonEncoder.withIndent('  ').convert(bundle);
