// Rules B2/B3: the motivation sentence is kept word for word, but checked for
// danger signs and stripped of obvious identifiers (A3: no phone numbers, emails).
// The keyword list is a first draft for Chi and the medical adviser to review.

const _dangerWords = <String>[
  'chest pain', 'faint', 'fainted', 'passed out', "can't breathe", 'cannot breathe',
  'short of breath', 'suicide', 'kill myself', 'end my life', 'self harm', 'self-harm',
  'hurt myself', 'want to die',
  // Arabic (to be checked by a native speaker): suicide, chest pain.
  'انتحار', 'ألم في الصدر',
];

/// True when the text mentions a danger sign: BB stops suggesting and points to
/// emergency help instead.
bool hasDangerSign(String text) {
  final t = text.toLowerCase();
  return _dangerWords.any(t.contains);
}

/// Removes emails and phone-number-like digit runs.
String stripIdentifiers(String text) => text
    .replaceAll(RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'), '…')
    .replaceAll(RegExp(r'\+?\d[\d\s\-().]{6,}\d'), '…')
    .trim();
