// Rules B5: the 14 goal cards. Titles live in l10n/strings.dart (by id).
// Cards never change the target numbers; they pick the starting area and habit order.

enum StartArea { sleep, movement, both }

class GoalCard {
  final String id;
  final String group; // night, day, mood, body, doctor
  final StartArea start;
  final String source;
  final bool askDoctorNote; // "doctor advised": show the ask-a-doctor note
  const GoalCard(this.id, this.group, this.start, this.source, {this.askDoctorNote = false});
}

const kGoalCards = <GoalCard>[
  GoalCard('fallAsleep', 'night', StartArea.sleep, 'NHLBI (NIH), Insomnia - Symptoms: lying awake a long time before falling asleep'),
  GoalCard('wakeAtNight', 'night', StartArea.sleep, 'NHLBI (NIH), Insomnia - Symptoms: waking up many times during the night'),
  GoalCard('wakeTooEarly', 'night', StartArea.sleep, 'NHLBI (NIH), Insomnia - Symptoms: waking too early and not getting back to sleep'),
  GoalCard('shiftSleep', 'night', StartArea.sleep, 'NHLBI (NIH), Circadian Rhythm Disorders: shift work disorder (night or rotating shifts)'),
  GoalCard('tiredOnWaking', 'day', StartArea.sleep, 'NHLBI (NIH), Insomnia - Symptoms: not feeling rested after sleep'),
  GoalCard('sleepyAtWork', 'day', StartArea.sleep, 'NHLBI (NIH): daytime sleepiness; sleepiness on night shifts'),
  GoalCard('focus', 'day', StartArea.sleep, 'NHLBI (NIH), Insomnia - Symptoms: trouble focusing on daily tasks'),
  GoalCard('mood', 'mood', StartArea.movement, 'WHO-5 topic "cheerful" (no questionnaire used); HHS 2018 table 2-1: activity lowers the risk of depression'),
  GoalCard('calm', 'mood', StartArea.both, 'WHO-5 topic "calm and relaxed"; HHS 2018 table 2-1: activity reduces anxiety'),
  GoalCard('energy', 'mood', StartArea.movement, 'WHO-5 topic "active and vigorous"; HHS 2018: fitness helps daily tasks without too much tiredness'),
  GoalCard('weight', 'body', StartArea.movement, 'HHS 2018 table 2-1: activity slows weight gain and helps keep weight off'),
  GoalCard('stronger', 'body', StartArea.movement, 'HHS 2018 table 2-1: better physical function'),
  GoalCard('aches', 'body', StartArea.movement, 'NIOSH: work-related musculoskeletal disorders; DHA 2026 sec. 12: stretching and warm-up'),
  GoalCard('doctor', 'doctor', StartArea.both, 'DHA 2026 sec. 11 "Exercise is Medicine"', askDoctorNote: true),
];

GoalCard goalById(String id) => kGoalCards.firstWhere((c) => c.id == id);
