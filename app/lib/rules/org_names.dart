// Short organisation names and what they stand for (Chi, thread 0007, 16/11): wherever "CDC", "WHO", "DoH"…
// shows, the user can see which organisation it is. Also the reuse lines some sources ask for.

/// Short name → full name. Matched as whole words, case-sensitive.
const kOrgNames = <String, String>{
  'CDC': 'U.S. Centers for Disease Control and Prevention',
  'NIOSH': 'U.S. National Institute for Occupational Safety and Health, part of CDC',
  'WHO': 'World Health Organization',
  'DHA': 'Dubai Health Authority',
  'DoH': 'Department of Health, Abu Dhabi',
  'MOHAP': 'UAE Ministry of Health and Prevention',
  'MoHRE': 'UAE Ministry of Human Resources and Emiratisation',
  'HHS': 'U.S. Department of Health and Human Services',
  'AASM': 'American Academy of Sleep Medicine',
  'SRS': 'Sleep Research Society',
  'NHS': 'National Health Service (UK)',
  'NHLBI': 'U.S. National Heart, Lung, and Blood Institute (NIH)',
  'NIH': 'U.S. National Institutes of Health',
  'BJSM': 'British Journal of Sports Medicine',
};

final _orgPattern = RegExp(r'\b(' + kOrgNames.keys.join('|') + r')\b');

/// The short names in [text], in order of first appearance, each once.
List<String> orgNamesIn(String text) {
  final seen = <String>[];
  for (final m in _orgPattern.allMatches(text)) {
    final k = m.group(1)!;
    if (!seen.contains(k)) seen.add(k);
  }
  return seen;
}

/// Splits [text] into plain parts and short names: (part, isOrg).
List<(String, bool)> splitOrgNames(String text) {
  final out = <(String, bool)>[];
  var at = 0;
  for (final m in _orgPattern.allMatches(text)) {
    if (m.start > at) out.add((text.substring(at, m.start), false));
    out.add((m.group(1)!, true));
    at = m.end;
  }
  if (at < text.length) out.add((text.substring(at), false));
  return out;
}

/// CDC's reuse terms: shown under any CDC or NIOSH source.
const kCdcAttribution = 'Source: CDC. Available free at cdc.gov. BloomBack is not endorsed by CDC or HHS.';
bool needsCdcLine(String source) => source.contains('CDC') || source.contains('NIOSH');

const kCcBy4 = 'https://creativecommons.org/licenses/by/4.0/';
bool isCcBy4(String source) => source.contains('CC BY 4.0');
