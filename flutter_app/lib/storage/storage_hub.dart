import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'merge.dart';

/// Layered persistence for Katsuyou.
///
/// Layers and their roles:
///  1. SQLite (`state` kv of section envelopes + `question_log`) — primary.
///  2. JSON snapshot file in the app documents dir — mirror + fallback read.
///  3. SharedPreferences — legacy source, migrated once, then never written.
///  4. Secure storage — cloud credentials only (handled by CloudSync).
///  5. Export/import share-sheet file — manual disaster recovery.
///  6. Firebase Firestore — optional cloud sync (see CloudSync).
///
/// Read order: SQLite → snapshot file → legacy prefs → defaults.
/// Write path: SQLite (authoritative) → snapshot mirror → cloud (if enabled).
class StorageHub {
  static const _sections = ['settings', 'stats', 'presets', 'lastOptions'];

  Database? _db;
  bool _dbBroken = false;
  String? _snapshotPath;

  /// In-memory section envelopes — the source of truth for the app.
  final Map<String, Envelope> sections = {};

  /// Cloud push hook, injected by CloudSync so this class stays platform-free.
  Future<void> Function(Map<String, Envelope> sections)? onLocalChange;

  // ------------------------------------------------------------ loading

  Future<void> load() async {
    await _openDb();
    await _resolveSnapshotPath();

    var loaded = <String, Envelope>{};
    if (!_dbBroken) {
      loaded = await _readSqlite();
    }

    if (loaded.isEmpty) {
      // Fallback 1: snapshot file.
      loaded = _readSnapshot();
      if (loaded.isEmpty) {
        // Fallback 2: legacy SharedPreferences (pre-layered versions).
        loaded = await _readLegacyPrefs();
        if (loaded.isNotEmpty && !_dbBroken) {
          // Materialize legacy data into the new layers.
          for (final e in loaded.entries) {
            await _writeSqlite(e.key, e.value);
          }
          await _writeSnapshot(loaded);
        }
      } else if (!_dbBroken) {
        for (final e in loaded.entries) {
          await _writeSqlite(e.key, e.value);
        }
      }
    }

    sections
      ..clear()
      ..addAll(loaded);
  }

  // ---------------------------------------------------------------- read

  Future<Map<String, Envelope>> _readSqlite() async {
    try {
      final rows = await _db!.query('state');
      return {
        for (final row in rows)
          row['key'] as String:
              jsonDecode(row['value'] as String) as Envelope,
      };
    } catch (e) {
      debugPrint('StorageHub: sqlite read failed ($e) — falling back');
      _dbBroken = true;
      return {};
    }
  }

  Map<String, Envelope> _readSnapshot() {
    try {
      final file = File(_snapshotPath!);
      if (!file.existsSync()) return {};
      final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final out = <String, Envelope>{};
      for (final name in _sections) {
        final v = raw[name];
        if (v is Map) {
          out[name] = Map<String, dynamic>.from(v);
        }
      }
      return out;
    } catch (e) {
      debugPrint('StorageHub: snapshot read failed ($e)');
      return {};
    }
  }

  Future<Map<String, Envelope>> _readLegacyPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final out = <String, Envelope>{};
      final now = DateTime.now().millisecondsSinceEpoch;

      final statsRaw = prefs.getString('katsuyou.stats');
      if (statsRaw != null) {
        out['stats'] = makeEnvelope(Map<String, dynamic>.from(jsonDecode(statsRaw) as Map), now);
      }
      final settingsRaw = prefs.getString('katsuyou.settings');
      if (settingsRaw != null) {
        out['settings'] = makeEnvelope(Map<String, dynamic>.from(jsonDecode(settingsRaw) as Map), now);
      }
      final presetsRaw = prefs.getString('katsuyou.presets');
      if (presetsRaw != null) {
        out['presets'] =
            makeEnvelope({'list': jsonDecode(presetsRaw) as List}, now);
      }
      final optionsRaw = prefs.getString('katsuyou.options');
      if (optionsRaw != null) {
        out['lastOptions'] = makeEnvelope(Map<String, dynamic>.from(jsonDecode(optionsRaw) as Map), now);
      }
      return out;
    } catch (e) {
      debugPrint('StorageHub: legacy prefs read failed ($e)');
      return {};
    }
  }

  // --------------------------------------------------------------- write

  Future<void> saveSection(String name, Map<String, dynamic> data) async {
    final envelope = makeEnvelope(data, DateTime.now().millisecondsSinceEpoch);
    sections[name] = envelope;

    if (!_dbBroken) {
      final ok = await _writeSqlite(name, envelope);
      if (!ok) _dbBroken = true;
    }
    unawaited(_writeSnapshot(sections));

    final push = onLocalChange;
    if (push != null) unawaited(push({name: envelope}));
  }

  Future<bool> _writeSqlite(String name, Envelope envelope) async {
    try {
      await _db!.insert(
        'state',
        {
          'key': name,
          'value': jsonEncode(envelope),
          'updated_at': envelope['updatedAt'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return true;
    } catch (e) {
      debugPrint('StorageHub: sqlite write failed ($e)');
      return false;
    }
  }

  Future<void> _writeSnapshot(Map<String, Envelope> sections) async {
    try {
      final file = File(_snapshotPath!);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode({
        'app': 'katsuyou',
        'version': 1,
        for (final e in sections.entries) e.key: e.value,
      }));
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('StorageHub: snapshot write failed ($e)');
    }
  }

  /// Append one answered question to the per-question log (analytics seed).
  Future<void> logQuestion({
    required String form,
    required bool correct,
  }) async {
    if (_dbBroken) return;
    try {
      await _db!.insert('question_log', {
        'ts': DateTime.now().millisecondsSinceEpoch,
        'form': form,
        'correct': correct ? 1 : 0,
      });
    } catch (_) {
      // The log is best-effort; the aggregate stats are the product.
    }
  }

  // ------------------------------------------------------- backup / cloud

  /// Canonical snapshot bytes used for both export and cloud upload.
  String snapshotJson() => jsonEncode({
        'app': 'katsuyou',
        'version': 1,
        'exportedAt': DateTime.now().millisecondsSinceEpoch,
        for (final e in sections.entries) e.key: e.value,
      });

  String? get snapshotPath => _snapshotPath;

  /// Merge a remote/imported section map into local state. Returns the merged
  /// sections that differ from local (callers persist + optionally push them).
  Future<Map<String, Envelope>> mergeInto(Map<String, Envelope?> incoming) async {
    final changed = mergeSections(local: sections, remote: incoming);
    for (final e in changed.entries) {
      sections[e.key] = e.value;
      if (!_dbBroken) await _writeSqlite(e.key, e.value);
    }
    if (changed.isNotEmpty) await _writeSnapshot(sections);
    return changed;
  }

  // --------------------------------------------------------------- setup

  Future<void> _openDb() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _db = await openDatabase(
        p.join(dir.path, 'katsuyou.db'),
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE state(
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE question_log(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              ts INTEGER NOT NULL,
              form TEXT NOT NULL,
              correct INTEGER NOT NULL
            )
          ''');
        },
      );
    } catch (e) {
      debugPrint('StorageHub: sqlite open failed ($e) — snapshot-only mode');
      _dbBroken = true;
    }
  }

  Future<void> _resolveSnapshotPath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _snapshotPath = p.join(dir.path, 'katsuyou-backup.json');
    } catch (e) {
      debugPrint('StorageHub: documents dir unavailable ($e)');
    }
  }
}
