# LanDon's Japanese Verb Conjugation Drill
##### Landon's Extension to the widely popular Don's Japanese Conjugation Drill

# Credits
- Original drill: [Don's Japanese Conjugation Drill](https://github.com/wkdonc/conjugation) by wkdonc
- This fork & extension: [LandonJPGinn/jp-verb-quiz](https://github.com/LandonJPGinn/jp-verb-quiz) by Landon Ginn
- The mobile apps in `app/` (Capacitor) and `flutter_app/` (Katsuyou) are built on top of this work — the in-app About screen and store listing credit both upstream repos. See [PUBLISHING.md](PUBLISHING.md) for the Play Store launch checklist.

# About
Forked from the original Don's Japanese Conjugation Drill, LanDon's Extended version brings a bit more features to help you level up your practice sessions.
Verb conjugation can be a complicated thing. Drill yourself on conjugation forms to help you recall patterns for different verb types.
This is a work in progress site.


# How to use
Just like Dons original site, but more stuff.
- Set your initial filters that youd like to receive prompts about and start the game
- the quiz will prompt you with a request to conjugate verbs into a specific change/form
- type out the conjugation you believe it is (english letters will convert to hiragana)
- the quiz will tell you if you are right or wrong and explain why you might be wrong

# Mobile / Install as an App
The drill is a Progressive Web App (PWA): it installs to your home screen and works fully offline.
- **Android (Chrome):** open the site, tap menu → *Add to Home screen* / *Install app*.
- **iPhone (Safari):** open the site, tap Share → *Add to Home Screen*.
- After the first visit online, all quiz data is cached by a service worker, so practice works without a connection.

# Development notes
- Bootstrap and jQuery are vendored under `conjugation/vendor/` so the app has no runtime CDN dependency.
- `conjugation/sw.js` precaches the app shell and data. If you change `drill.js`, `rules.js`, `words.json`, or any precached asset, bump `CACHE_VERSION` in `sw.js` so returning users get the update.

# Native App (Capacitor)
The `app/` folder wraps the same web app into a native Android app with Capacitor (appId `com.landonjp.verbquiz`, name "JP Conjugation"). The web source stays in `conjugation/` — one codebase for both the PWA and the native app.

Prerequisites: Node.js, JDK 21+, and an Android SDK (set `sdk.dir` in `app/android/local.properties` or the `ANDROID_HOME` env var).

```bash
cd app
npm install
npx cap sync android          # copy conjugation/ into the Android project after web changes
cd android
gradlew.bat assembleDebug     # -> app/build/outputs/apk/debug/app-debug.apk
gradlew.bat assembleRelease   # release build (signing config required for Play Store)
```

Icons and splash screens are generated from `app/assets/icon.png` / `splash.png` (the 動 mark) with `npx capacitor-assets generate --android`.

For Play Store distribution, generate an upload keystore and add a signing config to `app/android/app/build.gradle`, or open the project in Android Studio via `npx cap open android`. For iOS, `npx cap add ios` requires macOS with Xcode.

# Native App (Flutter) — 活 Katsuyou
The `flutter_app/` folder is a full native rewrite in Flutter/Dart named **Katsuyou** (活用 — Japanese for "conjugation"). The conjugation engine and quiz logic from `rules.js`/`drill.js` are ported to Dart under `lib/engine/`, and the same `words.json`/`rules.json` data ships as bundled assets.

Beyond the original drill it adds:
- **Home dashboard** — daily streak (with best-streak tracking), daily goal ring, 7-day activity chart, quick-start preset cards.
- **Presets** — save named option sets ("N5 warm-up", "causative drill"…) from the customize screen and start them with one tap from home.
- **Settings screen** — submit via Enter or Check button, auto-advance on correct, auto-explain on mistakes, romaji conversion on/off, furigana on/off, daily goal, dark mode. Behaviour toggles no longer clutter the round options.
- **Cancel mid-session** — the ✕ button (or back gesture) asks for confirmation; answers already given still count toward daily stats.
- **Redesigned quiz UI** — card-based questions with furigana, shake on invalid input, green/red feedback cards with struck-through wrong answers, and a Kanji Study-style explanation bottom sheet (root word, example sentence, 3-step breakdown, notes).
- **Caps-Lock-friendly typing** — the romaji→hiragana converter is case-insensitive.

```bash
cd flutter_app
flutter pub get
flutter test                      # engine, romaji, streak & preset unit tests
flutter build apk --split-per-abi # -> build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (~17MB)
flutter run                       # on a connected device / emulator
```

Launcher icons (the 活 mark) are generated from `assets/icon.png` / `assets/icon_fg.png` with `dart run flutter_launcher_icons`. Debug builds force-enable the Flutter semantics tree so uiautomator can drive the UI in automated tests.

# Why extend?
I had been using Don's conjugation practice for a while on my own and found it incredibly useful. However, I also really wished that there was more to the site.
- More verbs
- More conjugation options
- More helper verbs
- More adjectives

I noticed that the website was a github site, meaning there could be an active repository of code. However it had been over two years since anyone participated on maintaining the code. 
So I forked it and figured I could continue that work and learn the code base a bit.

# Next Up
- Moreverbs
- More adjectives
- Support filtering by JLPT levels
- Support Filtering by most common verbs
- Add example sentences.
- Add sound bytes
- More redesigning
- Performance improvements ( because more verbs == slower site currently )


# Who is Landon?
You can find a bit of my bio on my page but the short of it is I am a programmer with work history at Disney, Nickelodeon, and worked some time in Japan for a company that made cinematics for Nintendo called Anima.
I am a technology obsessive with my roots as an artist. I dabble in a whole lot of projects ranging from book authorship, music, photography, youtube, and games... to coffee, dogs, whisky, bouldering and more.
I am still studying Japanese and need a solid set of tools to help myself learn. So here we are.
