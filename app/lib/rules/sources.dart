// Links and short quotes for the "?" sheets (rules core 2: every piece of advice
// has a source). Quotes are only given where the exact wording has been checked
// (Chi's design, screen 13); everywhere else the sheet shows the source name and link.

class SourceLink {
  final String match; // text that identifies the source inside a source string
  final String name;
  final String url;
  const SourceLink(this.match, this.name, this.url);
}

/// A source text links the source it names first (Chi, thread 0005 fix 1); on a tie the earlier entry wins.
const kSourceLinks = <SourceLink>[
  SourceLink('DHA', 'Dubai Health Authority: Physical Activity Guideline (2026)',
      'https://dha.gov.ae/uploads/042026/Physical%20Activity%20Guideline2026429979.pdf'),
  SourceLink('NIOSH', 'NIOSH Training for Nurses on Shift Work and Long Work Hours',
      'https://www.cdc.gov/niosh/docs/wp-solutions/2015-115/'),
  SourceLink('van Hees', 'van Hees et al., Sci Rep 2018 (HDCZA)', 'https://doi.org/10.1038/s41598-018-31266-z'),
  SourceLink('Bull et al', 'WHO 2020 guidelines (Bull et al., BJSM 2020)', 'https://bjsm.bmj.com/content/54/24/1451'),
  SourceLink('HHS', 'Physical Activity Guidelines for Americans, 2nd edition (HHS 2018)',
      'https://odphp.health.gov/our-work/nutrition-physical-activity/physical-activity-guidelines/current-guidelines'),
  SourceLink('WHO 2020', 'WHO guidelines on physical activity and sedentary behaviour, 2020',
      'https://www.who.int/publications/i/item/9789240015128'),
  SourceLink('AASM', 'American Academy of Sleep Medicine: Healthy Sleep Habits',
      'https://sleepeducation.org/healthy-sleep/healthy-sleep-habits/'),
  SourceLink('NHS "Breathing', 'NHS: Breathing exercises for stress',
      'https://www.nhs.uk/mental-health/self-help/guides-tools-and-activities/breathing-exercises-for-stress/'),
  SourceLink('NHLBI', 'NHLBI (NIH): Insomnia', 'https://www.nhlbi.nih.gov/health/insomnia'),
  SourceLink('CDC', 'CDC: About Sleep', 'https://www.cdc.gov/sleep/about/index.html'),
];

/// The link for the source named first in [source], or null.
SourceLink? sourceLinkFor(String source) {
  SourceLink? best;
  var at = source.length + 1;
  for (final l in kSourceLinks) {
    final i = source.indexOf(l.match);
    if (i >= 0 && i < at) {
      best = l;
      at = i;
    }
  }
  return best;
}

/// Short quotes checked against the source (Chi's screen 13). Keyed by habit id.
const kHabitQuotes = <String, String>{
  'homeToBed': 'Go directly to bed when you arrive home.',
};

/// HHS 2018 talk test, used for "moderate" everywhere minutes are typed (A1, Q7).
const kTalkTestSource =
    'HHS Physical Activity Guidelines for Americans, 2nd ed. 2018: the "talk test". During '
    'moderate-intensity activity you can talk, but not sing. During vigorous activity you cannot '
    'say more than a few words without pausing for a breath.';

const kNotMedicalAdvice =
    'BloomBack gives suggestions, not medical advice. If sleep problems last, talk to your doctor.';
