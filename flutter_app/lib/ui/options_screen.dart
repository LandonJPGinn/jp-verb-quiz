import 'package:flutter/material.dart';

import '../engine/conjugation.dart';
import '../engine/options.dart';
import '../state/app_store.dart';
import 'pickers.dart';
import 'theme.dart';

/// What the screen is opened for.
enum OptionsPurpose {
  /// Pick options, then start a session right away (nothing is saved).
  customSession,

  /// Create a new preset (caller asks for the name first).
  createPreset,

  /// Edit an existing preset (set via [OptionsScreen.presetName]).
  editPreset,
}

/// Round customization: presets, length, focus, and option chip grids.
/// Deliberately styled as a "session builder" (cards + chips), distinct
/// from the flat list of the Settings screen.
class OptionsScreen extends StatefulWidget {
  final ConjugationEngine engine;
  final AppStore store;
  final OptionsPurpose purpose;

  /// The preset being edited (required for [OptionsPurpose.editPreset]).
  final String? presetName;

  const OptionsScreen({
    super.key,
    required this.engine,
    required this.store,
    this.purpose = OptionsPurpose.customSession,
    this.presetName,
  });

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  late final Map<String, bool> _bools;
  late String _focus;
  late TextEditingController _numQuestions;

  QuizOptions? _baseOptions;

  @override
  void initState() {
    super.initState();
    // Editing a preset starts from that preset; everything else starts from
    // the defaults — never from last settings.
    _baseOptions = widget.purpose == OptionsPurpose.editPreset
        ? widget.store.presets
              .firstWhere((p) => p.name == widget.presetName)
              .options
              .clone()
        : QuizOptions.defaults();
    final base = _baseOptions!;
    _bools = {...base.bools};
    _focus = base.questionFocus;
    _numQuestions = TextEditingController(text: base.numQuestions);
  }

  @override
  void dispose() {
    _numQuestions.dispose();
    super.dispose();
  }

  QuizOptions get _current {
    final options = _baseOptions!.clone();
    options.bools
      ..clear()
      ..addAll(_bools);
    options.questionFocus = _focus;
    options.numQuestions = _numQuestions.text;
    return options;
  }

  void _persist() {
    widget.store.lastOptions = _current;
    widget.store.saveOptions();
    setState(() {});
  }

  // Port of updateOptionSummary (drill.js) using the bundled count sample.
  static const Map<String, int> groupCounts = {
    'godan': 864,
    'ichidan': 429,
    'iku': 1,
    'kuru': 1,
    'suru': 1665,
    'aru': 1,
    'iru': 1,
    'i-adjective': 58,
    'ii': 1,
    'na-adjective': 50,
  };

  static const Map<String, String> sampleWords = {
    'なる': 'godan',
    '上げる': 'ichidan',
    '行く': 'iku',
    'ある': 'aru',
    'いる': 'iru',
    'する': 'suru',
    '高い': 'i-adjective',
    '来る': 'kuru',
    'いい': 'ii',
    '有名な': 'na-adjective',
  };

  int _applicableQuestions() {
    final options = _current;
    var applicable = 0;
    for (final word in sampleWords.keys) {
      for (final t in widget.engine.transformations) {
        if (widget.engine.validQuestion(word, t, options)) {
          applicable += groupCounts[sampleWords[word]] ?? 0;
        }
      }
    }
    return applicable;
  }

