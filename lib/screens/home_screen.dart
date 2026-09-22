import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../widgets/mood_face_painter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Must match the MethodChannel name used in MainActivity.kt
  static const _channel = MethodChannel('mood_widget/usage');

  double happyLimitHours = 2;
  double sadLimitHours = 4;
  bool? hasUsageAccess;
  int screenOnMinutesToday = 0;

  /// Refreshes screen-time every 60 s while the app is open.
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshPermission();
    _refreshScreenTime();
    // Kick off live updates — re-fetch usage every 60 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refreshScreenTime(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshPermission() async {
    final granted =
        await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
    if (mounted) setState(() => hasUsageAccess = granted);
  }

  Future<void> _refreshScreenTime() async {
    final minutes =
        await _channel.invokeMethod<int>('getScreenOnMinutesToday') ?? 0;
    if (mounted) setState(() => screenOnMinutesToday = minutes);
  }

  MoodState get _previewState {
    final hours = screenOnMinutesToday / 60;
    if (hours < happyLimitHours) return MoodState.happy;
    if (hours < sadLimitHours) return MoodState.neutral;
    return MoodState.sad;
  }

  /// Happy slider max: always at least 0.5 h above today's screen time,
  /// rounded up to the nearest 0.5 h step, with a floor of 6 h.
  double get _happyMax {
    final screenHours = screenOnMinutesToday / 60.0;
    // Round up to next 0.5 h boundary, then add one more step so the
    // slider's rightmost tick is always strictly above current usage.
    final needed = ((screenHours / 0.5).ceil() + 1) * 0.5;
    return needed > 6.0 ? needed : 6.0;
  }

  Future<void> _saveAndUpdateWidget() async {
    // home_widget writes these into the same SharedPreferences file the
    // native AppWidgetProvider reads from (see MoodWidgetProvider.kt).
    await HomeWidget.saveWidgetData<double>('happyLimitHours', happyLimitHours);
    await HomeWidget.saveWidgetData<double>('sadLimitHours', sadLimitHours);
    await HomeWidget.updateWidget(
      name: 'MoodWidgetProvider',
      androidName: 'MoodWidgetProvider',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Saved — the widget will refresh shortly')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mood Widget')),
      body: RefreshIndicator(
        onRefresh: () async {
          await _refreshPermission();
          await _refreshScreenTime();
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: SizedBox(
                width: 160,
                height: 160,
                child: CustomPaint(
                  painter: MoodFacePainter(_previewState),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${(screenOnMinutesToday / 60).toStringAsFixed(1)}h on screen today',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
            if (hasUsageAccess == false)
              Card(
                color: Colors.red.shade900,
                child: ListTile(
                  title: const Text('Usage access needed'),
                  subtitle: const Text(
                      'Grant access so the widget can read your screen time.'),
                  trailing: FilledButton(
                    onPressed: () async {
                      await _channel.invokeMethod('openUsageAccessSettings');
                    },
                    child: const Text('Grant'),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text('Happy below: ${happyLimitHours.toStringAsFixed(1)}h'),
            Slider(
              value: happyLimitHours.clamp(0.5, _happyMax),
              min: 0.5,
              max: _happyMax,
              // steps of 0.5 h across the dynamic range
              divisions: ((_happyMax - 0.5) / 0.5).round(),
              label: '${happyLimitHours.toStringAsFixed(1)}h',
              onChanged: (v) => setState(() {
                happyLimitHours = v;
                // keep sad >= happy so the sad slider's min never exceeds its value
                if (sadLimitHours < happyLimitHours) {
                  sadLimitHours = happyLimitHours;
                }
              }),
            ),
            Text('Sad above: ${sadLimitHours.toStringAsFixed(1)}h'),
            Slider(
              value: sadLimitHours,
              min: happyLimitHours,
              max: 10,
              divisions: 19,
              label: '${sadLimitHours.toStringAsFixed(1)}h',
              onChanged: (v) => setState(() => sadLimitHours = v),
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
            const Text(
              'Then: long-press your lock screen → Widgets (or open Good Lock '
              '→ LockStar) and add "Mood Widget" like any other widget.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
