# Mood Widget

A lock-screen widget (Samsung Good Lock → LockStar) whose dot-matrix face
turns from green → amber → red as your screen time climbs, built with
Flutter + a native Android `AppWidgetProvider`. The card behind the face
follows your device's light/dark theme.

## Screenshots

| Home screen | Lock screen |
|---|---|
| <img width="1080" height="2340" alt="home_screen" src="https://github.com/user-attachments/assets/cd4d6a11-07b0-42b2-8135-4400063a0c92" /> | <img width="1080" height="2340" alt="lock_screen" src="https://github.com/user-attachments/assets/53732fe0-0276-4839-9a7e-beb149e9f343" /> |

The widget renders identically in both places — same dot-matrix face,
same green/amber/red state — confirming lock-screen support (via Good
Lock → LockStar) alongside the standard home-screen placement.

## Project structure

```
lib/
  main.dart                      → app entry point
  models/mood_thresholds.dart    → MoodState, happy/sad limits, slider ranges, load/save
  services/usage_service.dart    → MethodChannel wrapper (permission, screen time)
  screens/home_screen.dart       → settings UI + in-app face preview
  widgets/mood_face_painter.dart → Flutter CustomPainter (mirrors the widget look)
test/
  mood_thresholds_test.dart      → unit tests for mood selection and slider maths

android/app/src/main/
  kotlin/.../
    MainActivity.kt             → MethodChannel for usage-access check & screen time
    MoodWidgetProvider.kt       → AppWidgetProvider — draws the dot mask on a Bitmap
    MoodWorker.kt               → periodic WorkManager worker that triggers updates
    UsageStatsHelper.kt         → reads total screen-on time since midnight
  res/
    layout/mood_widget.xml      → widget layout (single ImageView)
    drawable/widget_background.xml → the widget card (fill + border)
    values/colors.xml           → card colours, light theme
    values-night/colors.xml     → card colours, dark theme
    xml/mood_widget_info.xml    → AppWidgetProviderInfo
    values/mood_widget_strings.xml → widget label and accessibility strings

pubspec.yaml                    → home_widget dependency already added
```

> **This is a ready-to-build project.** All native widget code is already
> wired into the `android/` Gradle project — no manual copy steps needed.

## Quick start

```bash
flutter pub get
flutter run
```

Then on device:

1. Tap **Grant** → enable Usage Access for Mood Widget.
2. Set your happy / sad thresholds and tap **Save & update widget**.
3. Long-press home screen → **Widgets** → add **Mood Widget** to confirm it renders.
4. For the **lock screen**: install Good Lock + LockStar (Galaxy Store), open
   LockStar → Widgets, and add Mood Widget.

## Face design

The dot-matrix face is drawn in both the Flutter `CustomPainter` (in-app
preview) and the native `MoodWidgetProvider` (actual widget bitmap) from the
same proportions (`FaceGeometry` in both files), so the two look identical.
Features:

- **Phone outline** — dotted rounded-rect border
- **Eyes** — two dots, symmetric either side of centre
- **Nose** — L-shaped dot pattern: 4 dots going down (the top one at eye level), 1 foot turning right
- **Mouth** — 5-dot arc: curves **down** (smile ∪) when green, flat when amber, curves **up** (frown ∩) when red

| Screen time | Mood colour | Expression |
|-------------|-------------|------------|
| < happy threshold | 🟢 Green  | Smile |
| happy … sad  | 🟡 Amber  | Neutral |
| ≥ sad threshold  | 🔴 Red    | Frown |
| Usage Access not granted | ⚪ Grey | Neutral |

### Theme

The card background depends **only on the device theme**, never on the mood:
light mode shows a white card, dark mode a dark one. The mood only changes the
dots, which use a slightly different shade per theme for contrast.

On Android 12+ the launcher resolves both the card and the dot colour itself,
so the widget flips as soon as the theme changes. On older versions the dots
pick up the new theme on the next update (within ~15 minutes, or when the app
is opened).

## Notes

- **Update cadence:** Android enforces a 15-minute floor on WorkManager jobs,
  so the widget face can lag reality by up to ~15 minutes. The job starts when
  the first widget is added and stops when the last one is removed.
- **Screen time source:** `UsageStatsHelper` sums `SCREEN_INTERACTIVE` /
  `SCREEN_NON_INTERACTIVE` events since midnight (including a screen-on span
  that started the evening before) — total device screen-on time, not per-app
  usage.
- **Thresholds** are stored via `home_widget`'s shared preferences and read
  by both the Flutter UI and the native widget. They are loaded when the app
  opens, and changes reach the widget after tapping Save.
- **`home_widget` import:** `MoodWidgetProvider.kt` imports
  `es.antonborri.home_widget.HomeWidgetPlugin` — correct for `home_widget`
  0.7.x. If you upgrade the package and the import breaks, check the new
  package name with `flutter pub deps`.

## Releasing

Release APKs are built by `.github/workflows/release.yml` on pushes to `main`
and on `v*.*.*` tags (tags also publish a GitHub Release).

To sign releases with your own key (so each release installs as an in-place
update), create a keystore once and add these repository secrets:

| Secret | Value |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |

Locally, put the same values in `android/key.properties` (git-ignored):

```
storeFile=/absolute/path/to/release.jks
storePassword=...
keyAlias=...
keyPassword=...
```

Without a keystore the build falls back to the debug key, which is fine for
testing but not for distributing updates.
