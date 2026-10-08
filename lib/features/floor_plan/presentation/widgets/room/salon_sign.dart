import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The salon's name plate, drawn as a clipper guard: black plastic comb with
/// rounded teeth on top, a brushed-steel plate in a chrome bezel with screws in
/// the lower part carrying the engraved [name], and the metal clip below.
class SalonSign extends StatefulWidget {
  const SalonSign({super.key, required this.name, this.established});

  final String name;

  /// Year engraved under the name ("EST. 2026"); omitted when null.
  final int? established;

  /// Width / height of the sign.
  static const double aspectRatio = 1.75;

  @override
  State<SalonSign> createState() => _SalonSignState();
}

class _SalonSignState extends State<SalonSign>
    with SingleTickerProviderStateMixin {
  /// Drives the light glint that sweeps across the steel plate.
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.established == null
        ? 'BARBERSHOP'
        : 'BARBERSHOP · EST. ${widget.established}';

    return Semantics(
      header: true,
      label: widget.name,
      child: AspectRatio(
        aspectRatio: SalonSign.aspectRatio,
        child: RepaintBoundary(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final plate = _GuardGeometry(Size(w, h)).plate;
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _GuardPainter(_shine)),
                  ),
                  // Engraved salon name, between the rivets.
                  Positioned(
                    left: plate.left + plate.width * 0.15,
                    right: w - plate.right + plate.width * 0.15,
                    top: plate.top + plate.height * 0.08,
                    height: plate.height * 0.6,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _Engraved(
                          _balancedLines(widget.name.trim()),
                          style: const TextStyle(
                            fontFamily: 'Rye',
                            fontSize: 40,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: plate.left + plate.width * 0.15,
                    right: w - plate.right + plate.width * 0.15,
                    top: plate.top + plate.height * 0.68,
                    height: plate.height * 0.2,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _Engraved(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Splits long names over two lines at the space closest to the middle, so
/// they stay large enough to read.
String _balancedLines(String name) {
  const maxSingleLine = 16;
  if (name.length <= maxSingleLine || !name.contains(' ')) return name;
  var best = -1;
  for (var i = name.indexOf(' '); i != -1; i = name.indexOf(' ', i + 1)) {
    if (best == -1 ||
        (i - name.length / 2).abs() < (best - name.length / 2).abs()) {
      best = i;
    }
  }
  return '${name.substring(0, best)}\n${name.substring(best + 1)}';
}

/// Text that looks engraved into metal: dark letters with a light edge
/// underneath.
class _Engraved extends StatelessWidget {
  const _Engraved(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: style.copyWith(
        color: const Color(0xFF23272B),
        shadows: const [
          Shadow(color: Color(0xCCFFFFFF), offset: Offset(0, 1.2)),
          Shadow(color: Color(0x40000000), offset: Offset(0, -0.6)),
        ],
      ),
    );
  }
}

/// Shared layout of the guard's parts, relative to the sign size.
class _GuardGeometry {
  _GuardGeometry(this.size);

  final Size size;

  double get w => size.width;
  double get h => size.height;

  Rect get body => Rect.fromLTRB(w * 0.03, h * 0.27, w * 0.97, h * 0.86);
  double get teethTop => h * 0.03;
  Rect get plate => Rect.fromLTRB(w * 0.1, h * 0.42, w * 0.9, h * 0.79);
  Rect get clip => Rect.fromLTRB(w * 0.4, h * 0.8, w * 0.6, h * 0.985);
}

/// Paints the guard like a molded plastic part: tapered round teeth with
/// visible thickness, a satin black body lit from above, a steel plate set
/// in a chrome bezel with slotted screws, and the spring clip below.
class _GuardPainter extends CustomPainter {
  _GuardPainter(this.shine) : super(repaint: shine);

  final Animation<double> shine;

  static const _teeth = 17;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _GuardGeometry(size);

    _paintClip(canvas, g);
    _paintTeeth(canvas, g);
    _paintBody(canvas, g);
    _paintPlate(canvas, g);
  }

  // ---------------------------------------------------------------------------
  // Teeth
  // ---------------------------------------------------------------------------

  Path _tooth(Rect body, double top, int i) {
    final pitch = body.width / _teeth;
    final cx = body.left + pitch * (i + 0.5);
    final base = pitch * 0.66;
    final tip = pitch * 0.44;
    final bottom = body.top + body.height * 0.08;
    return Path()
      ..moveTo(cx - base / 2, bottom)
      ..lineTo(cx - tip / 2, top + tip / 2)
      ..arcToPoint(
        Offset(cx + tip / 2, top + tip / 2),
        radius: Radius.circular(tip / 2),
      )
      ..lineTo(cx + base / 2, bottom)
      ..close();
  }

  void _paintTeeth(Canvas canvas, _GuardGeometry g) {
    final body = g.body;
    final pitch = body.width / _teeth;
    // The far side of each tooth, seen slightly from above: gives depth.
    final depth = Offset(pitch * 0.09, -g.h * 0.012);

    final all = Path();
    for (var i = 0; i < _teeth; i++) {
      all.addPath(_tooth(body, g.teethTop + g.h * 0.012, i), Offset.zero);
    }
    canvas.drawShadow(all, Colors.black, 4, false);

    for (var i = 0; i < _teeth; i++) {
      final tooth = _tooth(body, g.teethTop + g.h * 0.012, i);
      final back = tooth.shift(depth);
      final bounds = tooth.getBounds();

      canvas.drawPath(back, Paint()..color = const Color(0xFF050506));

      // Rounded plastic: dark edges, a soft highlight left of center.
      canvas.drawPath(
        tooth,
        Paint()
          ..shader = const LinearGradient(
            colors: [
              Color(0xFF0B0B0D),
              Color(0xFF2E3034),
              Color(0xFF55585E),
              Color(0xFF24262A),
              Color(0xFF09090A),
            ],
            stops: [0.0, 0.25, 0.4, 0.7, 1.0],
          ).createShader(bounds),
      );
      canvas.drawPath(tooth, _stroke(const Color(0xFF020203), 0.8));
    }

    // Teeth darken where they meet the body.
    canvas.save();
    canvas.clipPath(all);
    final nearBody = Rect.fromLTRB(
      body.left,
      body.top - body.height * 0.35,
      body.right,
      body.top + body.height * 0.1,
    );
    canvas.drawRect(
      nearBody,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
        ).createShader(nearBody),
    );
    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // Body
  // ---------------------------------------------------------------------------

  void _paintBody(Canvas canvas, _GuardGeometry g) {
    final rect = g.body;
    final body = RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.circular(rect.height * 0.08),
      topRight: Radius.circular(rect.height * 0.08),
      bottomLeft: Radius.circular(rect.height * 0.32),
      bottomRight: Radius.circular(rect.height * 0.32),
    );
    final shape = Path()..addRRect(body);

    canvas.drawShadow(shape, Colors.black, 10, false);
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF34363A), Color(0xFF1A1B1E), Color(0xFF0C0C0E)],
          stops: [0.0, 0.4, 1.0],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipRRect(body);
    // Curved sides fall into shadow.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.45),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.45),
          ],
          stops: const [0.0, 0.12, 0.88, 1.0],
        ).createShader(rect),
    );
    // Satin sheen across the top.
    final sheen = Rect.fromLTRB(
      rect.left,
      rect.top,
      rect.right,
      rect.top + rect.height * 0.22,
    );
    canvas.drawRect(
      sheen,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(sheen),
    );
    canvas.restore();

    // Molded edge: lit along the top, darker along the bottom.
    canvas
      ..drawRRect(
        body.deflate(1.2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.28),
              Colors.white.withValues(alpha: 0.0),
              Colors.white.withValues(alpha: 0.07),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(rect),
      )
      ..drawRRect(body, _stroke(const Color(0xFF020203), 1.2));
  }

  // ---------------------------------------------------------------------------
  // Plate
  // ---------------------------------------------------------------------------

  void _paintPlate(Canvas canvas, _GuardGeometry g) {
    final rect = g.plate;
    final plate = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.height * 0.14),
    );
    final bezel = plate.inflate(rect.height * 0.045);
    final recess = bezel.inflate(rect.height * 0.035);

    // Pocket molded into the body, darker at the top where light can't reach.
    canvas.drawRRect(
      recess,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF020203), Color(0xFF16171A)],
        ).createShader(recess.outerRect),
    );
    // Chrome bezel.
    canvas.drawRRect(
      bezel,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF4F6F8),
            Color(0xFF8E959D),
            Color(0xFFDDE1E5),
            Color(0xFF5E656D),
          ],
          stops: [0.0, 0.45, 0.6, 1.0],
        ).createShader(bezel.outerRect),
    );
    canvas.drawRRect(bezel, _stroke(const Color(0xFF2C3036), 0.8));

    // Brushed-steel face.
    canvas.drawRRect(plate, Paint()..shader = _steel(rect));
    canvas.save();
    canvas.clipRRect(plate);
    final grain = Paint()
      ..color = Colors.black.withValues(alpha: 0.045)
      ..strokeWidth = 0.6;
    for (var y = rect.top + 1.5; y < rect.bottom; y += 2.2) {
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grain);
    }
    // Moving glint: sweeps across during the first third of each cycle.
    final t = shine.value / 0.35;
    if (t <= 1) {
      final x = rect.left - rect.width * 0.3 + rect.width * 1.6 * t;
      final band = Path()
        ..moveTo(x, rect.top)
        ..lineTo(x + rect.width * 0.12, rect.top)
        ..lineTo(x - rect.width * 0.02, rect.bottom)
        ..lineTo(x - rect.width * 0.14, rect.bottom)
        ..close();
      canvas.drawPath(
        band,
        Paint()..color = Colors.white.withValues(alpha: 0.4),
      );
    }
    // Inner shadow under the bezel's top edge.
    final lip = Rect.fromLTRB(
      rect.left,
      rect.top,
      rect.right,
      rect.top + rect.height * 0.12,
    );
    canvas.drawRect(
      lip,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.22), Colors.transparent],
        ).createShader(lip),
    );
    canvas.restore();
    canvas.drawRRect(plate, _stroke(const Color(0xFF4A5057), 0.8));

    // Slotted screws at both ends.
    final r = rect.height * 0.11;
    for (final (x, angle) in [
      (rect.left + rect.width * 0.075, 0.6),
      (rect.right - rect.width * 0.075, -0.4),
    ]) {
      _paintScrew(canvas, Offset(x, rect.center.dy), r, angle);
    }
  }

  void _paintScrew(Canvas canvas, Offset c, double r, double angle) {
    final head = Rect.fromCircle(center: c, radius: r);
    canvas
      ..drawCircle(
        c.translate(0, r * 0.12),
        r * 1.05,
        Paint()..color = Colors.black.withValues(alpha: 0.25),
      )
      ..drawCircle(
        c,
        r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.45),
            colors: [Color(0xFFFFFFFF), Color(0xFFB4BBC3), Color(0xFF59606A)],
            stops: [0.0, 0.5, 1.0],
          ).createShader(head),
      )
      ..drawCircle(c, r, _stroke(const Color(0xFF353A40), 0.8));

    // The slot, with a light lower edge.
    final dx = r * 0.78 * math.cos(angle);
    final dy = r * 0.78 * math.sin(angle);
    canvas
      ..drawLine(
        c.translate(-dx, -dy),
        c.translate(dx, dy),
        Paint()
          ..color = const Color(0xFF2A2E33)
          ..strokeWidth = r * 0.28
          ..strokeCap = StrokeCap.round,
      )
      ..drawLine(
        c.translate(-dx, -dy + r * 0.14),
        c.translate(dx, dy + r * 0.14),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..strokeWidth = r * 0.08
          ..strokeCap = StrokeCap.round,
      );
  }

  // ---------------------------------------------------------------------------
  // Clip
  // ---------------------------------------------------------------------------

  void _paintClip(Canvas canvas, _GuardGeometry g) {
    final rect = g.clip;
    final tab = RRect.fromRectAndCorners(
      rect,
      bottomLeft: Radius.circular(rect.height * 0.35),
      bottomRight: Radius.circular(rect.height * 0.35),
    );
    canvas
      ..drawRRect(
        tab,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF0B0B0D), Color(0xFF2C2E32), Color(0xFF0B0B0D)],
          ).createShader(rect),
      )
      ..drawRRect(tab, _stroke(const Color(0xFF020203), 1.2));

    // Steel spring bar.
    final bar = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(rect.center.dx, rect.top + rect.height * 0.62),
        width: rect.width * 0.6,
        height: rect.height * 0.3,
      ),
      Radius.circular(rect.height * 0.15),
    );
    canvas
      ..drawRRect(bar, Paint()..shader = _steel(bar.outerRect))
      ..drawRRect(bar, _stroke(const Color(0xFF3B4046), 0.8));
  }

  // ---------------------------------------------------------------------------

  Shader _steel(Rect rect) => const LinearGradient(
    begin: Alignment(-1, -0.4),
    end: Alignment(1, 0.4),
    colors: [
      Color(0xFFD5DADF),
      Color(0xFFF5F6F8),
      Color(0xFFB4BBC3),
      Color(0xFFE9ECEF),
      Color(0xFFA3ABB4),
    ],
    stops: [0.0, 0.3, 0.55, 0.8, 1.0],
  ).createShader(rect);

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round;

  @override
  bool shouldRepaint(_GuardPainter oldDelegate) => false;
}
