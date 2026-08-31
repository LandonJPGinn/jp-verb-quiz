import 'package:flutter/material.dart';

import '../engine/conjugation.dart';
import '../engine/options.dart';
import '../state/app_store.dart';
import 'pickers.dart';
import 'theme.dart';

/// Round customization: presets, length, focus, and option chip grids.
/// Deliberately styled as a "session builder" (cards + chips), distinct
/// from the flat list of the Settings screen.
class OptionsScreen extends StatefulWidget {
  final ConjugationEngine engine;
  final AppStore store;

  /// When set, this screen edits an existing preset: it starts from that
  /// preset's options and "Done" saves back to it.
  final String? editingPreset;

  const OptionsScreen({
    super.key,
    required this.engine,
    required this.store,
    this.editingPreset,
  });

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  late final Map<String, bool> _bools;
  late String _focus;
  late TextEditingController _numQuestions;

  @override
  void initState() {
    super.initState();
    // Editing a preset starts from that preset; creating a session starts
    // from the defaults — never from last settings.
    final base = widget.editingPreset == null
        ? QuizOptions.defaults()
        : widget.store.presets
            .firstWhere((p) => p.name == widget.editingPreset)
            .options;
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
    final options = widget.store.lastOptions;
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
    'godan': 109,
    'ichidan': 38,
    'iku': 1,
    'kuru': 1,
    'suru': 118,
    'aru': 1,
    'iru': 1,
    'i-adjective': 7,
    'ii': 1,
    'na-adjective': 8,
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

  @override
  Widget build(BuildContext context) {
    final applicable = _applicableQuestions();
    final wanted = int.tryParse(_numQuestions.text) ?? 10;
    final notEnough = applicable < wanted;
    final noPoliteness = !_bools['plain']! && !_bools['polite']!;

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.editingPreset == null
              ? 'Customize session'
              : 'Edit "${widget.editingPreset}"')),
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
                icon: Icon(widget.editingPreset == null
                    ? Icons.play_arrow
                    : Icons.check),
                label: Text(widget.editingPreset == null
                    ? 'Start with these options'
                    : 'Save preset'),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, MediaQuery.viewPaddingOf(context).bottom + 24),
        children: [
          SettingsCard(
            title: 'Presets',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in widget.store.presets)
                  InputChip(
                    label: Text(preset.name),
                    avatar: const Icon(Icons.bookmark, size: 15),
                    visualDensity: VisualDensity.compact,
                    onDeleted: () => _confirmDeletePreset(preset.name),
                    onPressed: () => _loadPreset(preset.options),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 17),
                  label: const Text('Save current'),
                  visualDensity: VisualDensity.compact,
                  onPressed: _savePresetDialog,
                ),
              ],
            ),
          ),
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
                        fontSize: 20, fontWeight: FontWeight.w800),
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                            fontSize: 15, fontWeight: FontWeight.w600),
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) => IconButton.outlined(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.outlineDark
                : AppColors.outline,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

  void _savePresetDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save preset'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. "N5 warm-up"'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                widget.store.addPreset(name, _current);
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePreset(String name) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete preset?'),
        content: Text('"$name" will be removed. Your settings stay unchanged.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              widget.store.removePreset(name);
              Navigator.pop(dialogContext);
              setState(() {});
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _loadPreset(QuizOptions options) {
    setState(() {
      _bools
        ..clear()
        ..addAll(options.bools);
      _focus = options.questionFocus;
      _numQuestions.text = options.numQuestions;
    });
    _persist();
  }
}
