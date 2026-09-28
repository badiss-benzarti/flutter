import 'package:flutter/material.dart';

import 'room_art.dart';

/// Paints the room around the stations: perspective ceiling, back wall line and the two side walls.
class RoomShellPainter extends CustomPainter {
  const RoomShellPainter({
    required this.ceilingHeight,
    required this.wallWidth,
  });

  final double ceilingHeight;
  final double wallWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ceil = ceilingHeight;
    final wall = wallWidth;

    canvas.drawRect(Offset.zero & size, Paint()..color = RoomInk.floor);

    // Side walls.
    RoomInk.shape(
      canvas,
      RoomInk.poly([
        Offset.zero,
        Offset(wall, ceil),
        Offset(wall, h),
        Offset(0, h),
      ]),
      Paint()..color = RoomInk.wall,
    );
    RoomInk.shape(
      canvas,
      RoomInk.poly([
        Offset(w, 0),
        Offset(w - wall, ceil),
        Offset(w - wall, h),
        Offset(w, h),
      ]),
      Paint()..color = RoomInk.wall,
    );

    // Ceiling (the salon sign hangs from its center).
    RoomInk.shape(
      canvas,
      RoomInk.poly([
        Offset.zero,
        Offset(w, 0),
        Offset(w - wall, ceil),
        Offset(wall, ceil),
      ]),
      Paint()..color = RoomInk.wall,
    );

    // Technical detailing along the back wall, as in a floor blueprint.
    final y = ceil + 10;
    canvas
      ..drawLine(Offset(wall + 12, y), Offset(wall + 26, y), RoomInk.line)
      ..drawLine(Offset(w * 0.32, y), Offset(w * 0.44, y), RoomInk.thinLine)
      ..drawLine(Offset(w * 0.56, y), Offset(w * 0.68, y), RoomInk.thinLine)
      ..drawLine(
        Offset(w - wall - 26, y),
        Offset(w - wall - 12, y),
        RoomInk.line,
      );
  }

  @override
  bool shouldRepaint(RoomShellPainter oldDelegate) =>
      oldDelegate.ceilingHeight != ceilingHeight ||
      oldDelegate.wallWidth != wallWidth;
}
