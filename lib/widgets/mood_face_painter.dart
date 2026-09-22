import 'dart:math';
import 'package:flutter/material.dart';

enum MoodState { happy, neutral, sad }

extension MoodStateColor on MoodState {
  Color get color {
    switch (this) {
      case MoodState.happy:
        return const Color(0xFF00B050); // contrast green for white card
      case MoodState.neutral:
        return const Color(0xFFD97706); // contrast amber for white card
      case MoodState.sad:
        return const Color(0xFFFF5252); // bright red for black card
    }
  }

  Color get backgroundColor {
    switch (this) {
      case MoodState.happy:
      case MoodState.neutral:
        return const Color(0xFFFFFFFF); // white background
      case MoodState.sad:
        return const Color(0xFF171A1D); // black background in red mode
    }
  }

  bool get hasBorder => this != MoodState.sad;
}

/// In-app preview of the mood face. The native Android widget (see
/// MoodWidgetProvider.kt) redraws the same design directly on a Bitmap/Canvas
/// so it can run without the Flutter engine — keep the two in sync if you
/// tweak the look.
class MoodFacePainter extends CustomPainter {
  MoodFacePainter(this.state);

  final MoodState state;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = state.backgroundColor;
    final bgRRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.135),
    );
    canvas.drawRRect(bgRRect, bgPaint);

    if (state.hasBorder) {
      final borderPaint = Paint()
        ..color = const Color(0xFFE5E7EB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.008;
      canvas.drawRRect(bgRRect, borderPaint);
    }

    final dotPaint = Paint()..color = state.color;
    final dotRadius = size.shortestSide * 0.0115;

    // Dotted rounded-rect "screen" outline
    final outline = Rect.fromLTWH(
      size.width * 0.355,
      size.height * 0.245,
      size.width * 0.29,
      size.height * 0.51,
    );
    _drawDottedRRect(
      canvas,
      dotPaint,
      outline,
      dotRadius,
      cornerRadius: size.width * 0.04,
      spacing: size.shortestSide * 0.033,
    );

    // Speaker grill at the top inside the phone outline
    final speakerY = size.height * 0.285;
    final speakerSpacing = size.shortestSide * 0.024;
    canvas.drawCircle(Offset(size.width * 0.5 - speakerSpacing, speakerY),
        dotRadius * 0.95, dotPaint);
    canvas.drawCircle(
        Offset(size.width * 0.5, speakerY), dotRadius * 0.95, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.5 + speakerSpacing, speakerY),
        dotRadius * 0.95, dotPaint);

    // Eyes
    final eyeY = size.height * 0.465;
    canvas.drawCircle(
        Offset(size.width * 0.455, eyeY), dotRadius * 1.12, dotPaint);
    canvas.drawCircle(
        Offset(size.width * 0.545, eyeY), dotRadius * 1.12, dotPaint);

    // Nose — L shape: 4 dots going down (top dot sits at eye level, between eyes)
    //   •   x=noseX, y=eyeY      ← in between the two eyes
    //   •   x=noseX, y=nose2Y
    //   •   x=noseX, y=nose3Y
    //   • • x=noseX & noseFoot, y=noseBotY  (corner + foot going right)
    final noseX = size.width * 0.488; // between left eye (45.5%) & centre (50%)
    final nose2Y = size.height * 0.493;
    final nose3Y = size.height * 0.521;
    final noseBotY = size.height * 0.549; // corner
    final noseFoot = size.width * 0.516; // one dot to the right
    canvas.drawCircle(Offset(noseX, eyeY), dotRadius, dotPaint); // at eye row
    canvas.drawCircle(Offset(noseX, nose2Y), dotRadius, dotPaint);
    canvas.drawCircle(Offset(noseX, nose3Y), dotRadius, dotPaint);
    canvas.drawCircle(Offset(noseX, noseBotY), dotRadius, dotPaint);
    canvas.drawCircle(Offset(noseFoot, noseBotY), dotRadius, dotPaint);

    // Mouth — happy (green) curves down = smile ∪, sad (red) curves up = frown ∩
    final mouthY = size.height * 0.615;
    final mouthWidth = size.width * 0.145;
    const dots = 5;
    for (var i = 0; i < dots; i++) {
      final t = i / (dots - 1);
      final x = size.width / 2 - mouthWidth / 2 + t * mouthWidth;
      final curve = sin(t * pi) * size.height * 0.025;
      final y = switch (state) {
        MoodState.happy => mouthY + curve, // middle below corners → smile ∪
        MoodState.neutral => mouthY,
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
      oldDelegate.state != state;
}
