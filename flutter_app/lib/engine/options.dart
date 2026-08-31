import 'dart:convert';

/// Mirror of defaultConfig / configOptions in drill.js, persisted as JSON.
class QuizOptions {
  final Map<String, bool> bools;
  String questionFocus;
  String numQuestions;

  QuizOptions._(this.bools, this.questionFocus, this.numQuestions);

  static Map<String, bool> defaultBools() => {
        'plain': true,
        'polite': false,
        'negative': true,
        'past': true,
        'te-form': false,
        'progressive': false,
        'potential': false,
        'conditional': false,
        'provisional': false,
        'imperative': false,
        'passive': false,
        'causative': false,
        'godan': true,
        'ichidan': true,
        'iku': true,
        'kuru': true,
        'suru': true,
        'iru': true,
        'aru': true,
        'i-adjective': false,
        'na-adjective': false,
        'ii': false,
        'desire': false,
        'volitional': false,
        'trick': true,
        'kana': false,
        'common': true,
        'n5': true,
        'n4': false,
        'n3': false,
        'n2': false,
        'n1': false,
      };

  factory QuizOptions.defaults() =>
      QuizOptions._(defaultBools(), 'none', '10');

  factory QuizOptions.fromJson(Map<String, dynamic> json) {
    final result = QuizOptions.defaults();
    final storedBools = json['bools'] as Map<String, dynamic>?;
    if (storedBools != null) {
      storedBools.forEach((k, v) {
        if (result.bools.containsKey(k)) result.bools[k] = v as bool;
      });
    }
    result.questionFocus = json['questionFocus'] as String? ?? 'none';
    result.numQuestions = json['numQuestions'] as String? ?? '10';
    return result;
  }

  Map<String, dynamic> toJson() => {
        'bools': bools,
        'questionFocus': questionFocus,
        'numQuestions': numQuestions,
      };

  String serialize() => jsonEncode(toJson());

  /// Independent deep copy — presets must never share an options instance
  /// with lastOptions or with each other.
  QuizOptions clone() =>
      QuizOptions.fromJson(Map<String, dynamic>.from(toJson()));

  Iterable<String> get boolKeys => bools.keys;

  bool? getBool(String key) => bools[key];

  bool get plain => bools['plain']!;
  bool get kana => bools['kana']!;
  bool get trick => bools['trick']!;
  bool get n5 => bools['n5']!;
  bool get n4 => bools['n4']!;
  bool get n3 => bools['n3']!;
  bool get n2 => bools['n2']!;
  bool get n1 => bools['n1']!;
  bool get common => bools['common']!;

  int get questionCount => int.tryParse(numQuestions) ?? 10;
}

const focusOptions = <String, String>{
  'none': 'None',
  'politeness': 'Politeness',
  'negative': 'Negative',
  'past': 'Past',
  'te-form': 'て form',
  'progressive': 'Progressive',
  'desire': 'Desire',
  'volitional': 'Volitional',
  'potential': 'Potential',
  'conditional': 'Conditional(たら)',
  'provisional': 'Provisional Conditional(ば)',
  'imperative': 'Imperative',
  'passive': 'Passive',
  'causative': 'Causative',
  'tetakei': 'Godan て / た form',
};
