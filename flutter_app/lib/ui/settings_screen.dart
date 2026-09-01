import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_store.dart';
import 'cloud_sync_screen.dart';
import 'data_sync_screen.dart';
import 'jisho_link.dart' show JishoLink;
import 'theme.dart';
import 'widgets.dart';

/// App settings — behaviour that applies to every session. Every change
/// applies immediately (the store notifies the whole app).
class SettingsScreen extends StatefulWidget {
  final AppStore store;

  const SettingsScreen({super.key, required this.store});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _goalController;

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController(
      text: '${widget.store.settings.dailyGoal}',
    );
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  void _set(VoidCallback fn) {
    setState(fn);
    widget.store.saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            MediaQuery.viewPaddingOf(context).bottom + 32,
          ),
          children: [
            const SectionHeader('Answering'),
            _tile(
              icon: Icons.keyboard_return,
              title: 'Submit with',
              subtitle: s.submitMode == SubmitMode.enter
                  ? 'Enter key on keyboard'
                  : 'Check button',
              context: context,
              trailing: SegmentedButton<SubmitMode>(
                segments: const [
                  ButtonSegment(value: SubmitMode.enter, label: Text('Enter')),
                  ButtonSegment(
                    value: SubmitMode.button,
                    label: Text('Button'),
                  ),
                ],
                selected: {s.submitMode},
                onSelectionChanged: (mode) =>
                    _set(() => s.submitMode = mode.first),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-advance on correct'),
              subtitle: const Text(
                'Skip the "Next" tap after a correct answer',
              ),
              value: s.autoNextOnCorrect,
              onChanged: (v) => _set(() => s.autoNextOnCorrect = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show explanation on mistakes'),
              subtitle: const Text('Open the "Why?" sheet automatically'),
              value: s.autoExplainOnWrong,
              onChanged: (v) => _set(() => s.autoExplainOnWrong = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Romaji → hiragana ${s.romajiConversion ? "on" : "off"}',
              ),
              subtitle: const Text(
                'Convert romaji letters to kana as you type (Caps Lock works too)',
              ),
              value: s.romajiConversion,
              onChanged: (v) => _set(() => s.romajiConversion = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show furigana'),
              subtitle: const Text(
                'Reading above kanji in questions and answers',
              ),
              value: s.furiganaAlways,
              onChanged: (v) => _set(() => s.furiganaAlways = v),
            ),
            const SectionHeader('Daily goal'),
            _tile(
              icon: Icons.flag,
              title: 'Questions per day',
              subtitle: 'Reaching the goal keeps your streak alive — any number works',
              context: context,
              trailing: Row(
                children: [
                  IconButton.outlined(
                    onPressed: () {
                      final v = (int.tryParse(_goalController.text) ?? 20) - 5;
                      if (v >= 1) {
                        _goalController.text = '$v';
                        _set(() => s.dailyGoal = v);
                      }
                    },
                    icon: const Icon(Icons.remove, size: 18),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _goalController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(isDense: true),
                      onChanged: (text) {
                        final v = int.tryParse(text);
                        if (v != null && v >= 1) {
                          _set(() => s.dailyGoal = v);
                        }
                      },
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: () {
                      final v = (int.tryParse(_goalController.text) ?? 20) + 5;
                      _goalController.text = '$v';
                      _set(() => s.dailyGoal = v);
                    },
                    icon: const Icon(Icons.add, size: 18),
                  ),
                ],
              ),
            ),
            const SectionHeader('Appearance'),
            _tile(
              icon: Icons.brightness_6_outlined,
              title: 'Theme',
              subtitle: switch (s.theme) {
                ThemeSetting.light => 'Light',
                ThemeSetting.dark => 'Dark',
                ThemeSetting.system => 'Follow system',
              },
              context: context,
              trailing: SegmentedButton<ThemeSetting>(
                segments: const [
                  ButtonSegment(
                    value: ThemeSetting.system,
                    label: Text('Auto'),
                    icon: Icon(Icons.brightness_auto, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeSetting.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeSetting.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode, size: 16),
                  ),
                ],
                selected: {s.theme},
                onSelectionChanged: (v) => _set(() => s.theme = v.first),
              ),
            ),
            const SectionHeader('Data & sync'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Backup file'),
              subtitle: const Text(
                'Export or import your full practice history as a file',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DataSyncScreen(store: widget.store),
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_sync_outlined),
              title: const Text('Cloud sync'),
              subtitle: const Text(
                'Automatic sync across devices via your own Firebase project',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CloudSyncScreen(store: widget.store),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SectionHeader('About'),
            Text(
              '活 Katsuyou — 活用 (katsuyō, "conjugation").\n'
              'Japanese verb & adjective conjugation drill.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Built on top of the Lan-Don extension of\nDon\'s Japanese Conjugation Drill.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => JishoLink.open(
                    context,
                    'https://github.com/wkdonc/conjugation',
                  ),
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text(
                    "Don's original",
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => JishoLink.open(
                    context,
                    'https://github.com/LandonJPGinn/jp-verb-quiz',
                  ),
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text(
                    "Landon's fork",
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Widget _tile({
  required IconData icon,
  required String title,
  required String subtitle,
  required Widget trailing,
  required BuildContext context,
}) {
  return Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: accentOf(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: trailing),
      ],
    ),
  );
}
