import 'package:flutter_test/flutter_test.dart';
import 'package:mood_widget_app/models/mood_thresholds.dart';

void main() {
  group('MoodThresholds.moodFor', () {
    const t = MoodThresholds(); // happy < 2h, sad >= 4h

    test('is happy below the happy limit', () {
      expect(t.moodFor(0), MoodState.happy);
      expect(t.moodFor(1.99), MoodState.happy);
    });

    test('is neutral between the limits (lower bound inclusive)', () {
      expect(t.moodFor(2.0), MoodState.neutral);
      expect(t.moodFor(3.99), MoodState.neutral);
    });

    test('is sad at and above the sad limit', () {
      expect(t.moodFor(4.0), MoodState.sad);
      expect(t.moodFor(12), MoodState.sad);
    });
  });

  group('slider ranges', () {
    test('happy slider max is strictly above usage with a 6h floor', () {
      expect(MoodThresholds.happySliderMax(0), 6.0);
      expect(MoodThresholds.happySliderMax(5.5), 6.0);
      expect(MoodThresholds.happySliderMax(6.2), 7.0);
      expect(MoodThresholds.happySliderMax(6.0), 6.5);
    });

    test('sad slider ticks are always exactly 0.5h apart', () {
      for (final happy in [0.5, 1.0, 2.0, 3.5, 9.5, 10.0, 11.5]) {
        final t = MoodThresholds(happyHours: happy, sadHours: happy);
        final stepSize =
            (t.sadSliderMax - happy) / t.sadSliderDivisions;
        expect(stepSize, MoodThresholds.step, reason: 'happy=$happy');
      }
    });

    test('sad slider max never drops below its min', () {
      const t = MoodThresholds(happyHours: 10.5, sadHours: 10.5);
      expect(t.sadSliderMax, 11.0);
      expect(t.sadSliderMax, greaterThan(t.happyHours));
      expect(t.sadSliderDivisions, 1);
    });
  });

  group('editing', () {
    test('raising happy above sad pushes sad up with it', () {
      final t = const MoodThresholds().withHappy(5);
      expect(t.happyHours, 5.0);
      expect(t.sadHours, 5.0);
    });

    test('lowering happy leaves sad untouched', () {
      final t = const MoodThresholds().withHappy(1);
      expect(t.happyHours, 1.0);
      expect(t.sadHours, 4.0);
    });

    test('values snap to the 0.5h step', () {
      final t = const MoodThresholds().withHappy(2.26).withSad(6.74);
      expect(t.happyHours, 2.5);
      expect(t.sadHours, 6.5);
    });
  });

  group('MoodThresholds.normalized', () {
    test('keeps valid stored values', () {
      final t = MoodThresholds.normalized(2.0, 4.0);
      expect(t.happyHours, 2.0);
      expect(t.sadHours, 4.0);
    });

    test('repairs out-of-range and inconsistent values', () {
      final low = MoodThresholds.normalized(0.1, 0.2);
      expect(low.happyHours, MoodThresholds.minHappyHours);
      expect(low.sadHours, MoodThresholds.minHappyHours);

      final inverted = MoodThresholds.normalized(3.3, 1.0);
      expect(inverted.happyHours, 3.5);
      expect(inverted.sadHours, 3.5);

      final huge = MoodThresholds.normalized(50, 99);
      expect(huge.happyHours, MoodThresholds.maxHours);
      expect(huge.sadHours, huge.sadSliderMax);
    });
  });
}
