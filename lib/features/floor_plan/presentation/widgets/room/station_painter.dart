import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/station.dart';
import 'room_art.dart';

/// Paints one barber station against a side wall: mirror, tool cabinet,
/// chair and the characters for the current [status].
///
/// Drawn in a 190x124 canonical box with the wall on the left; right-wall
/// stations are [mirrored]. [animation] drives the barber's scissors while a
/// client is being served.
class StationPainter extends CustomPainter {
  StationPainter({
    required this.status,
    required this.mirrored,
    required this.animation,
  }) : super(repaint: animation);

  final ChairStatus status;
  final bool mirrored;
  final Animation<double> animation;

  static const Size canonical = Size(190, 124);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / canonical.width,
      size.height / canonical.height,
    );
    canvas.save();
    if (mirrored) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    canvas
      ..translate(0, size.height - canonical.height * scale)
      ..scale(scale);

    _paintMirror(canvas);
    _paintCabinet(canvas);

    final hasBarber =
        status == ChairStatus.available || status == ChairStatus.occupied;
    final hasClient = status == ChairStatus.occupied;

    _paintChairBack(canvas);
    if (hasClient) _paintClient(canvas);
    _paintArmrest(canvas);
    if (hasBarber) _paintBarber(canvas, working: hasClient);

    canvas.restore();
  }

  void _paintMirror(Canvas c) {
    final frame = RoomInk.poly(const [
      Offset(4, 12),
      Offset(15, 20),
      Offset(15, 100),
      Offset(4, 108),
    ]);
    RoomInk.shape(c, frame, Paint()..color = const Color(0xFFFAFAFA));
    c
      ..drawLine(const Offset(8, 28), const Offset(8, 48), RoomInk.thinLine)
      ..drawLine(const Offset(11, 34), const Offset(11, 44), RoomInk.thinLine);
  }

  void _paintCabinet(Canvas c) {
    RoomInk.shape(
      c,
      RoomInk.poly(const [
        Offset(44, 22),
        Offset(49, 27),
        Offset(49, 101),
        Offset(44, 106),
      ]),
      RoomInk.shade,
    );
    RoomInk.rrect(
      c,
      RRect.fromLTRBR(22, 22, 44, 106, const Radius.circular(2)),
    );
    c.drawLine(const Offset(22, 64), const Offset(44, 64), RoomInk.line);

    // Top shelf: clipper and comb.
    c.drawRRect(
      RRect.fromLTRBR(26, 29, 40, 35, const Radius.circular(2)),
      RoomInk.black,
    );
    c.drawRect(const Rect.fromLTRB(26, 40, 40, 43), RoomInk.line);
    for (var i = 0; i < 6; i++) {
      final x = 27.0 + i * 2.5;
      c.drawLine(Offset(x, 43), Offset(x, 47), RoomInk.line);
    }
    c.drawRRect(
      RRect.fromLTRBR(26, 52, 34, 56, const Radius.circular(1.5)),
      RoomInk.black,
    );

    // Bottom shelf: spray bottle and brush.
    c.drawRect(const Rect.fromLTRB(28.5, 76, 32.5, 80), RoomInk.black);
    RoomInk.rrect(c, RRect.fromLTRBR(27, 80, 34, 97, const Radius.circular(2)));
    c.drawRRect(
      RRect.fromLTRBR(36, 86, 41, 97, const Radius.circular(2)),
      RoomInk.black,
    );
  }

  void _paintChairBack(Canvas c) {
    // Floor shadow, round base and pole.
    c.drawOval(
      Rect.fromCenter(center: const Offset(94, 110), width: 52, height: 12),
      RoomInk.shadow,
    );
    final base = Rect.fromCenter(
      center: const Offset(96, 106),
      width: 40,
      height: 12,
    );
    c
      ..drawOval(base, RoomInk.white)
      ..drawOval(base, RoomInk.line)
      ..drawOval(
        Rect.fromCenter(center: const Offset(96, 106), width: 22, height: 6),
        RoomInk.black,
      )
      ..drawRect(const Rect.fromLTRB(93, 86, 99, 104), RoomInk.black);

    // Slatted footrest toward the mirror.
    const a = Offset(54, 82);
    const b = Offset(70, 78);
    const cc = Offset(74, 94);
    const d = Offset(58, 98);
    RoomInk.shape(c, RoomInk.poly(const [a, b, cc, d]));
    for (final t in const [0.33, 0.66]) {
      c.drawLine(Offset.lerp(a, d, t)!, Offset.lerp(b, cc, t)!, RoomInk.line);
    }

    // Backrest, headrest and seat.
    c
      ..drawRRect(
        RRect.fromLTRBR(100, 30, 116, 82, const Radius.circular(6)),
        RoomInk.black,
      )
      ..drawLine(const Offset(106, 26), const Offset(106, 31), RoomInk.line)
      ..drawRRect(
        RRect.fromLTRBR(97, 16, 113, 27, const Radius.circular(4)),
        RoomInk.black,
      )
      ..drawRRect(
        RRect.fromLTRBR(68, 72, 110, 88, const Radius.circular(5)),
        RoomInk.black,
      );
  }

  void _paintArmrest(Canvas c) {
    RoomInk.rrect(
      c,
      RRect.fromLTRBR(70, 62, 100, 69, const Radius.circular(3)),
    );
    for (final x in const [77.0, 84.0, 91.0]) {
      c.drawLine(Offset(x, 63.5), Offset(x, 67.5), RoomInk.line);
    }
  }

  void _paintClient(Canvas c) {
    // Legs stretched onto the footrest.
    RoomInk.limb(c, const Offset(86, 74), const Offset(68, 82), 8);
    RoomInk.limb(c, const Offset(68, 82), const Offset(63, 90), 7);
    // Torso under a barber cape.
    RoomInk.shape(
      c,
      Path()
        ..moveTo(82, 44)
        ..quadraticBezierTo(92, 38, 102, 44)
        ..lineTo(104, 76)
        ..lineTo(78, 76)
        ..close(),
    );
    RoomInk.head(c, const Offset(90, 30), 10.5);
  }

  void _paintBarber(Canvas c, {required bool working}) {
    const x = 146.0;
    c.drawOval(
      Rect.fromCenter(center: const Offset(x, 116), width: 36, height: 8),
      RoomInk.shadow,
    );

    // Legs and the arm on the far side.
    RoomInk.limb(c, const Offset(x - 5, 92), const Offset(x - 6, 112), 7);
    RoomInk.limb(c, const Offset(x + 5, 92), const Offset(x + 6, 112), 7);
    RoomInk.limb(
      c,
      const Offset(x + 10, 64),
      working ? const Offset(x + 2, 80) : const Offset(x + 15, 86),
      6,
    );

    // Body and head.
    RoomInk.rrect(
      c,
      RRect.fromLTRBR(x - 13, 54, x + 13, 98, const Radius.circular(12)),
    );
    RoomInk.head(c, const Offset(x, 38), 13);

    // Near arm: resting, or cutting at the client's head.
    if (!working) {
      RoomInk.limb(c, const Offset(x - 10, 64), const Offset(x - 15, 86), 6);
      return;
    }
    final phase = animation.value * 2 * math.pi;
    final hand = Offset(98 + math.sin(phase) * 2.5, 18 + math.cos(phase));
    RoomInk.limb(c, const Offset(x - 10, 62), hand, 6);
    _paintScissors(c, hand, math.sin(phase * 2).abs());
  }

  void _paintScissors(Canvas c, Offset at, double open) {
    final spread = 0.18 + open * 0.35;
    for (final sign in const [-1.0, 1.0]) {
      final angle = math.pi + sign * spread;
      c.drawLine(
        at,
        at + Offset(math.cos(angle), math.sin(angle)) * 9,
        RoomInk.line,
      );
    }
  }

  @override
  bool shouldRepaint(StationPainter oldDelegate) =>
      oldDelegate.status != status || oldDelegate.mirrored != mirrored;
}