  String _title(BuildContext context) {
    switch (widget.purpose) {
      case OptionsPurpose.customSession:
        return 'Custom session';
      case OptionsPurpose.createPreset:
        return 'New preset: ${widget.presetName}';
      case OptionsPurpose.editPreset:
        return 'Edit: ${widget.presetName}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final applicable = _applicableQuestions();
    final wanted = int.tryParse(_numQuestions.text) ?? 10;
    final notEnough = applicable < wanted;
    final noPoliteness = !_bools['plain']! && !_bools['polite']!;

    return Scaffold(
      appBar: AppBar(title: Text(_title(context))),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (notEnough)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Not enough available questions for this length.',
                    style: TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
              if (noPoliteness)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    "Pick at least one of 'Plain' and 'Polite'.",
                    style: TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
              FilledButton.icon(
                onPressed: (notEnough || noPoliteness)
                    ? null
                    : () => Navigator.of(context).pop(_current),
                icon: Icon(
                  widget.purpose == OptionsPurpose.customSession
                      ? Icons.play_arrow
                      : Icons.check,
                ),
                label: Text(
                  widget.purpose == OptionsPurpose.customSession
                      ? 'Start session'
                      : 'Save preset',
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewPaddingOf(context).bottom + 24,
        ),
        children: [
          const SizedBox(height: 12),
          SettingsCard(
            title: 'Session length',
            child: Row(
              children: [
                _stepperButton(Icons.remove, () {
                  final v = (int.tryParse(_numQuestions.text) ?? 10) - 1;
                  if (v >= 1) {
                    _numQuestions.text = '$v';
                    _persist();
                  }
                }),
                Expanded(
                  child: TextField(
                    controller: _numQuestions,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Any number',
                    ),
                    onChanged: (text) {
                      final v = int.tryParse(text);
                      if (v == null || v < 1) return;
                      _persist();
                    },
                  ),
                ),
                _stepperButton(Icons.add, () {
                  final v = (int.tryParse(_numQuestions.text) ?? 10) + 1;
                  _numQuestions.text = '$v';
                  _persist();
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SettingsCard(
            title: 'Question focus',
            trailing: Text(
              'Pooled Questions: $applicable',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.75),
              ),
            ),
            child: InkWell(
              onTap: () async {
                await showFocusPicker(context, _focus);
                if (mounted) _persist();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.outlineDark
                        : AppColors.outline,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        focusOptions[_focus] ?? 'None',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SettingsCard(
            title: 'Forms',
            child: SelectChipGrid(
              entries: const [
                MapEntry('plain', 'Plain'),
                MapEntry('polite', 'Polite'),
                MapEntry('negative', 'Negative'),
                MapEntry('past', 'Past'),
                MapEntry('te-form', 'て form'),
                MapEntry('progressive', 'Progressive'),
                MapEntry('desire', 'Desire'),
                MapEntry('volitional', 'Volitional'),
                MapEntry('potential', 'Potential'),
                MapEntry('conditional', 'Conditional'),
                MapEntry('provisional', 'Provisional'),
                MapEntry('imperative', 'Imperative'),
                MapEntry('passive', 'Passive'),
                MapEntry('causative', 'Causative'),
              ],
              valueOf: (key) => _bools[key]!,
              onChanged: (key, value) {
                _bools[key] = value;
                _persist();
              },
            ),
          ),
          const SizedBox(height: 12),
          SettingsCard(
            title: 'Verbs',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectChipGrid(
                  entries: const [
                    MapEntry('godan', 'Godan'),
                    MapEntry('ichidan', 'Ichidan'),
                  ],
                  valueOf: (key) => _bools[key]!,
                  onChanged: (key, value) {
                    _bools[key] = value;
                    _persist();
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'IRREGULAR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 8),
                SelectChipGrid(
                  entries: const [
                    MapEntry('suru', 'する verbs'),
                    MapEntry('kuru', '来る verb'),
                    MapEntry('iku', '行く verb'),
                    MapEntry('aru', 'ある verb'),
                    MapEntry('iru', 'いる verbs'),
                  ],
                  valueOf: (key) => _bools[key]!,
                  onChanged: (key, value) {
                    _bools[key] = value;
                    _persist();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SettingsCard(
            title: 'Adjectives',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectChipGrid(
                  entries: const [
                    MapEntry('i-adjective', 'い adjectives'),
                    MapEntry('na-adjective', 'な adjectives'),
                    MapEntry('ii', 'いい adjective'),
                  ],
                  valueOf: (key) => _bools[key]!,
                  onChanged: (key, value) {
                    _bools[key] = value;
                    _persist();
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'FILTERS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 8),
                SelectChipGrid(
                  entries: const [
                    MapEntry('common', 'Top 100 common'),
                    MapEntry('n5', 'JLPT N5'),
                    MapEntry('n4', 'JLPT N4'),
                    MapEntry('n3', 'JLPT N3'),
                    MapEntry('n2', 'JLPT N2'),
                    MapEntry('n1', 'JLPT N1'),
                  ],
                  valueOf: (key) => _bools[key]!,
                  onChanged: (key, value) {
                    _bools[key] = value;
                    _persist();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SettingsCard(
            title: 'Extras',
            child: SelectChipGrid(
              entries: const [
                MapEntry('trick', 'Trick questions'),
                MapEntry('kana', 'Hiragana only'),
              ],
              valueOf: (key) => _bools[key]!,
              onChanged: (key, value) {
                _bools[key] = value;
                _persist();
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Trick questions may ask you to type the word exactly as given.\n'
            'Hiragana only hides all kanji in questions and answers.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) =>
      IconButton.outlined(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.outlineDark
                : AppColors.outline,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
}
