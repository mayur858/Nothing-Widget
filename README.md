# Mood Widget

A lock-screen widget (Samsung Good Lock → LockStar) whose dot-matrix face
turns from green → amber → red as your screen time climbs, built with
Flutter + a native Android `AppWidgetProvider`.

## Screenshots

| Home screen | Lock screen |
|---|---|
| <img width="1080" height="2340" alt="home_screen" src="https://github.com/user-attachments/assets/cd4d6a11-07b0-42b2-8135-4400063a0c92" />
| <img width="1080" height="2340" alt="lock_screen" src="https://github.com/user-attachments/assets/53732fe0-0276-4839-9a7e-beb149e9f343" /> |

The widget renders identically in both places — same dot-matrix face,
same green/amber/red state — confirming lock-screen support (via Good
Lock → LockStar) alongside the standard home-screen placement.

## Project structure

```
lib/
  main.dart                     → app entry point
  screens/home_screen.dart      → settings UI + in-app face preview
  widgets/mood_face_painter.dart→ Flutter CustomPainter (mirrors the widget look)

android/app/src/main/
  kotlin/.../
    MainActivity.kt             → MethodChannel for usage-access check & screen time
    MoodWidgetProvider.kt       → AppWidgetProvider — draws the dot-face on a Bitmap
    MoodWorker.kt               → periodic WorkManager worker that triggers updates
    UsageStatsHelper.kt         → reads total screen-on time since midnight
  res/
    layout/mood_widget.xml      → widget layout (single ImageView)
    xml/mood_widget_info.xml    → AppWidgetProviderInfo
    values/strings.xml          → widget label string

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
preview) and the native `MoodWidgetProvider` (actual widget bitmap) so the
two always look identical. Features:

- **Phone outline** — dotted rounded-rect border
- **Eyes** — two dots, symmetric either side of centre
- **Nose** — L-shaped dot pattern: 3 dots going down, 1 dot turning right
- **Mouth** — 5-dot arc: curves **down** (smile ∪) when green, flat when amber, curves **up** (frown ∩) when red

| Screen time | Colour | Expression |
|-------------|--------|------------|
| < happy threshold | 🟢 Green  | Smile |
| happy … sad  | 🟡 Amber  | Neutral |
| ≥ sad threshold  | 🔴 Red    | Frown |

## Notes

- **Update cadence:** Android enforces a 15-minute floor on WorkManager jobs,
  so the widget face can lag reality by up to ~15 minutes.
- **Screen time source:** `UsageStatsHelper` sums `SCREEN_INTERACTIVE` /
  `SCREEN_NON_INTERACTIVE` events since midnight — total device screen-on
  time, not per-app usage.
- **Thresholds** are stored via `home_widget`'s shared preferences and read
  by both the Flutter UI and the native widget, so changes take effect
  immediately after tapping Save.
- **`home_widget` import:** `MoodWidgetProvider.kt` imports
  `es.antonborri.home_widget.HomeWidgetPlugin` — correct for `home_widget`
  0.7.x. If you upgrade the package and the import breaks, check the new
  package name with `flutter pub deps`.
