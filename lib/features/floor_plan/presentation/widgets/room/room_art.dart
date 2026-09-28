import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared drawing primitives for the illustrated barbershop room: black
/// outlines on white shapes, like a line-art sketch.
class RoomInk {
  RoomInk._();

  static const Color ink = Color(0xFF111111);
  static const Color wall = Color(0xFFF4F4F5);
  static const Color wallShade = Color(0xFFE4E4E7);
  static const Color floor = Colors.white;

  static final Paint line = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  static final Paint thinLine = Paint()
    ..color = const Color(0xFF9CA3AF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.round;

  static final Paint white = Paint()..color = Colors.white;
  static final Paint black = Paint()..color = ink;
  static final Paint shade = Paint()..color = wallShade;
  static final Paint shadow = Paint()..color = const Color(0x1A000000);

  static void shape(Canvas c, Path p, [Paint? fill]) {
    c
      ..drawPath(p, fill ?? white)
      ..drawPath(p, line);
  }

  static void rrect(Canvas c, RRect r, [Paint? fill]) {
    c
      ..drawRRect(r, fill ?? white)
      ..drawRRect(r, line);
  }

  static void circle(Canvas c, Offset center, double radius, [Paint? fill]) {
    c
      ..drawCircle(center, radius, fill ?? white)
      ..drawCircle(center, radius, line);
  }

  /// An outlined limb: a white stroke with a black border.
  static void limb(Canvas c, Offset a, Offset b, double width) {
    c
      ..drawLine(
        a,
        b,
        Paint()
          ..color = ink
          ..strokeWidth = width + 3.6
          ..strokeCap = StrokeCap.round,
      )
      ..drawLine(
        a,
        b,
        Paint()
          ..color = Colors.white
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
  }

  static Path poly(List<Offset> points) => Path()..addPolygon(points, true);

  /// A simple character head: outlined circle, eyes and a smile, looking
  /// toward negative x.
  static void head(Canvas c, Offset center, double radius) {
    circle(c, center, radius);
    final eyeY = center.dy - radius * 0.08;
    final eyeR = radius * 0.11;
    c
      ..drawCircle(Offset(center.dx - radius * 0.52, eyeY), eyeR, black)
      ..drawCircle(Offset(center.dx - radius * 0.08, eyeY), eyeR, black)
      ..drawArc(
        Rect.fromCenter(
          center: Offset(center.dx - radius * 0.3, center.dy + radius * 0.3),
          width: radius * 0.55,
          height: radius * 0.35,
        ),
        0.15 * math.pi,
        0.7 * math.pi,
        false,
        line,
      );
  }
}
