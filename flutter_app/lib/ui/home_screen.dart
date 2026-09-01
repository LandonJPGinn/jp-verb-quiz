import 'package:flutter/material.dart';

import '../engine/conjugation.dart';
import '../engine/options.dart';
import '../state/app_store.dart';
import 'cloud_sync_screen.dart';
import 'options_screen.dart';
import 'presets_screen.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Katsuyou home: today's goal first, then the start CTA, your session
/// presets (start / edit / delete each), and the history heatmap.
class HomeScreen extends StatelessWidget {
  final ConjugationEngine engine;
  final AppStore store;

  const HomeScreen({super.key, required this.engine, required this.store});

  void _startQuiz(BuildContext context, QuizOptions options) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            QuizScreen(engine: engine, store: store, options: options.clone()),
      ),
    );
  }

  /// Custom session: pick options, it starts right away, nothing is saved.
  Future<void> _startCustomSession(BuildContext context) async {
    final result = await Navigator.of(context).push<QuizOptions>(
      MaterialPageRoute(
        builder: (_) => OptionsScreen(
          engine: engine,
          store: store,
          purpose: OptionsPurpose.customSession,
        ),
      ),
    );
    if (result != null && context.mounted) {
      _startQuiz(context, result);
    }
  }

  Future<void> _createPreset(BuildContext context) async {
    final name = await PresetsScreen.askName(context, title: 'New preset');
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

  Future<void> _confirmDeletePreset(BuildContext context, String name) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text(
          'This removes the preset only — your stats and settings stay.',
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
        final todayCorrect = store.stats.correctOn(store.today);
        final goal = store.settings.dailyGoal;

        return Scaffold(
          drawer: _buildDrawer(context),
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('活 Katsuyou'),
                Text(
                  '活用 — conjugation drill',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: muted(context, 0.55),
                  ),
                ),
              ],
            ),
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.viewPaddingOf(context).bottom + 32,
            ),
            children: [
              // First thing you see: today's goal.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      GoalRing(done: todayCorrect, goal: goal),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              todayCorrect >= goal
                                  ? 'Daily goal reached!'
                                  : 'Daily goal',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              todayCorrect >= goal
                                  ? 'Goal covered — everything more is bonus heat.'
                                  : '$todayCorrect correct so far. One correct '
                                        'answer keeps your streak alive.',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: muted(context, 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // The CTA.
              FilledButton.icon(
                onPressed: () => _showStartSheet(context),
                icon: const Icon(Icons.play_arrow, size: 28),
                label: const Text(
                  'Start session',
                  style: TextStyle(fontSize: 18),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                ),
              ),
              const SizedBox(height: 24),
              _presetSection(context),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------- presets on home

  Widget _presetSection(BuildContext context) {
    if (store.presets.isEmpty) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.bookmark_add_outlined, color: accentOf(context)),
          title: const Text('Create your first preset'),
          subtitle: const Text(
            'Save an option setup — "N5 warm-up", "causative drill" — and '
            'start it any time',
          ),
          onTap: () => _createPreset(context),
        ),
      );
    }

    return Column(
      children: [
        for (final preset in store.presets)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 4, 0, 4),
              leading: Icon(Icons.bookmark, color: accentOf(context)),
              title: Text(
                preset.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${preset.options.numQuestions} questions · '
                '${focusOptions[preset.options.questionFocus] ?? 'no focus'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _startQuiz(context, preset.options),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Start',
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _startQuiz(context, preset.options),
                  ),
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editPreset(context, preset.name),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                    onPressed: () => _confirmDeletePreset(context, preset.name),
                  ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _createPreset(context),
          icon: const Icon(Icons.add),
          label: const Text('Create preset'),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- drawer

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '活 Katsuyou',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '活用 — conjugation drill',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: muted(context, 0.55),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.bookmark_border, color: accentOf(context)),
              title: const Text('Session presets'),
              subtitle: const Text('Manage your saved setups'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PresetsScreen(engine: engine, store: store),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings_outlined, color: accentOf(context)),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(store: store),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.backup_outlined, color: accentOf(context)),
              title: const Text('Backup & cloud sync'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CloudSyncScreen(store: store),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// The start flow: existing presets, or a custom session.
  void _showStartSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 14),
              Text(
                'Start session',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  children: [
                    if (store.presets.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          'YOUR PRESETS',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: Theme.of(sheetContext).colorScheme.primary,
                          ),
                        ),
                      ),
                    for (final preset in store.presets)
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: Icon(
                          Icons.bookmark,
                          color: accentOf(sheetContext),
                        ),
                        title: Text(preset.name),
                        subtitle: Text(
                          '${preset.options.numQuestions} questions · '
                          '${focusOptions[preset.options.questionFocus] ?? 'no focus'}',
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _startQuiz(context, preset.options);
                        },
                      ),
                    if (store.presets.isNotEmpty) const Divider(height: 16),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: Icon(Icons.tune, color: accentOf(sheetContext)),
                      title: const Text('Custom session'),
                      subtitle: const Text(
                        'Pick the options, then it starts right away',
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _startCustomSession(context);
                      },
                    ),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: Icon(
                        Icons.bookmark_border,
                        color: accentOf(sheetContext),
                      ),
                      title: const Text('Manage presets'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PresetsScreen(engine: engine, store: store),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
