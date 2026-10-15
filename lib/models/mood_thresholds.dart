import 'dart:math' as math;

import 'package:home_widget/home_widget.dart';

/// The face shown in the app preview and on the home/lock-screen widget.
///
/// [noAccess] is shown while Usage Access hasn't been granted, so the widget
/// never claims "happy" just because it can't read any screen time.
enum MoodState { happy, neutral, sad, noAccess }

/// User-configurable screen-time limits plus the pure logic that depends on
/// them (mood selection and slider ranges), kept free of Flutter widgets so
/// it can be unit tested.
class MoodThresholds {
  const MoodThresholds({
    this.happyHours = defaultHappyHours,
    this.sadHours = defaultSadHours,
  });

  /// Builds thresholds from untrusted input (e.g. stored values): snaps to
  /// the slider step, clamps to a sane range and keeps `sad >= happy`.
  factory MoodThresholds.normalized(double happy, double sad) {
    final happyHours = _clamp(snap(happy), minHappyHours, maxHours);
    final sadHours =
        _clamp(snap(sad), happyHours, _sadSliderMaxFor(happyHours));
    return MoodThresholds(happyHours: happyHours, sadHours: sadHours);
  }

  static const defaultHappyHours = 2.0;
  static const defaultSadHours = 4.0;

  /// Slider granularity, in hours.
  static const step = 0.5;
  static const minHappyHours = 0.5;
  static const maxHours = 24.0;

  /// The happy slider never goes below this maximum…
  static const _minHappySliderMax = 6.0;

  /// …and the sad slider never goes below this maximum.
  static const _minSadSliderMax = 10.0;

  /// Keys shared with the native widget (see MoodWidgetProvider.kt).
  static const happyKey = 'happyLimitHours';
  static const sadKey = 'sadLimitHours';

  final double happyHours;
  final double sadHours;

  /// Mirrors `UsageStatsHelper.moodFor` on the Kotlin side — keep in sync.
  MoodState moodFor(double screenHours) {
    if (screenHours < happyHours) return MoodState.happy;
    if (screenHours < sadHours) return MoodState.neutral;
    return MoodState.sad;
  }

  MoodThresholds withHappy(double hours) {
    final happy = snap(hours);
    return MoodThresholds(
      happyHours: happy,
      // keep sad >= happy so the sad slider's min never exceeds its value
      sadHours: math.max(sadHours, happy),
    );
  }

  MoodThresholds withSad(double hours) =>
      MoodThresholds(happyHours: happyHours, sadHours: snap(hours));

  /// Happy slider max: always strictly above today's screen time, rounded up
  /// to the next [step], with a floor of 6 h.
  static double happySliderMax(double screenHours) {
    final needed = ((screenHours / step).ceil() + 1) * step;
    return math.max(needed, _minHappySliderMax);
  }

  static int happySliderDivisions(double max) =>
      ((max - minHappyHours) / step).round();

  /// Sad slider max: 10 h, or just above the happy value if that is higher
  /// (the happy slider can grow past 10 h on very heavy-usage days).
  double get sadSliderMax => _sadSliderMaxFor(happyHours);

  /// Divisions derived from the real range so every tick is exactly [step].
  int get sadSliderDivisions => ((sadSliderMax - happyHours) / step).round();

  static double snap(double hours) => (hours / step).round() * step;

  static double _sadSliderMaxFor(double happyHours) =>
      math.max(_minSadSliderMax, happyHours + step);

  static double _clamp(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);

  /// Loads the values last saved for the widget, falling back to defaults.
  static Future<MoodThresholds> load() async {
    try {
      final happy = await HomeWidget.getWidgetData<double>(
        happyKey,
        defaultValue: defaultHappyHours,
      );
      final sad = await HomeWidget.getWidgetData<double>(
        sadKey,
        defaultValue: defaultSadHours,
      );
      return MoodThresholds.normalized(
        happy ?? defaultHappyHours,
        sad ?? defaultSadHours,
      );
    } on Exception {
      return const MoodThresholds();
    }
  }

  /// Writes the values into the SharedPreferences file the native
  /// AppWidgetProvider reads from. Throws on platform errors.
  Future<void> save() async {
    await HomeWidget.saveWidgetData<double>(happyKey, happyHours);
    await HomeWidget.saveWidgetData<double>(sadKey, sadHours);
  }
}
