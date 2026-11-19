// Chi's thread 0005 fixes 1-2: the "?" sheet links the source named first; DHA 2026 has its link;
// self-made habits say "BloomBack suggestion".
import 'package:bloomback/rules/habits.dart';
import 'package:bloomback/rules/sources.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every habit links the source it names first', () {
    String url(String id) => sourceLinkFor(kHabits.firstWhere((h) => h.id == id).source)!.url;
    for (final id in ['briskWalk', 'walkAfterMeal', 'stairs', 'strength', 'standUp', 'stretch', 'walkAfterIftar']) {
      expect(url(id), contains('dha.gov.ae'), reason: id);
    }
    expect(url('dimLight'), contains('sleepeducation.org'));
    expect(url('screensOff'), contains('sleepeducation.org'));
    expect(url('indoorWalk'), contains('odphp.health.gov'));
    for (final h in kHabits) {
      expect(sourceLinkFor(h.source), isNotNull, reason: h.id);
    }
  });
  test('walk after iftar is a BloomBack suggestion', () {
    expect(kHabits.firstWhere((h) => h.id == 'walkAfterIftar').source, startsWith('BloomBack suggestion'));
  });
}
