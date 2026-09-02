import 'package:flutter/material.dart';

import '../engine/conjugation.dart';
import '../engine/options.dart';
import '../state/app_store.dart';
import 'options_screen.dart';
import 'quiz_screen.dart';
import 'theme.dart';

/// Dedicated page for managing session presets: start, edit, or delete each
/// one, and create new presets. Editing always opens on its own page.
class PresetsScreen extends StatelessWidget {
  final ConjugationEngine engine;
  final AppStore store;

  const PresetsScreen({super.key, required this.engine, required this.store});

  void _startQuiz(BuildContext context, QuizOptions options) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            QuizScreen(engine: engine, store: store, options: options.clone()),
      ),
    );
  }

  /// Name prompt shared with the home screen's create flow.
  static Future<String?> askName(
    BuildContext context, {
    required String title,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
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
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _createPreset(BuildContext context) async {
    final name = await askName(context, title: 'New preset');
    if (name == null || name.isEmpty || !context.mounted) return;
    final result = await Navigator.of(context).push<QuizOptions>(
      MaterialPageRoute(
        builder: (_) => OptionsScreen(
          engine: engine,
          store: store,
          purpose: OptionsPurpose.createPreset,
          presetName: name,
        ),
      ),
    );
    if (result != null) {
      await store.addPreset(name, result);
    }
  }

  Future<void> _editPreset(BuildContext context, String name) async {
    final result = await Navigator.of(context).push<QuizOptions>(
      MaterialPageRoute(
        builder: (_) => OptionsScreen(
          engine: engine,
          store: store,
          purpose: OptionsPurpose.editPreset,
          presetName: name,
        ),
      ),
    );
    if (result != null) {
      await store.updatePreset(name, result);
    }
  }

  Future<void> _confirmDelete(BuildContext context, String name) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text(
          'This removes the preset only — stats and settings stay.',
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cancel is the primary action — deleting should never be
                // the easiest thing to hit.
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.65),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.25),
                    ),
                  ),
                  onPressed: () {
                    store.removePreset(name);
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Delete preset'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final presets = store.presets;
        return Scaffold(
          appBar: AppBar(title: const Text('Session presets')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _createPreset(context),
            icon: const Icon(Icons.add),
            label: const Text('Create preset'),
          ),
          body: presets.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No presets yet.\nCreate one to save an option setup you '
                      'can start any time.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    MediaQuery.viewPaddingOf(context).bottom + 88,
                  ),
                  itemCount: presets.length,
                  itemBuilder: (context, i) {
                    final preset = presets[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.bookmark,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    preset.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      _editPreset(context, preset.name),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: AppColors.error,
                                  ),
                                  onPressed: () =>
                                      _confirmDelete(context, preset.name),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 30,
                                bottom: 10,
                              ),
                              child: Text(
                                '${preset.options.numQuestions} questions · '
                                '${focusOptions[preset.options.questionFocus] ?? 'no focus'}'
                                '${preset.options.kana ? ' · hiragana only' : ''}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.tonalIcon(
                                onPressed: () =>
                                    _startQuiz(context, preset.options),
                                icon: const Icon(Icons.play_arrow, size: 20),
                                label: const Text('Start'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
