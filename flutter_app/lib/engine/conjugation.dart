import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';
import 'options.dart';

/// Port of the conjugation engine in rules.js / drill.js.
class ConjugationEngine {
  late final Map<String, WordEntry> words;
  late final Map<String, Map<String, RuleForm>> rules;
  late final Map<String, Map<String, Conjugation>> _conjugations;
  late final List<Transformation> transformations;

  ConjugationEngine._();

  static Future<ConjugationEngine> load({
    required String wordsJson,
    required String rulesJson,
  }) async {
    final engine = ConjugationEngine._();
    final wordsMap = jsonDecode(wordsJson) as Map<String, dynamic>;
    engine.words = wordsMap.map(
      (k, v) => MapEntry(k, WordEntry.fromJson(v as Map<String, dynamic>)),
    );

    final rulesMap = jsonDecode(rulesJson) as Map<String, dynamic>;
    engine.rules = rulesMap.map((group, forms) {
      final inner = (forms as Map<String, dynamic>).map(
        (name, rf) =>
            MapEntry(name, RuleForm.fromJson(rf as Map<String, dynamic>)),
      );
      return MapEntry(group, inner);
    });

    engine._calculateAllConjugations();
    engine._calculateTransitions();
    return engine;
  }

  /// Loads the bundled words.json / rules.json assets.
  static Future<ConjugationEngine> loadAssets() async => load(
    wordsJson: await rootBundle.loadString('assets/words.json'),
    rulesJson: await rootBundle.loadString('assets/rules.json'),
  );

  // ---------------------------------------------------------------- forms

  static final RegExp _kanaPattern = RegExp(r'.\[([^\]]*)\]');
  static final RegExp _kanjiPattern = RegExp(r'(.+)\[[^\]]*\]');

  /// "食[た]べる" -> "たべる" (kana only, matching the JS kanaForm regex).
  static String kanaForm(String word) =>
      word.replaceAllMapped(_kanaPattern, (m) => m.group(1) ?? '');

  /// "食[た]べる" -> "食べる" (kanji, matching the JS kanjiForm regex).
  static String kanjiForm(String word) =>
      word.replaceAllMapped(_kanjiPattern, (m) => m.group(1) ?? '');

  Conjugation conjugationFor(String entry, String name) =>
      _conjugations[entry]![name] ??
      (throw StateError('no conjugation $name for $entry'));

  bool hasConjugation(String entry, String name) {
    final byWord = _conjugations[entry];
    return byWord != null && byWord.containsKey(name);
  }

  // ------------------------------------------------------- conjugations

  Conjugation? _calculateConjugations(String entry, String conjugation) {
    final word = words[entry];
    if (word == null) return null;

    if (conjugation == 'dictionary') {
      return Conjugation(forms: [word.dictionary]);
    }

    final groupRules = rules[word.group];
    if (groupRules == null) return null;
    final form = groupRules[conjugation];
    if (form == null) return null;

    final dictionary = word.dictionary;
    final results = <String>[];

    for (final rule in form.forms) {
      if (rule.before != null && rule.after != null) {
        if (dictionary.endsWith(rule.before!)) {
          results.add(
            dictionary.substring(0, dictionary.length - rule.before!.length) +
                rule.after!,
          );
        }
      }
      if (rule.result != null) {
        results.add(rule.result!);
      }
    }

    return Conjugation(forms: results, tetakei: form.tetakei);
  }

  void _calculateAllConjugations() {
    _conjugations = {};
    for (final entry in words.keys) {
      final word = words[entry]!;
      final byWord = <String, Conjugation>{
        'dictionary': Conjugation(forms: [word.dictionary]),
      };
      final groupRules = rules[word.group] ?? <String, RuleForm>{};
      for (final name in groupRules.keys) {
        final c = _calculateConjugations(entry, name);
        if (c != null) byWord[name] = c;
      }
      _conjugations[entry] = byWord;
    }
  }

  // ------------------------------------------------------- transitions

  static List<String> _getTags(String str) {
    final tags = str.split(' ');
    if (tags.length == 1 && tags[0] == 'plain') return [];
    return tags;
  }

  static List<String> _calculateTags(String str) {
    final tags = str.split(' ').toList();
    if (!tags.contains('polite')) tags.insert(0, 'plain');
    final dictIndex = tags.indexOf('dictionary');
    if (dictIndex != -1) tags.removeAt(dictIndex);
    return tags;
  }

