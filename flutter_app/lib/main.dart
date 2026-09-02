import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'engine/conjugation.dart';
import 'state/app_store.dart';
import 'storage/storage_hub.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Expose the semantics tree in debug/profile so UI-automation tooling
  // (uiautomator) can read labels and bounds during testing.
  if (kDebugMode) {
    SemanticsBinding.instance.ensureSemantics();
  }

  final store = AppStore(StorageHub());
  await store.load();

  final engine = await ConjugationEngine.loadAssets();

  runApp(KatsuyouApp(engine: engine, store: store));
}

class KatsuyouApp extends StatefulWidget {
  final ConjugationEngine engine;
  final AppStore store;

  const KatsuyouApp({super.key, required this.engine, required this.store});

  @override
  State<KatsuyouApp> createState() => _KatsuyouAppState();
}

class _KatsuyouAppState extends State<KatsuyouApp> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
  }

  void _onStoreChanged() => setState(() {});

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.store.settings;
    final dark = settings.theme == ThemeSetting.dark ||
        (settings.theme == ThemeSetting.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return MaterialApp(
      title: 'Katsuyou',
      debugShowCheckedModeBanner: false,
      theme: dark ? buildDarkTheme() : buildTheme(),
      home: HomeScreen(engine: widget.engine, store: widget.store),
    );
  }
}
