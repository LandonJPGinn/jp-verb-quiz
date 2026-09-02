import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../state/app_store.dart';
import 'cloud_sync_screen.dart';
import 'theme.dart';

/// Backup-file layer: export the JSON snapshot, or import one back in.
/// Works with no account at all — the human-powered sync channel.
class DataSyncScreen extends StatelessWidget {
  final AppStore store;

  const DataSyncScreen({super.key, required this.store});

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final path = store.hub.snapshotPath;
      if (path == null) throw 'storage unavailable';
      final messenger = ScaffoldMessenger.of(context);
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'Katsuyou backup',
        text: 'Katsuyou practice data backup',
      );
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePickerHolder.pick();
      if (result == null) return;
      final changed = await store.hub.mergeInto(result);
      await store.reloadFromHub();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            changed.isEmpty
                ? 'Nothing new to merge — backup matches current data.'
                : 'Merged: ${changed.keys.join(", ")}.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup file')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewPaddingOf(context).bottom + 32,
        ),
        children: [
          const Text(
            'A single file holds your entire practice history: daily stats, '
            'form accuracy, presets and settings. Keep it anywhere you like — '
            'Drive, email, your PC — and merge it back on any device.',
            style: TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.save_alt, color: accentOf(context)),
                  title: const Text('Export backup'),
                  subtitle: const Text(
                    'Share a snapshot file you can keep anywhere',
                  ),
                  onTap: () => _exportBackup(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.save_as, color: accentOf(context)),
                  title: const Text('Import backup'),
                  subtitle: const Text(
                    'Merge a previously exported file — nothing is overwritten',
                  ),
                  onTap: () => _importBackup(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Want automatic sync across devices instead (or too)?',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CloudSyncScreen(store: store)),
            ),
            icon: const Icon(Icons.cloud_sync_outlined),
            label: const Text('Set up cloud sync'),
          ),
        ],
      ),
    );
  }
}

/// Indirection so the import path stays testable without the plugin.
class FilePickerHolder {
  static FilePicker filePicker = FilePicker.platform;

  static Future<Map<String, Map<String, dynamic>>?> pick() async {
    final picked = await filePicker.pickFiles(withData: true);
    final bytes = picked?.files.single.bytes;
    if (bytes == null) return null;
    final raw = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return {
      for (final e in raw.entries)
        if (e.value is Map) e.key: Map<String, dynamic>.from(e.value as Map),
    };
  }
}
