# Publishing Katsuyou to Google Play (with ads) — checklist

Everything here needs accounts only you can create; the code side is ready.

## 1. Developer account
- Create a Google Play Console account: https://play.google.com/console (one-time USD 25).
- Identity verification is required before you can publish.

## 2. App signing
Generate an upload keystore (keep it safe — losing it means you can never update the app):

```bash
keytool -genkey -v -keystore katsuyou-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias katsuyou
```

Create `flutter_app/android/key.properties` (never commit it):

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=katsuyou
storeFile=../../katsuyou-upload.jks
```

Add to `flutter_app/android/app/build.gradle` above the `android {` block:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

and inside `android { }`:

```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
buildTypes {
    release {
        signingConfig signingConfigs.release
    }
}
```

Then build the store bundle: `flutter build appbundle --release` → upload the `.aab` from
`build/app/outputs/bundle/release/app-release.aab`.

## 3. Ads (AdMob)
1. Sign up at https://admob.google.com, create an app, note the **AdMob App ID**.
2. Add `google_mobile_ads: ^5.3.1` to `pubspec.yaml`.
3. In `android/app/src/main/AndroidManifest.xml`, inside `<application>`:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXX~YYYYYYYY"/>
```

4. Show a **banner** on the home screen and an **interstitial** between sessions
   (never inside the question flow — it wrecks the drill rhythm and reviews).
5. Play requires a **privacy policy** URL once you collect ad data; a GitHub Pages
   page (you already have the repo) works fine.

Suggested placement (fair-play for a study app):
- Banner at the bottom of Home only.
- Interstitial once when a session ends (not on cancel).

## 4. Store listing checklist
- App name: `Katsuyou: Japanese Verb Drill`
- Short description (80 chars): `Master Japanese verb & adjective conjugation with daily drills.`
- Full description: reuse README's feature list.
- Screenshots: phone (min 2), 1080×1920 — Home, quiz, explanation sheet, calendar.
- Feature graphic 1024×500, app icon 512×512 (use `flutter_app/assets/icon.png`).
- Content rating questionnaire: "Everyone" (no user content, no violence).
- Data safety form: declares AdMob data collection; app itself stores data locally only.
- Categories: Education → Education.

## 5. Credit (keep visible in the listing)
The drill is built on the work of others — keep this line in the store description:

> Based on the open-source "Don's Japanese Conjugation Drill" by wkdonc and its
> Lan-Don extension by LandonJPGinn (github.com/LandonJPGinn/jp-verb-quiz).
> Katsuyou is a native Flutter rewrite; the original web version remains free at
> landonjpginn.github.io/jp-verb-quiz.

In-app credit already ships in Settings → About.

## 6. Launch promo draft (Twitter/X)

🇯🇵 ID:
> Baru rilis KATSUYOU (活用) — app latihan konjugasi kata kerja Jepang:
> ✅ preset latihan ("hari ini N5, besok てform")
> ✅ streak & kalender progress
> ✅ statistik form mana yang lemah
> ✅ offline, tanpa iklan mengganggu
> Dibangun di atas drill open-source karya Don & LanDon (credit penuh di app).
> #JapaneseLearning #日本語 #Flutter

🇬🇧 EN mirror:
> I built KATSUYOU (活用) — a native Android app for drilling Japanese verb
> conjugations: presets, streaks, a progress calendar, and per-form weak-spot
> stats. Free, offline-first, built on the open-source Don/Lan-Don drill
> (credited in-app). Feedback welcome!

Post with 2–3 screenshots; r/LearnJapanese and the original repo's issue page
are also good announce spots (ask Landon first via the repo's feedback form).
