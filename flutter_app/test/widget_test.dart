import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:jp_conjugation/engine/conjugation.dart';
import 'package:jp_conjugation/engine/options.dart';
import 'package:jp_conjugation/engine/romaji.dart';
import 'package:jp_conjugation/state/app_store.dart';
import 'package:jp_conjugation/storage/merge.dart';

void main() {
  test('kanaForm / kanjiForm handle furigana notation', () {
    expect(ConjugationEngine.kanaForm('食[た]べる'), 'たべる');
    expect(ConjugationEngine.kanjiForm('食[た]べる'), '食べる');
    expect(ConjugationEngine.kanaForm('なる'), 'なる');
    expect(ConjugationEngine.kanjiForm('なる'), 'なる');
  });

  test('romaji converter is case-insensitive (Caps Lock friendly)', () {
    // Per-keystroke conversion: each call sees one more syllable at the cursor.
    var value = '';
    var pos = 0;
    for (final ch in 'TABEMASU'.split('')) {
      value += ch;
      pos += 1;
      final (v, p) = convertRomajiAtCursor(value, pos);
      value = v;
      pos = p;
    }
    expect(value, 'たべます');
  });

  test('romaji converter converts syllables before the cursor', () {
    final (value, pos) = convertRomajiAtCursor('tabemasu', 8);
    expect(value, 'tabemaす');
    expect(pos, 'tabemaす'.length);
  });

  test('engine generates a valid question with default options', () async {
    final engine = await ConjugationEngine.load(
      wordsJson: _wordsJson,
      rulesJson: _rulesJson,
    );
    expect(engine.words, isNotEmpty);
    expect(engine.transformations, isNotEmpty);

    final options = QuizOptions.defaults();
    final pool = engine.questionPoolFor(options);
    expect(pool, isNotEmpty);

    final question = engine.generateQuestion(pool, options, Random(42));
    expect(question, isNotNull);
    expect(question!.answer, isNotEmpty);
    expect(question.answerKana, isNotEmpty);
  });

  group('StatsStore streak', () {
    StatsStore storeWith(List<DateTime> days) {
      final store = StatsStore();
      for (final d in days) {
        store.record(date: _fmt(d), correct: true, goal: 1);
      }
      return store;
    }

    test('a single correct answer keeps the streak (goal is not required)', () {
      final today = DateTime.now();
      final store = StatsStore();
      store.record(date: _fmt(today), correct: true, goal: 20);
      expect(store.currentStreak, 1); // one correct answer is enough

      final wrongOnly = StatsStore();
      wrongOnly.record(date: _fmt(today), correct: false, goal: 20);
      expect(wrongOnly.currentStreak, 0); // wrong answers alone never count
    });

    test('no activity -> zero streak', () {
      expect(StatsStore().currentStreak, 0);
    });

    test('yesterday + today -> streak 2, best 2', () {
      final today = DateTime.now();
      final store = storeWith([today, today.subtract(const Duration(days: 1))]);
      expect(store.currentStreak, 2);
      expect(store.bestStreak, 2);
    });

    test('gap breaks the streak but best keeps the longest run', () {
      final today = DateTime.now();
      final store = storeWith([
        today,
        today.subtract(const Duration(days: 1)),
        today.subtract(const Duration(days: 2)),
        today.subtract(const Duration(days: 5)),
        today.subtract(const Duration(days: 6)),
      ]);
      expect(store.currentStreak, 3);
      expect(store.bestStreak, 3);
    });

    test('yesterday only still counts as an active streak', () {
      final today = DateTime.now();
      final store = storeWith([today.subtract(const Duration(days: 1))]);
      expect(store.currentStreak, 1);
    });

    test('serializes to JSON and back', () {
      final store = storeWith([DateTime.now()]);
      final copy = StatsStore.fromJson(
        Map<String, dynamic>.from(store.toJson()),
      );
      expect(copy.currentStreak, store.currentStreak);
      expect(copy.answeredOn(store.days.keys.first), 1);
    });
  });

  group('Form stats', () {
    test('records accuracy per form and finds weak spots', () {
      final store = StatsStore();
      // te-form: 1/5 correct, past: 5/5
      for (var i = 0; i < 5; i++) {
        store.recordForm(form: 'te-form', correct: i == 0);
        store.recordForm(form: 'past', correct: true);
      }
      expect(store.formStat('te-form')!.answered, 5);
      expect(store.formStat('te-form')!.accuracy, closeTo(0.2, 0.001));

      final weak = store.weakSpots();
      expect(weak.first.key, 'te-form');
      expect(weak.map((e) => e.key), ['te-form']); // past is mastered
    });

    test('weak spots ignore too-few attempts and mastered forms', () {
      final store = StatsStore();
      store.recordForm(form: 'volitional', correct: false); // 1 attempt
      for (var i = 0; i < 4; i++) store.recordForm(form: 'past', correct: true);
      store.recordForm(form: 'past', correct: false); // 80%, 5 attempts
      // past is exactly at the 80% bar -> not weak; volitional too few attempts
      expect(store.weakSpots(), isEmpty);
      // dip below the bar and it shows up
      store.recordForm(form: 'past', correct: false); // 60%, 6 attempts
      expect(store.weakSpots().map((e) => e.key), ['past']);
    });

    test('form stats serialize to JSON and back', () {
      final store = StatsStore();
      store.recordForm(form: 'te-form', correct: true);
      final copy = StatsStore.fromJson(
        Map<String, dynamic>.from(store.toJson()),
      );
      expect(copy.formStat('te-form')!.correct, 1);
    });
  });

  group('Layered storage merge', () {
    test('stats merge is additive per key (max counters, OR goalMet)', () {
      final local = {
        '2026-08-31': {'date': '2026-08-31', 'answered': 10, 'correct': 8, 'goalMet': false},
        '2026-08-30': {'date': '2026-08-30', 'answered': 5, 'correct': 5, 'goalMet': true},
      };
      final remote = {
        '2026-08-31': {'date': '2026-08-31', 'answered': 4, 'correct': 4, 'goalMet': true},
        '2026-08-29': {'date': '2026-08-29', 'answered': 2, 'correct': 0, 'goalMet': false},
      };
      final merged = mergeStatsData({'days': local}, {'days': remote});
      final days = merged['days'] as Map;

      expect((days['2026-08-31']['answered'] as int), 10); // max of both
      expect((days['2026-08-31']['correct'] as int), 8);
      expect(days['2026-08-31']['goalMet'], true); // OR
      expect(days.containsKey('2026-08-30'), true); // local-only kept
      expect(days.containsKey('2026-08-29'), true); // remote-only kept
    });

    test('settings merge is whole-section LWW', () {
      final local = {'settings': makeEnvelope({'a': 1}, 100)};
      final remote = {'settings': makeEnvelope({'a': 2}, 200)};
      final changed = mergeSections(local: local, remote: remote);
      expect(changed['settings']!['data']['a'], 2);

      // Older remote never overwrites.
      final older = {'settings': makeEnvelope({'a': 3}, 50)};
      final unchanged = mergeSections(local: local, remote: older);
      expect(unchanged.containsKey('settings'), false);
    });

    test('presets merge is per-name LWW', () {
      final local = {'presets': makeEnvelope({
        'list': [
          {'name': 'A', 'updatedAt': 10},
          {'name': 'B', 'updatedAt': 5},
        ]
      }, 100)};
      final remote = {'presets': makeEnvelope({
        'list': [
          {'name': 'A', 'updatedAt': 20}, // newer on remote
          {'name': 'C', 'updatedAt': 7},  // remote-only
        ]
      }, 200)};
      final changed = mergeSections(local: local, remote: remote);
      final list = changed['presets']!['data']['list'] as List;
      final names = {for (final p in list) p['name']: p['updatedAt']};
      expect(names['A'], 20);
      expect(names['B'], 5);
      expect(names['C'], 7);
    });
  });

  group('Presets', () {
    test('cloned presets are independent from the source options', () {
      final options = QuizOptions.defaults();
      final preset = RoundPreset(name: 'A', options: options.clone());
      // Mutating the source afterwards must NOT touch the preset.
      options.bools['te-form'] = true;
      options.numQuestions = '99';
      expect(preset.options.bools['te-form'], false);
      expect(preset.options.numQuestions, '10');
    });

    test('serialize and restore options', () {
      final options = QuizOptions.defaults();
      options.bools['te-form'] = true;
      options.numQuestions = '25';
      final preset = RoundPreset(name: 'te-form focus', options: options);
      final restored = RoundPreset.fromJson(
        Map<String, dynamic>.from(preset.toJson()),
      );
      expect(restored.name, 'te-form focus');
      expect(restored.options.bools['te-form'], true);
      expect(restored.options.numQuestions, '25');
    });
  });
}

