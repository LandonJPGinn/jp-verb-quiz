import 'package:flutter/material.dart';

import '../engine/conjugation.dart';
import '../engine/options.dart';
import '../state/app_store.dart';
import 'cloud_sync_screen.dart';
import 'options_screen.dart';
import 'pickers.dart' show prettyForm;
import 'quiz_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets.dart';

/// Katsuyou home. First thing you see is today's goal, then one big CTA.
/// Starting offers your existing presets or a custom session — and a custom
/// session runs on its own settings without saving them.
class HomeScreen extends StatelessWidget {
  final ConjugationEngine engine;
  final AppStore store;

  const HomeScreen({super.key, required this.engine, required this.store});

  // ------------------------------------------------------------ actions

  void _startQuiz(BuildContext context, QuizOptions options) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          engine: engine,
          store: store,
          options: options.clone(),
        ),
      ),
    );
  }

  /// Start a session focused on one conjugation form (weak-spot drill).
  void _startFocused(BuildContext context, String form) {
    final options = store.lastOptions.clone()..questionFocus = form;
    _startQuiz(context, options);
  }

  /// Opens the customize screen. When [editingPreset] is set, "Done" saves
  /// the changes back to that preset; otherwise the returned options are
  /// used to start immediately and are NOT saved anywhere.
  Future<void> _openOptions(BuildContext context, {String? editingPreset}) async {
    final result = await Navigator.of(context).push<QuizOptions>(
      MaterialPageRoute(
        builder: (_) => OptionsScreen(
          engine: engine,
          store: store,
          editingPreset: editingPreset,
        ),
      ),
    );
    if (result == null) return;

    if (editingPreset != null) {
      await store.updatePreset(editingPreset, result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preset "$editingPreset" updated.')),
        );
      }
    } else if (context.mounted) {
      _startQuiz(context, result); // run immediately, nothing saved
    }
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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 14),
              Text('Start session',
                  style: Theme.of(sheetContext).textTheme.titleMedium),
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
                            borderRadius: BorderRadius.circular(14)),
                        leading: Icon(Icons.bookmark,
                            color: accentOf(sheetContext)),
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
                          borderRadius: BorderRadius.circular(14)),
                      leading:
                          Icon(Icons.tune, color: accentOf(sheetContext)),
                      title: const Text('Custom session'),
                      subtitle: const Text(
                          'Pick the options, then it starts right away'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openOptions(context);
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

  // -------------------------------------------------------------- build

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
                20, 8, 20, MediaQuery.viewPaddingOf(context).bottom + 32),
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
                label: const Text('Start session',
                    style: TextStyle(fontSize: 18)),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64)),
              ),
              const SizedBox(height: 8),
              Text(
                'Wrong answers come back until you master them.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: muted(context, 0.55)),
              ),
              const SectionHeader('History'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: MonthCalendar(stats: store.stats, goal: goal),
                ),
              ),
              const SectionHeader('Weak spots'),
              _weakSpotsCard(context),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------- drawer

  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('活 Katsuyou',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Text(
                'SESSION PRESETS',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: accentOf(context),
                ),
              ),
            ),
            if (store.presets.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'No presets yet — create one from the start sheet with '
                  '"Custom session".',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: muted(context, 0.55),
                  ),
                ),
              )
            else
              for (final preset in store.presets)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.bookmark, color: accentOf(context)),
                  title: Text(preset.name),
                  subtitle: Text(
                    '${preset.options.numQuestions} questions · '
                    '${focusOptions[preset.options.questionFocus] ?? 'no focus'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _startQuiz(context, preset.options);
                  },
                  trailing: PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: muted(context, 0.6)),
                    onSelected: (action) {
                      Navigator.pop(context); // close drawer first
                      if (action == 'edit') {
                        _openOptions(context, editingPreset: preset.name);
                      } else if (action == 'delete') {
                        _confirmDeletePreset(context, preset.name);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Edit'))),
                      PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.delete_outline,
                                  color: AppColors.error),
                              title: Text('Delete',
                                  style: TextStyle(color: AppColors.error)))),
                    ],
                  ),
                ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.tune, color: accentOf(context)),
              title: const Text('Customize session'),
              onTap: () {
                Navigator.pop(context);
                _openOptions(context);
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.settings_outlined, color: accentOf(context)),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SettingsScreen(store: store)));
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.backup_outlined, color: accentOf(context)),
              title: const Text('Backup & cloud sync'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CloudSyncScreen(store: store)));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePreset(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text(
            'This removes the preset only — your stats and settings stay.'),
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
                    foregroundColor: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.65),
                    side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
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

  // --------------------------------------------------------- weak spots

  Widget _weakSpotsCard(BuildContext context) {
    final theme = Theme.of(context);
    final weak = store.stats.weakSpots();

    Widget body;
    if (weak.isEmpty) {
      body = Row(
        children: [
          Icon(
              store.stats.hasFormSamples
                  ? Icons.verified_outlined
                  : Icons.insights,
              color: muted(context, 0.5)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              store.stats.hasFormSamples
                  ? 'No weak spots right now — every drilled form is above 80%. Keep it up!'
                  : 'Answer a few questions and your weakest conjugation forms will show up here — tap one to drill it.',
              style: TextStyle(
                fontSize: 13.5,
                color: muted(context, 0.75),
              ),
            ),
          ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Forms you keep missing (min. 5 attempts) — tap ▶ to drill that form only.',
            style: TextStyle(
              fontSize: 12,
              color: muted(context, 0.6),
            ),
          ),
          const SizedBox(height: 8),
          for (final spot in weak)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prettyForm(spot.key),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${spot.value.correct} of ${spot.value.answered} attempts correct',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: muted(context, 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: spot.value.accuracy,
                        minHeight: 8,
                        backgroundColor: theme.colorScheme.onSurface
                            .withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation(
                          spot.value.accuracy < 0.5
                              ? AppColors.error
                              : AppColors.indigo,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${(spot.value.accuracy * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: accentOf(context),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      tooltip: 'Drill this form',
                      onPressed: () => _startFocused(context, spot.key),
                      icon: const Icon(Icons.play_circle_outline),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: body),
    );
  }
}