  static List<String> _difference(List<String> a, List<String> b) =>
      a.where((x) => !b.contains(x)).toList();

  static List<String> _unique(List<String> arr) => arr.toSet().toList();

  static const Map<String, String> _phraseByDropped = {
    'negative': 'affirmative',
    'past': 'present',
    'polite': 'plain',
    'te-form': 'non-て',
    'potential': 'non-potential',
    'conditional': 'non-conditional',
    'provisional': 'non-provisional',
    'imperative': 'non-imperative',
    'causative': 'non-causative',
    'passive': 'active',
    'progressive': 'non-progressive',
    'desire': "'non-desire'",
    'volitional': 'non-volitional',
  };

  static const Map<String, String> _phraseByAdded = {
    'negative': 'negative',
    'past': 'past',
    'polite': 'polite',
    'te-form': 'て',
    'potential': 'potential',
    'conditional': 'conditional',
    'provisional': 'provisional',
    'imperative': 'imperative',
    'causative': 'causative',
    'passive': 'passive',
    'progressive': 'progressive',
    'desire': "'desire'",
    'volitional': 'volitional',
  };

  void _calculateTransitions() {
    final allTags = <String, List<String>>{};

    for (final entry in words.keys) {
      for (final conjugation in _conjugations[entry]!.keys) {
        final key = conjugation == 'dictionary' ? '' : conjugation;
        allTags[key] = key.split(' ');
      }
    }

    final List<Transformation> base = [];
    for (final srcTag in allTags.keys) {
      if (srcTag.isEmpty) continue;
      final tags = allTags[srcTag]!;
      for (var i = 0; i < tags.length; i++) {
        final dropped = [...tags]..removeAt(i);
        final dstTag = dropped.join(' ');
        if (allTags.containsKey(dstTag)) {
          final src = srcTag.isEmpty ? 'dictionary' : srcTag;
          final dst = dstTag.isEmpty ? 'dictionary' : dstTag;
          base.add(Transformation(src, dst));
          base.add(Transformation(dst, src));
        }
      }
    }

    for (final t in base) {
      final from = _getTags(t.from);
      final to = _getTags(t.to);

      var phrase = '';
      final dropped = _difference(from, to);
      if (dropped.isNotEmpty) phrase = _phraseByDropped[dropped.first] ?? '';
      final added = _difference(to, from);
      if (phrase.isEmpty && added.isNotEmpty) {
        phrase = _phraseByAdded[added.first] ?? '';
      }

      t.phrase = phrase;
      t.fromTags = _calculateTags(t.from);
      t.toTags = _calculateTags(t.to);
      t.tags = _unique([...t.fromTags, ...t.toTags]);

      final diffFromTo = _difference(t.fromTags, t.toTags);
      String type;
      if (diffFromTo.isNotEmpty) {
        type = diffFromTo.first;
      } else {
        type = _difference(t.toTags, t.fromTags).firstOrNull ?? '';
      }
      if (type == 'plain' || type == 'polite') type = 'politeness';
      t.type = type;
    }

    final tricks = <Transformation>[];
    for (final t in base) {
      final trick = Transformation(t.to, t.to)
        ..type = t.type
        ..phrase = t.phrase
        ..fromTags = t.toTags
        ..toTags = t.toTags
        ..tags = [...t.tags, 'trick'];
      tricks.add(trick);
    }

    transformations = [...base, ...tricks];
  }

  // --------------------------------------------------------- questions

  static const groupLabels = {
    'godan': 'godan verb',
    'ichidan': 'ichidan verb',
    'iku': 'godan verb',
    'suru': 'suru verb',
    'kuru': 'special verb',
    'aru': 'aru verb',
    'iru': 'iru verb',
    'i-adjective': 'い-adjective',
    'ii': 'い-adjective',
    'na-adjective': 'な-adjective',
  };