String _fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// Minimal data fixtures so the tests do not need the full asset bundle.
const _wordsJson = '''
{
  "なる": {
    "group": "godan",
    "dictionary": "なる",
    "meaning": "to become",
    "level": "N5",
    "sentences": ["私は医者になりたいです。", "I want to become a doctor."],
    "tags": ["verb", "intransitive", "godan", "n5"],
    "notes": ["なる is an intransitive verb."]
  },
  "食べる": {
    "group": "ichidan",
    "dictionary": "食[た]べる",
    "meaning": "to eat",
    "level": "N5",
    "sentences": ["パンを食べる。", "I eat bread."],
    "tags": ["verb", "transitive", "ichidan", "n5"],
    "notes": ["食べる is a transitive verb."]
  }
}
''';

const _rulesJson = '''
{
  "godan": {
    "negative": { "forms": [
      {"before": "る", "after": "らない"},
      {"before": "つ", "after": "たない"},
      {"before": "う", "after": "わない"},
      {"before": "く", "after": "かない"},
      {"before": "ぐ", "after": "がない"},
      {"before": "す", "after": "さない"},
      {"before": "ぬ", "after": "なない"},
      {"before": "ぶ", "after": "ばない"},
      {"before": "む", "after": "まない"}
    ]},
    "polite": { "forms": [
      {"before": "る", "after": "ります"},
      {"before": "つ", "after": "ちます"},
      {"before": "う", "after": "います"},
      {"before": "く", "after": "きます"},
      {"before": "ぐ", "after": "ぎます"},
      {"before": "す", "after": "します"},
      {"before": "ぬ", "after": "にます"},
      {"before": "ぶ", "after": "びます"},
      {"before": "む", "after": "みます"}
    ]},
    "past": { "forms": [
      {"before": "る", "after": "った"},
      {"before": "つ", "after": "った"},
      {"before": "う", "after": "った"},
      {"before": "く", "after": "いた"},
      {"before": "ぐ", "after": "いだ"},
      {"before": "す", "after": "した"},
      {"before": "ぬ", "after": "んだ"},
      {"before": "ぶ", "after": "んだ"},
      {"before": "む", "after": "んだ"}
    ], "tetakei": true}
  },
  "ichidan": {
    "negative": { "forms": [ {"before": "る", "after": "ない"} ]},
    "polite": { "forms": [ {"before": "る", "after": "ます"} ]},
    "past": { "forms": [ {"before": "る", "after": "た"} ], "tetakei": true}
  }
}
''';
