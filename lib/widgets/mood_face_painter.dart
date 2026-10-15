import 'dart:math';

import 'package:flutter/material.dart';

import '../models/mood_thresholds.dart';

/// Face proportions, as fractions of the (square) canvas side.
///
/// The native widget (MoodWidgetProvider.kt → `FaceGeometry`) uses the same
/// numbers — keep the two in sync if you tweak the look.
abstract final class FaceGeometry {
  static const panelCornerRadius = 0.135;
  static const borderWidth = 0.008;
  static const dotRadius = 0.0115;

  // Dotted rounded-rect "screen" outline
  static const outlineLeft = 0.355;
  static const outlineTop = 0.245;
  static const outlineWidth = 0.29;
  static const outlineHeight = 0.51;
  static const outlineCornerRadius = 0.04;
  static const outlineSpacing = 0.033;

  // Speaker grill
  static const speakerY = 0.285;
  static const speakerSpacing = 0.024;
  static const speakerDotScale = 0.95;

  // Eyes
  static const eyeY = 0.465;
  static const eyeLeftX = 0.455;
  static const eyeRightX = 0.545;
  static const eyeDotScale = 1.12;

  // Nose — L shape: top dot at eye level, three more going down, one foot
  static const noseX = 0.488;
  static const nose2Y = 0.493;
  static const nose3Y = 0.521;
  static const noseBottomY = 0.549;
  static const noseFootX = 0.516;

  // Mouth — 5-dot arc
  static const mouthY = 0.615;
  static const mouthWidth = 0.145;
  static const mouthDots = 5;
  static const mouthCurve = 0.025;
}

/// Colours that depend on the device theme. The panel follows light/dark
/// mode; only the dots carry the mood colour.
extension MoodStatePalette on MoodState {
  Color dotColor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      MoodState.happy =>
        dark ? const Color(0xFF00E676) : const Color(0xFF00B050),
      MoodState.neutral =>
        dark ? const Color(0xFFFFB300) : const Color(0xFFD97706),
      MoodState.sad => dark ? const Color(0xFFFF5252) : const Color(0xFFE53935),
      MoodState.noAccess =>
        dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
    };
  }

  String get label => switch (this) {
        MoodState.happy => 'happy',
        MoodState.neutral => 'neutral',
        MoodState.sad => 'sad',
        MoodState.noAccess => 'usage access needed',
      };
}

Color moodPanelColor(Brightness brightness) => brightness == Brightness.dark
    ? const Color(0xFF171A1D)
    : const Color(0xFFFFFFFF);

Color moodBorderColor(Brightness brightness) => brightness == Brightness.dark
    ? const Color(0xFF2A2E33)
    : const Color(0xFFE5E7EB);

/// In-app preview of the mood face. The native Android widget (see
/// MoodWidgetProvider.kt) draws the same design on a Bitmap/Canvas so it can
/// run without the Flutter engine.
class MoodFacePainter extends CustomPainter {
  MoodFacePainter(this.state, this.brightness);

  final MoodState state;

  /// Device theme: decides the panel colour (light card / dark card) and the
  /// shade of the mood colour used for the dots.
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final bgRRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * FaceGeometry.panelCornerRadius),
    );
    canvas.drawRRect(bgRRect, Paint()..color = moodPanelColor(brightness));

    // Inset by half the stroke so the whole border is visible, matching the
    // native widget's background.
    final borderWidth = size.width * FaceGeometry.borderWidth;
    canvas.drawRRect(
      bgRRect.deflate(borderWidth / 2),
      Paint()
        ..color = moodBorderColor(brightness)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );

    final dotPaint = Paint()..color = state.dotColor(brightness);
    final dotRadius = side * FaceGeometry.dotRadius;

    _drawDottedRRect(
      canvas,
      dotPaint,
      Rect.fromLTWH(
        size.width * FaceGeometry.outlineLeft,
        size.height * FaceGeometry.outlineTop,
        size.width * FaceGeometry.outlineWidth,
        size.height * FaceGeometry.outlineHeight,
      ),
      dotRadius,
      cornerRadius: size.width * FaceGeometry.outlineCornerRadius,
      spacing: side * FaceGeometry.outlineSpacing,
    );

    // Speaker grill at the top inside the phone outline
    final speakerY = size.height * FaceGeometry.speakerY;
    final speakerSpacing = side * FaceGeometry.speakerSpacing;
    final speakerRadius = dotRadius * FaceGeometry.speakerDotScale;
    for (final dx in [-speakerSpacing, 0.0, speakerSpacing]) {
      canvas.drawCircle(
          Offset(size.width * 0.5 + dx, speakerY), speakerRadius, dotPaint);
    }

    // Eyes
    final eyeY = size.height * FaceGeometry.eyeY;
    final eyeRadius = dotRadius * FaceGeometry.eyeDotScale;
    canvas.drawCircle(
        Offset(size.width * FaceGeometry.eyeLeftX, eyeY), eyeRadius, dotPaint);
    canvas.drawCircle(
        Offset(size.width * FaceGeometry.eyeRightX, eyeY), eyeRadius, dotPaint);

    // Nose — L shape: 4 dots going down (top dot at eye level, between the
    // eyes) plus one foot to the right.
    final noseX = size.width * FaceGeometry.noseX;
    final noseBottomY = size.height * FaceGeometry.noseBottomY;
    for (final y in [
      eyeY,
      size.height * FaceGeometry.nose2Y,
      size.height * FaceGeometry.nose3Y,
      noseBottomY,
    ]) {
      canvas.drawCircle(Offset(noseX, y), dotRadius, dotPaint);
    }
    canvas.drawCircle(
      Offset(size.width * FaceGeometry.noseFootX, noseBottomY),
      dotRadius,
      dotPaint,
    );

    // Mouth — happy curves down = smile ∪, sad curves up = frown ∩
    final mouthY = size.height * FaceGeometry.mouthY;
    final mouthWidth = size.width * FaceGeometry.mouthWidth;
    const dots = FaceGeometry.mouthDots;
    for (var i = 0; i < dots; i++) {
      final t = i / (dots - 1);
      final x = size.width / 2 - mouthWidth / 2 + t * mouthWidth;
      final curve = sin(t * pi) * size.height * FaceGeometry.mouthCurve;
      final y = switch (state) {
        MoodState.happy => mouthY + curve, // middle below corners → smile ∪
        MoodState.neutral || MoodState.noAccess => mouthY,
        MoodState.sad => mouthY - curve, // middle above corners → frown ∩
      };
      canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
    }
  }

  void _drawDottedRRect(
    Canvas canvas,
    Paint paint,
    Rect rect,
    double dotRadius, {
    required double cornerRadius,
    required double spacing,
  }) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, dotRadius, paint);
        }
        distance += spacing;
      }
    }
  }

  @override
  bool shouldRepaint(covariant MoodFacePainter oldDelegate) =>
      oldDelegate.state != state || oldDelegate.brightness != brightness;
}
