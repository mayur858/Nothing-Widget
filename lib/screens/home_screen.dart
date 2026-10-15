import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../models/mood_thresholds.dart';
import '../services/usage_service.dart';
import '../widgets/mood_face_painter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _usage = UsageService();

  MoodThresholds thresholds = const MoodThresholds();
  bool? hasUsageAccess;
  int screenOnMinutesToday = 0;

  /// Refreshes screen-time every 60 s while the app is in the foreground.
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThresholds();
    _refreshAll();
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // The user may have just granted Usage Access in system settings, so
        // re-check everything and repaint the widget with fresh data.
        _refreshAll(syncWidget: true);
        _startTimer();
      case AppLifecycleState.paused:
        _stopTimer();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refreshScreenTime(),
    );
  }

  void _stopTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _loadThresholds() async {
    final loaded = await MoodThresholds.load();
    if (mounted) setState(() => thresholds = loaded);
  }

  Future<void> _refreshAll({bool syncWidget = false}) async {
    await Future.wait([_refreshPermission(), _refreshScreenTime()]);
    if (syncWidget) await _updateWidget();
  }

  Future<void> _refreshPermission() async {
    final granted = await _usage.hasUsageAccess();
    if (mounted) setState(() => hasUsageAccess = granted);
  }

  Future<void> _refreshScreenTime() async {
    final minutes = await _usage.screenOnMinutesToday();
    // Keep the previous value if the read failed.
    if (minutes != null && mounted) {
      setState(() => screenOnMinutesToday = minutes);
    }
  }

  /// Asks the native provider to repaint. Returns false if that failed.
  Future<bool> _updateWidget() async {
    try {
      await HomeWidget.updateWidget(
        name: 'MoodWidgetProvider',
        androidName: 'MoodWidgetProvider',
      );
      return true;
    } on Exception {
      return false;
    }
  }

  MoodState get _previewState => hasUsageAccess == false
      ? MoodState.noAccess
      : thresholds.moodFor(screenOnMinutesToday / 60);

  Future<void> _saveAndUpdateWidget() async {
    var saved = true;
    try {
      // home_widget writes these into the same SharedPreferences file the
      // native AppWidgetProvider reads from (see MoodWidgetProvider.kt).
      await thresholds.save();
      saved = await _updateWidget();
    } on Exception {
      saved = false;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved
            ? 'Saved — the widget will refresh shortly'
            : "Couldn't update the widget. Please try again."),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final screenHours = screenOnMinutesToday / 60;
    final happyMax = MoodThresholds.happySliderMax(screenHours);
    final happyValue = math.min(thresholds.happyHours, happyMax);

    return Scaffold(
      appBar: AppBar(title: const Text('Mood Widget')),
      body: RefreshIndicator(
        onRefresh: () => _refreshAll(syncWidget: true),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Semantics(
                image: true,
                label: 'Mood face: ${_previewState.label}',
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: CustomPaint(
                    painter: MoodFacePainter(_previewState, brightness),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${screenHours.toStringAsFixed(1)}h on screen today',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 24),
            if (hasUsageAccess == false)
              Card(
                color: scheme.errorContainer,
                child: ListTile(
                  textColor: scheme.onErrorContainer,
                  title: const Text('Usage access needed'),
                  subtitle: const Text(
                      'Grant access so the widget can read your screen time.'),
                  trailing: FilledButton(
                    onPressed: _usage.openUsageAccessSettings,
                    child: const Text('Grant'),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text('Happy below: ${thresholds.happyHours.toStringAsFixed(1)}h'),
            Slider(
              value: happyValue,
              min: MoodThresholds.minHappyHours,
              max: happyMax,
              divisions: MoodThresholds.happySliderDivisions(happyMax),
              label: '${happyValue.toStringAsFixed(1)}h',
              onChanged: (v) => setState(() {
                thresholds = thresholds.withHappy(v);
              }),
            ),
            Text('Sad above: ${thresholds.sadHours.toStringAsFixed(1)}h'),
            Slider(
              value: thresholds.sadHours,
              min: thresholds.happyHours,
              max: thresholds.sadSliderMax,
              divisions: thresholds.sadSliderDivisions,
              label: '${thresholds.sadHours.toStringAsFixed(1)}h',
              onChanged: (v) => setState(() {
                thresholds = thresholds.withSad(v);
              }),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saveAndUpdateWidget,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Save & update widget'),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Then: long-press your lock screen → Widgets (or open Good Lock '
              '→ LockStar) and add "Mood Widget" like any other widget.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
