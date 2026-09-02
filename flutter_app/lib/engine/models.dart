// Engine port of rules.js / drill.js from Lan-Don's Japanese Conjugation Drill.

class RuleEntry {
  final String? before;
  final String? after;
  final String? result;

  RuleEntry({this.before, this.after, this.result});

  factory RuleEntry.fromJson(Map<String, dynamic> json) => RuleEntry(
    before: json['before'] as String?,
    after: json['after'] as String?,
    result: json['result'] as String?,
  );
}

class RuleForm {
  final List<RuleEntry> forms;
  final bool tetakei;

  RuleForm({required this.forms, this.tetakei = false});

  factory RuleForm.fromJson(Map<String, dynamic> json) => RuleForm(
    forms: (json['forms'] as List)
        .map((e) => RuleEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
    tetakei: json['tetakei'] == true,
  );
}

class WordEntry {
  final String group;
  final String dictionary;
  final String meaning;
  final String level;
  final List<String> sentences;
  final List<String> notes;
  final List<String> tags;

  WordEntry({
    required this.group,
    required this.dictionary,
    required this.meaning,
    required this.level,
    required this.sentences,
    required this.notes,
    required this.tags,
  });

  factory WordEntry.fromJson(Map<String, dynamic> json) => WordEntry(
    group: json['group'] as String,
    dictionary: json['dictionary'] as String,
    meaning: json['meaning'] as String? ?? '',
    level: json['level'] as String? ?? '',
    sentences: (json['sentences'] as List?)?.cast<String>() ?? const [],
    notes: (json['notes'] as List?)?.cast<String>() ?? const [],
    tags: (json['tags'] as List?)?.cast<String>() ?? const [],
  );
}

/// One conjugated form of a word, mirroring the JS `{ forms: [...] }` shape.
class Conjugation {
  final List<String> forms;
  final bool tetakei;

  Conjugation({required this.forms, this.tetakei = false});
}

class Transformation {
  final String from;
  final String to;
  String phrase;
  String type;
  List<String> fromTags;
  List<String> toTags;
  List<String> tags;

  Transformation(this.from, this.to)
    : phrase = '',
      type = '',
      fromTags = const [],
      toTags = const [],
      tags = const [];
}

class QuizQuestion {
  final String entry;
  final Transformation transformation;
  final String questionText; // phrase with the word substituted
  final List<String> answer; // accepted answers (kanji or kana form)
  final List<String> answerKana;
  final List<String> answerFurigana; // raw forms, kanji[kana] notation
  final String givenWord;
  final String givenWordAsKanji;

  QuizQuestion({
    required this.entry,
    required this.transformation,
    required this.questionText,
    required this.answer,
    required this.answerKana,
    required this.answerFurigana,
    required this.givenWord,
    required this.givenWordAsKanji,
  });
}

class HistoryEntry {
  final String question;
  final String response;
  final List<String> answer;
  final bool correct;

  HistoryEntry({
    required this.question,
    required this.response,
    required this.answer,
    required this.correct,
  });
}
