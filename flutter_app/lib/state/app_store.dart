import 'dart:async';

import 'package:flutter/foundation.dart';

import '../engine/options.dart';
import '../storage/storage_hub.dart';

/// App-level settings that persist across sessions — behaviour toggles that
/// used to live on the round-options screen.
class AppSettings {
  ThemeSetting theme; // light / dark / system
  SubmitMode submitMode; // enter key or explicit button
  bool autoNextOnCorrect;
  bool autoExplainOnWrong;
  bool furiganaAlways;
  bool romajiConversion;
  int dailyGoal;

  AppSettings({
    this.theme = ThemeSetting.system,
    this.submitMode = SubmitMode.enter,
    this.autoNextOnCorrect = false,
    this.autoExplainOnWrong = false,
    this.furiganaAlways = true,
    this.romajiConversion = true,
    this.dailyGoal = 20,
  });

  Map<String, dynamic> toJson() => {
        'theme': theme.name,
        'submitMode': submitMode.name,
        'autoNextOnCorrect': autoNextOnCorrect,
        'autoExplainOnWrong': autoExplainOnWrong,
        'furiganaAlways': furiganaAlways,
        'romajiConversion': romajiConversion,
        'dailyGoal': dailyGoal,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final s = AppSettings();
    s.theme = ThemeSetting.values.firstWhere(
      (v) => v.name == json['theme'],
      orElse: () => ThemeSetting.system,
    );
    s.submitMode = SubmitMode.values.firstWhere(
      (v) => v.name == json['submitMode'],
      orElse: () => SubmitMode.enter,
    );
    s.autoNextOnCorrect = json['autoNextOnCorrect'] as bool? ?? false;
    s.autoExplainOnWrong = json['autoExplainOnWrong'] as bool? ?? false;
    s.furiganaAlways = json['furiganaAlways'] as bool? ?? true;
    s.romajiConversion = json['romajiConversion'] as bool? ?? true;
    s.dailyGoal = json['dailyGoal'] as int? ?? 20;
    return s;
  }
}

enum ThemeSetting { system, light, dark }

enum SubmitMode { enter, button }

/// A named snapshot of round options — "today N5, tomorrow causatives".
class RoundPreset {
  final String name;
  final QuizOptions options;
  final int updatedAt;

  RoundPreset({required this.name, required this.options, this.updatedAt = 0});

  Map<String, dynamic> toJson() =>
      {'name': name, 'options': options.toJson(), 'updatedAt': updatedAt};

  factory RoundPreset.fromJson(Map<String, dynamic> json) => RoundPreset(
        name: json['name'] as String,
        options: QuizOptions.fromJson(
          Map<String, dynamic>.from(json['options'] as Map),
        ),
        updatedAt: json['updatedAt'] as int? ?? 0,
      );
}

/// Daily practice statistics + streak tracking.
/// A day counts toward the streak once the daily goal is reached.
class DayStat {
  final String date; // yyyy-mm-dd (local)
  int answered;
  int correct;
  bool goalMet;

  /// True for days recorded before goal tracking existed (loaded from old
  /// JSON without a `goalMet` field) — they count via the legacy fallback.
  final bool isLegacy;

  DayStat({
    required this.date,
    this.answered = 0,
    this.correct = 0,
    this.goalMet = false,
    this.isLegacy = false,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'answered': answered,
        'correct': correct,
        'goalMet': goalMet,
      };

  factory DayStat.fromJson(Map<String, dynamic> json) => DayStat(
        date: json['date'] as String,
        answered: json['answered'] as int? ?? 0,
        correct: json['correct'] as int? ?? 0,
        goalMet: json['goalMet'] as bool? ?? false,
        isLegacy: !json.containsKey('goalMet'),
      );
}

/// Per-conjugation-form accuracy ("te-form", "past negative", ...), used to
/// surface weak spots on the home screen.
class FormStat {
  int answered;
  int correct;

  FormStat({this.answered = 0, this.correct = 0});

  double get accuracy => answered == 0 ? 0 : correct / answered;

  Map<String, dynamic> toJson() => {'answered': answered, 'correct': correct};

  factory FormStat.fromJson(Map<String, dynamic> json) => FormStat(
        answered: json['answered'] as int? ?? 0,
        correct: json['correct'] as int? ?? 0,
      );
}

class StatsStore {
  StatsStore();

  final Map<String, DayStat> days = {};
  final Map<String, FormStat> forms = {};

  /// Weakest forms by accuracy, enough attempts to be meaningful.
  List<MapEntry<String, FormStat>> weakSpots({
    int minAttempts = 5,
    double maxAccuracy = 0.8,
    int limit = 4,
  }) {
    final entries = forms.entries
        .where((e) =>
            e.value.answered >= minAttempts && e.value.accuracy < maxAccuracy)
        .toList()
      ..sort((a, b) => a.value.accuracy.compareTo(b.value.accuracy));
    return entries.take(limit).toList();
  }

  /// True once any form has enough attempts to judge.
  bool get hasFormSamples => forms.values.any((f) => f.answered >= 5);

  int answeredOn(String date) => days[date]?.answered ?? 0;
  int correctOn(String date) => days[date]?.correct ?? 0;
  bool goalMetOn(String date) => days[date]?.goalMet ?? false;

  void record({required String date, required bool correct, required int goal}) {
    final stat = days.putIfAbsent(date, () => DayStat(date: date));
    stat.answered++;
    if (correct) stat.correct++;
    if (goal > 0 && stat.answered >= goal) stat.goalMet = true;
  }

