// Daily health-knowledge question (Chi, thread 0007; design B and C in docs/design/new-features-2026-11-15.pdf).
// Rules: no scores, no right/wrong count, no streaks; general knowledge only, never the user's own numbers;
// every question has an official source; Chi approves every question (only approved ones are shown).
import 'dart:convert';

import '../data/models.dart';

enum QuizTopic { sleep, movement, numbers }

class QuizSource {
  final String title;
  final String url;
  const QuizSource(this.title, this.url);
}

class QuizQuestion {
  final String id;
  final QuizTopic topic;
  final String question;
  final List<String> choices;
  final int answer;
  final String explanation;
  final bool askDoctor;
  final List<QuizSource> sources;
  final String? approved;

  const QuizQuestion({
    required this.id,
    required this.topic,
    required this.question,
    required this.choices,
    required this.answer,
    required this.explanation,
    required this.askDoctor,
    required this.sources,
    this.approved,
  });

  bool get isApproved => approved != null && approved!.isNotEmpty;
}

class QuizFormatError implements Exception {
  final String message;
  QuizFormatError(this.message);
  @override
  String toString() => 'questions.json: $message';
}

String _text(Object? v, String where) {
  if (v is Map && v['en'] is String && (v['en'] as String).trim().isNotEmpty) return (v['en'] as String).trim();
  throw QuizFormatError('$where needs { "en": "..." }');
}

/// Reads assets/quiz/questions.json. Throws [QuizFormatError] on anything Chi's agent should fix.
List<QuizQuestion> parseQuizBank(String json) {
  final root = jsonDecode(json);
  if (root is! Map || root['questions'] is! List) throw QuizFormatError('needs a "questions" list');
  final out = <QuizQuestion>[];
  final ids = <String>{};
  for (final q in root['questions'] as List) {
    if (q is! Map) throw QuizFormatError('every question is an object');
    final id = q['id'];
    if (id is! String || !RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(id)) {
      throw QuizFormatError('id "$id" must be kebab-case');
    }
    if (!ids.add(id)) throw QuizFormatError('id "$id" is used twice');
    final topic = QuizTopic.values.where((t) => t.name == q['topic']).firstOrNull;
    if (topic == null) throw QuizFormatError('$id: topic must be sleep, movement or numbers');
    final rawChoices = q['choices'];
    if (rawChoices is! List || rawChoices.length < 2 || rawChoices.length > 4) {
      throw QuizFormatError('$id: 2 to 4 choices');
    }
    final choices = [for (var i = 0; i < rawChoices.length; i++) _text(rawChoices[i], '$id choice $i')];
    final answer = q['answer'];
    if (answer is! int || answer < 0 || answer >= choices.length) throw QuizFormatError('$id: answer is not a choice index');
    final rawSources = q['sources'];
    final sources = <QuizSource>[
      if (rawSources is List)
        for (final s in rawSources)
          if (s is Map && s['title'] is String && s['url'] is String && (s['url'] as String).startsWith('https://'))
            QuizSource(s['title'] as String, s['url'] as String),
    ];
    final approved = q['approved'] as String?;
    if (approved != null && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(approved)) {
      throw QuizFormatError('$id: approved must be YYYY-MM-DD');
    }
    if (approved != null && sources.isEmpty) throw QuizFormatError('$id: an approved question needs a source with an https link');
    if (q['askDoctor'] is! bool) throw QuizFormatError('$id: askDoctor must be true or false');
    out.add(QuizQuestion(
      id: id,
      topic: topic,
      question: _text(q['question'], '$id question'),
      choices: choices,
      answer: answer,
      explanation: _text(q['explanation'], '$id explanation'),
      askDoctor: q['askDoctor'] as bool,
      sources: sources,
      approved: approved,
    ));
  }
  return out;
}

/// The next question for today, or null when the bank has nothing to show.
/// Habit topics follow the user's areas; about 1 in 5 is a "numbers" question (Chi's write-up 5.1, 4:1).
/// [seen] is oldest first, each id once. Unseen questions come first; when all have been seen, the bank starts
/// again with the one seen longest ago. [shownCount] counts every question ever shown (for the 4:1 mix).
QuizQuestion? nextQuestion(
  List<QuizQuestion> bank, {
  required Set<Domain> domains,
  required List<String> seen,
  required Set<String> shownToday,
  required int shownCount,
}) {
  final habitTopics = {
    if (domains.contains(Domain.sleep)) QuizTopic.sleep,
    if (domains.contains(Domain.movement)) QuizTopic.movement,
  };
  if (habitTopics.isEmpty) habitTopics.addAll([QuizTopic.sleep, QuizTopic.movement]);
  final pool = bank.where((q) => q.isApproved && !shownToday.contains(q.id)).toList();
  final habits = pool.where((q) => habitTopics.contains(q.topic)).toList();
  final numbers = pool.where((q) => q.topic == QuizTopic.numbers).toList();
  // Every 5th question shown is a numbers question, when one is left.
  final wantNumbers = shownCount % 5 == 4;
  final order = wantNumbers ? [numbers, habits] : [habits, numbers];
  for (final list in order) {
    final unseen = list.where((q) => !seen.contains(q.id)).toList();
    if (unseen.isNotEmpty) return unseen.first;
  }
  // All seen: start again with the one seen longest ago.
  final all = [...order[0], ...order[1]];
  if (all.isEmpty) return null;
  all.sort((a, b) => seen.indexOf(a.id).compareTo(seen.indexOf(b.id)));
  return all.first;
}