  static const questionPhrases = {
    'affirmative': 'make the following affirmative',
    'negative': 'make the following negative',
    'present': 'convert the following to the present tense',
    'past': 'convert the following to the past tense',
    'plain': 'make the following informal',
    'polite': 'make the following polite',
    'て': 'add the て pattern to the following',
    'non-て': 'remove the て pattern from the following',
    'potential': 'make the following potential',
    'non-potential': 'make the following non-potential',
    'conditional': 'make the following conditional',
    'non-conditional': 'make the following non-conditional',
    'provisional': 'make the following provisional',
    'non-provisional': 'make the following non-provisional',
    'imperative': 'make the following imperative',
    'non-imperative': 'make the following non-imperative',
    'causative': 'make the following causative',
    'non-causative': 'make the following non-causative',
    'passive': 'make the following passive',
    'active': 'make the following active',
    'progressive': 'make the following progressive',
    'non-progressive': 'make the following non-progressive',
    "'desire'": "convert the following to the 'desire' form",
    "'non-desire'": "convert the following to the 'non-desire' form",
    'volitional': 'make the following volitional',
    'non-volitional': 'make the following non-volitional',
  };

  bool validQuestion(String entry, Transformation t, QuizOptions options) {
    var valid = true;

    for (final type in t.tags) {
      if (options.getBool(type) == false) valid = false;
    }

    if (options.getBool(words[entry]!.group) == false) valid = false;

    final hasFilter =
        options.n5 ||
        options.n4 ||
        options.n3 ||
        options.n2 ||
        options.n1 ||
        options.common;
    if (hasFilter) {
      var pass = false;
      for (final key in options.boolKeys) {
        if (options.getBool(key) == true && words[entry]!.tags.contains(key)) {
          pass = true;
          break;
        }
      }
      if (!pass) valid = false;
    }

    if (!hasConjugation(entry, t.from) || !hasConjugation(entry, t.to)) {
      valid = false;
    }

    if (valid && options.questionFocus != 'none') {
      if (options.questionFocus == 'tetakei') {
        final fromC = _conjugations[entry]![t.from]!;
        final toC = _conjugations[entry]![t.to]!;
        if (fromC.tetakei == toC.tetakei) valid = false;
      } else if (t.type != options.questionFocus) {
        valid = false;
      }
    }

    return valid;
  }

  QuizQuestion? generateQuestion(
    List<String> questionPool,
    QuizOptions options,
    Random random,
  ) {
    var selection = [...questionPool];

    String? entry;
    Transformation? transformation;

    for (var attempt = 0; attempt < 800; attempt++) {
      if (selection.isEmpty) selection = [...questionPool];
      entry = selection[random.nextInt(selection.length)];
      transformation = transformations[random.nextInt(transformations.length)];

      var valid = validQuestion(entry, transformation, options);

      if (!valid) {
        selection.remove(entry);
      }

      // Trick questions appear ~25% of the time overall in the original;
      // Landon later cut the odds by a tenth, mirrored here.
      if (transformation.tags.contains('trick')) {
        if (random.nextDouble() > 0.033) valid = false;
      }

      if (valid) break;
      entry = null;
      transformation = null;
    }

    if (entry == null || transformation == null) return null;

    final t = transformation;
    final fromC = _conjugations[entry]![t.from]!;
    final toC = _conjugations[entry]![t.to]!;

    final List<String> candidates;
    if (options.kana) {
      candidates = fromC.forms.map(kanaForm).toList();
    } else {
      candidates = fromC.forms;
    }

    final idx = random.nextInt(candidates.length);
    final givenWord = candidates[idx];
    final givenWordAsKanji = kanjiForm(fromC.forms[idx]);

    List<String> answer;
    List<String> answerFurigana;
    if (options.kana) {
      answer = toC.forms.map(kanaForm).toList();
      answerFurigana = toC.forms.map(kanaForm).toList();
    } else {
      answer = toC.forms.map(kanjiForm).toList();
      answerFurigana = toC.forms;
    }
    final answerKana = toC.forms.map(kanaForm).toList();

    final phrase = questionPhrases[t.phrase] ?? t.phrase;

    return QuizQuestion(
      entry: entry,
      transformation: t,
      questionText: phrase.replaceFirst('the following', kanaForm(givenWord)),
      answer: answer,
      answerKana: answerKana,
      answerFurigana: answerFurigana,
      givenWord: givenWord,
      givenWordAsKanji: givenWordAsKanji,
    );
  }

  List<String> questionPoolFor(QuizOptions options) {
    final activeGroups = options.boolKeys
        .where((k) => options.getBool(k) == true)
        .toSet();
    return words.keys
        .where((entry) => activeGroups.contains(words[entry]!.group))
        .toList();
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
