import 'package:flutter/material.dart';

import '../state/app_store.dart';
import '../storage/cloud_sync.dart';
import 'theme.dart';

/// Dedicated configuration page for Firebase cloud sync. Everything happens
/// here — paste credentials, connect, sync now, disconnect — with the
/// keyboard-friendly scroll and clear step-by-step setup guidance.
class CloudSyncScreen extends StatefulWidget {
  final AppStore store;

  const CloudSyncScreen({super.key, required this.store});

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  final _apiKey = TextEditingController();
  final _projectId = TextEditingController();
  final _appId = TextEditingController();
  final _senderId = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  final _cloud = CloudSync();
  bool _busy = false;
  bool _connected = false;
  bool _showSteps = false;
  String? _message;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadStored();
  }

  Future<void> _loadStored() async {
    final config = await _cloud.readConfig();
    final email = await _cloud.readEmail();
    if (!mounted) return;
    if (config != null) {
      _apiKey.text = config['apiKey'] ?? '';
      _projectId.text = config['projectId'] ?? '';
      _appId.text = config['appId'] ?? '';
      _senderId.text = config['messagingSenderId'] ?? '';
      _connected = true; // stored config means it was connected before
    }
    if (email != null) _email.text = email;
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in [
      _apiKey,
      _projectId,
      _appId,
      _senderId,
      _email,
      _password,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _connect() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      await _cloud.connect(
        hub: widget.store.hub,
        apiKey: _apiKey.text.trim(),
        projectId: _projectId.text.trim(),
        appId: _appId.text.trim(),
        messagingSenderId: _senderId.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      setState(() {
        _connected = true;
        _message = 'Connected. Every save now uploads, and "Sync now" pulls anything newer.';
      });
      widget.store.reloadFromHub();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _message = _friendlyError(e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    if (text.contains('operation-not-allowed')) {
      return 'Email/Password sign-in is not enabled yet — enable it in your '
          'Firebase console (Authentication → Sign-in method).';
    }
    if (text.contains('invalid-credential') ||
        text.contains('wrong-password') ||
        text.contains('user-not-found')) {
      return 'Wrong email or password for that Firebase account.';
    }
    if (text.contains('network')) {
      return 'Network error — check your connection and try again.';
    }
    if (text.contains('invalid-api-key') || text.contains('api-key')) {
      return 'The API key looks wrong — copy it from Firebase project settings.';
    }
    return 'Connection failed: ${text.split('\n').first}';
  }

  Future<void> _syncNow() async {
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      await _cloud.pull(widget.store.hub);
      await widget.store.reloadFromHub();
      if (!mounted) return;
      setState(
        () => _message = 'Synced — merged anything newer from the cloud.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _message = 'Sync failed: ${e.toString().split('\n').first}';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    await _cloud.disconnect();
    if (!mounted) return;
    setState(() {
      _connected = false;
      _message = 'Disconnected. Local data stays untouched.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud sync')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewPaddingOf(context).bottom + 32,
        ),
        children: [
          Text(
            _connected
                ? 'Connected. Every save uploads automatically; "Sync now" '
                      'merges anything newer from the cloud into this device.'
                : 'Keep your streak and stats identical on every device. Your '
                      'data lives in your own free Firebase project — this app '
                      'never sees it.',
            style: const TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: 16),
          if (_connected) ...[
            FilledButton.icon(
              onPressed: _busy ? null : _syncNow,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: const Text('Sync now'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _disconnect,
              icon: const Icon(Icons.link_off),
              label: const Text('Disconnect'),
            ),
          ] else ...[
            // ------------------------------------------------ setup steps
            Card(
              child: ListTile(
                leading: Icon(
                  _showSteps ? Icons.unfold_less : Icons.help_outline,
                  color: AppColors.indigo,
                ),
                title: const Text('How do I get these credentials?'),
                subtitle: const Text('5-minute setup, free tier is enough'),
                onTap: () => setState(() => _showSteps = !_showSteps),
              ),
            ),
            if (_showSteps)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        [
                              _step(
                                '1',
                                'console.firebase.google.com → Add project.',
                              ),
                              _step(
                                '2',
                                'Build → Authentication → Sign-in method → enable Email/Password → Add user (any email + password).',
                              ),
                              _step(
                                '3',
                                'Build → Firestore Database → Create database (production mode).',
                              ),
                              _step(
                                '4',
                                'Firestore → Rules → paste the rules below → Publish.',
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "rules_version = '2';\n"
                                  'service cloud.firestore {\n'
                                  '  match /databases/{database}/documents {\n'
                                  '    match /users/{uid} {\n'
                                  '      allow read, write: if request.auth.uid == uid;\n'
                                  '    }\n'
                                  '  }\n'
                                  '}',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                              _step(
                                '5',
                                'Project settings (gear) → General → Your apps → Web app (</>) → copy the config values below.',
                              ),
                            ]
                            .expand((w) => [w, const SizedBox(height: 8)])
                            .toList()
                          ..removeLast(),
                  ),
                ),
              ),
            // ------------------------------------------------ form
            const SizedBox(height: 8),
            _field(_apiKey, 'API key'),
            _field(_projectId, 'Project ID'),
            _field(_appId, 'App ID'),
            _field(_senderId, 'Messaging sender ID'),
            _field(_email, 'Account email'),
            _field(_password, 'Account password', obscure: true),
            const SizedBox(height: 8),
            Text(
              'Credentials are stored encrypted on this device only.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _connect,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: const Text('Connect & sync'),
            ),
          ],
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _message!,
                style: TextStyle(
                  fontSize: 13,
                  color: _error ? AppColors.error : AppColors.success,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _step(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.indigo,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        obscuringCharacter: '•',
        autofillHints: obscure ? [AutofillHints.password] : null,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
