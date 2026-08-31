import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'merge.dart';
import 'storage_hub.dart';

/// Optional Firebase cloud sync (layer 6).
///
/// Deliberately configured at RUNTIME (not at build time) so the app builds
/// without a google-services.json: the user pastes their Firebase web-app
/// credentials in Settings → Cloud sync. Credentials live in encrypted
/// storage; the study data itself lives in one Firestore doc per user:
///
///   users/{uid} → { settings: {data, updatedAt}, stats: ..., ... }
///
/// Required Firestore rules:
///   match /users/{uid} { allow read, write: if request.auth.uid == uid; }
class CloudSync {
  static const _secure = FlutterSecureStorage();
  static const _kConfig = 'katsuyou.cloud.config';
  static const _kEmail = 'katsuyou.cloud.email';
  static const _kPassword = 'katsuyou.cloud.password';

  bool _connected = false;
  bool get isConnected => _connected;
  FirebaseApp? _app;
  StorageHub? _hub;

  Future<Map<String, String>?> readConfig() async {
    final raw = await _secure.read(key: _kConfig);
    if (raw == null) return null;
    return Map<String, String>.from(jsonDecode(raw) as Map);
  }

  Future<String?> readEmail() => _secure.read(key: _kEmail);

  /// Initializes Firebase with runtime options, signs in, pulls + merges.
  /// Throws on any failure; [StorageHub.mergeInto] is only called on success.
  Future<void> connect({
    required StorageHub hub,
    required String apiKey,
    required String projectId,
    required String appId,
    required String messagingSenderId,
    required String email,
    required String password,
  }) async {
    _hub = hub;
    final options = FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
    );

    _app ??= Firebase.apps.isEmpty
        ? await Firebase.initializeApp(options: options)
        : Firebase.apps.first;
    _connected = false;

    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = cred.user!.uid;
    final doc = FirebaseFirestore.instance.collection('users').doc(uid);

    // Pull remote, merge into local.
    final snap = await doc.get();
    Map<String, Envelope>? remote;
    if (snap.exists) {
      remote = {
        for (final e
            in ((snap.data()!['sections'] as Map?) ?? {}).entries)
          e.key as String: Map<String, dynamic>.from(e.value as Map),
      };
    }

    final changed = await hub.mergeInto(remote ?? {});

    // Push: always write the merged local view (covers both directions).
    await doc.set({
      'sections': {
        for (final e in hub.sections.entries) e.key: e.value,
      },
      'syncedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _secure.write(key: _kConfig, value: jsonEncode({
      'apiKey': apiKey,
      'projectId': projectId,
      'appId': appId,
      'messagingSenderId': messagingSenderId,
    }));
    await _secure.write(key: _kEmail, value: email);
    await _secure.write(key: _kPassword, value: password);

    _connected = true;
    hub.onLocalChange = _pushChanged;

    if (changed.isNotEmpty) {
      debugPrint('CloudSync: merged ${changed.keys.toList()} from remote');
    }
  }

  /// Live push of locally changed sections (debounced by the caller).
  Future<void> _pushChanged(Map<String, Envelope> changed) async {
    if (!_connected) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'sections': {for (final e in changed.entries) e.key: e.value},
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('CloudSync: push failed ($e) — will retry on next change');
      // Data is already safe locally; failed pushes self-heal on the next save.
    }
  }

  Future<void> pull(StorageHub hub) async {
    if (!_connected) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return;
    final remote = <String, Envelope>{
      for (final e
          in ((doc.data()!['sections'] as Map?) ?? {}).entries)
        e.key as String: Map<String, dynamic>.from(e.value as Map),
    };
    final changed = await hub.mergeInto(remote);
    if (changed.isNotEmpty) await _pushChanged(hub.sections);
  }

  Future<void> disconnect() async {
    _connected = false;
    _hub?.onLocalChange = null;
    _hub = null;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await _secure.delete(key: _kConfig);
    await _secure.delete(key: _kEmail);
    await _secure.delete(key: _kPassword);
  }

}