  void recordForm({required String form, required bool correct}) {
    final stat = forms.putIfAbsent(form, () => FormStat());
    stat.answered++;
    if (correct) stat.correct++;
  }

  FormStat? formStat(String form) => forms[form];

  bool _streakDay(String date) {
    final stat = days[date];
    // One correct answer is enough to keep the streak alive — the goal is a
    // soft daily target, not a streak requirement.
    return stat != null && stat.correct > 0;
  }

  /// Consecutive days (ending today or yesterday) with at least one correct
  /// answer.
  int get currentStreak {
    var streak = 0;
    var day = DateTime.now();
    if (!_streakDay(_fmt(day))) {
      day = day.subtract(const Duration(days: 1)); // today not done yet
      if (!_streakDay(_fmt(day))) return 0;
    }
    while (_streakDay(_fmt(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int get bestStreak {
    if (days.isEmpty) return 0;
    final dates = days.keys.where(_streakDay).toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final d in dates) {
      final date = DateTime.parse(d);
      if (prev != null && date.difference(prev).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
      prev = date;
    }
    return best;
  }

  Map<String, dynamic> toJson() => {
        'days': [for (final d in days.values) d.toJson()],
        'forms': {
          for (final e in forms.entries) e.key: e.value.toJson(),
        },
      };

  factory StatsStore.fromJson(Map<String, dynamic> json) {
    final store = StatsStore();
    for (final raw in (json['days'] as List? ?? [])) {
      final stat = DayStat.fromJson(Map<String, dynamic>.from(raw));
      store.days[stat.date] = stat;
    }
    final rawForms = json['forms'];
    if (rawForms is Map) {
      rawForms.forEach((key, value) {
        store.forms[key as String] =
            FormStat.fromJson(Map<String, dynamic>.from(value));
      });
    }
    return store;
  }
}

String _fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// All persisted state in one place. Persistence itself is delegated to the
/// layered [StorageHub] (SQLite -> snapshot file -> legacy prefs -> cloud).
class AppStore extends ChangeNotifier {
  AppStore(this._hub);

  final StorageHub _hub;

  StorageHub get hub => _hub;

  AppSettings settings = AppSettings();
  StatsStore stats = StatsStore();
  List<RoundPreset> presets = [];
  QuizOptions lastOptions = QuizOptions.defaults();

  String get today => _fmt(DateTime.now());

  void changed() => notifyListeners();

  Future<void> load() async {
    await _hub.load();

    if (_hub.sections['settings'] != null) {
      try {
        settings = AppSettings.fromJson(
            Map<String, dynamic>.from(_hub.sections['settings']!['data']));
      } catch (_) {}
    }
    if (_hub.sections['stats'] != null) {
      try {
        stats = StatsStore.fromJson(
            Map<String, dynamic>.from(_hub.sections['stats']!['data']));
      } catch (_) {}
    }
    if (_hub.sections['presets'] != null) {
      try {
        presets = [
          for (final e in _hub.sections['presets']!['data']['list'] as List)
            RoundPreset.fromJson(Map<String, dynamic>.from(e)),
        ];
      } catch (_) {}
    }
    if (_hub.sections['lastOptions'] != null) {
      try {
        lastOptions = QuizOptions.fromJson(
            Map<String, dynamic>.from(_hub.sections['lastOptions']!['data']));
      } catch (_) {}
    }

  }

  void recordAnswer({required bool correct, String? form}) {
    // Daily activity counts ONLY correct answers; retries are free.
    if (correct) {
      stats.record(date: today, correct: true, goal: settings.dailyGoal);
    }
    // Form accuracy still tracks every attempt — that is what weak spots
    // are computed from.
    if (form != null) {
      stats.recordForm(form: form, correct: correct);
      unawaited(_hub.logQuestion(form: form, correct: correct));
    }
    saveStats();
    notifyListeners();
  }

  Future<void> addPreset(String name, QuizOptions options) async {
    presets.removeWhere((p) => p.name == name);
    presets.add(RoundPreset(
      name: name,
      options: options.clone(), // independent snapshot, never a shared reference
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await savePresets();
    notifyListeners();
  }

  /// Overwrite an existing preset's options (edit flow).
  Future<void> updatePreset(String name, QuizOptions options) async {
    final i = presets.indexWhere((p) => p.name == name);
    if (i == -1) return;
    presets[i] = RoundPreset(
      name: name,
      options: options.clone(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await savePresets();
    notifyListeners();
  }

  Future<void> removePreset(String name) async {
    presets.removeWhere((p) => p.name == name);
    await savePresets();
    notifyListeners();
  }

  // ---- persistence passthroughs (the hub fans out to every layer) ----

  Future<void> saveSettings() {
    notifyListeners(); // settings apply live, no restart needed
    return _hub.saveSection('settings', settings.toJson());
  }

  Future<void> saveStats() => _hub.saveSection('stats', stats.toJson());

  Future<void> savePresets() => _hub.saveSection('presets',
        {'list': [for (final p in presets) p.toJson()]});

  Future<void> saveOptions() =>
      _hub.saveSection('lastOptions', lastOptions.toJson());

  /// Re-apply merged data (after import or cloud pull) onto in-memory models.
  Future<void> reloadFromHub() async {
    await load();
    notifyListeners();
  }
}
