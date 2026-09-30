import 'package:flutter/material.dart';

/// The salon's name plate, drawn as a clipper guard: glossy black comb with
/// teeth on top, a brushed-steel plate with gold trim and chrome rivets in
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

class _GuardPainter extends CustomPainter {
  _GuardPainter(this.shine) : super(repaint: shine);

  final Animation<double> shine;

  static const _outline = Color(0xFF050505);
  static const _gold = Color(0xFFC9A227);

  @override
  void paint(Canvas canvas, Size size) {
    final g = _GuardGeometry(size);

    _paintClip(canvas, g);
    _paintBody(canvas, g);
    _paintPlate(canvas, g);
  }

  void _paintClip(Canvas canvas, _GuardGeometry g) {
    final clip = RRect.fromRectAndCorners(
      g.clip,
      bottomLeft: Radius.circular(g.clip.height * 0.35),
      bottomRight: Radius.circular(g.clip.height * 0.35),
    );
    canvas
      ..drawRRect(clip, Paint()..shader = _steel(g.clip))
      ..drawRRect(clip, _stroke(_outline, 1.5))
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(g.clip.center.dx, g.clip.top + g.clip.height * 0.6),
            width: g.clip.width * 0.55,
            height: g.clip.height * 0.28,
          ),
          Radius.circular(g.clip.height * 0.14),
        ),
        Paint()..color = const Color(0xFF3B4046),
      );
  }

  void _paintBody(Canvas canvas, _GuardGeometry g) {
    final body = g.body;
    const teeth = 17;
    final pitch = body.width / teeth;
    final toothWidth = pitch * 0.6;

    final shape = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          body,
          topLeft: Radius.circular(body.height * 0.06),
          topRight: Radius.circular(body.height * 0.06),
          bottomLeft: Radius.circular(body.height * 0.3),
          bottomRight: Radius.circular(body.height * 0.3),
        ),
      );
    for (var i = 0; i < teeth; i++) {
      final left = body.left + pitch * i + (pitch - toothWidth) / 2;
      shape.addRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(left, g.teethTop, left + toothWidth, body.top + 4),
          topLeft: Radius.circular(toothWidth * 0.45),
          topRight: Radius.circular(toothWidth * 0.45),
        ),
      );
    }

    canvas.drawShadow(shape, Colors.black, 8, false);
    canvas.drawPath(
      shape,
      Paint()
        ..shader =
            const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A3A3D), Color(0xFF151517), Color(0xFF050506)],
              stops: [0.0, 0.45, 1.0],
            ).createShader(
              Rect.fromLTRB(body.left, g.teethTop, body.right, body.bottom),
            ),
    );

    // Gloss on the teeth and along the top of the body.
    canvas.save();
    canvas.clipPath(shape);
    canvas.drawRect(
      Rect.fromLTRB(
        body.left,
        g.teethTop,
        body.right,
        body.top + body.height * 0.1,
      ),
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.02),
              ],
            ).createShader(
              Rect.fromLTRB(body.left, g.teethTop, body.right, body.top),
            ),
    );
    canvas.restore();

    canvas.drawPath(shape, _stroke(_outline, 1.5));
    // Gold pinstripe where the teeth meet the body.
    canvas.drawLine(
      Offset(body.left + body.width * 0.02, body.top + body.height * 0.06),
      Offset(body.right - body.width * 0.02, body.top + body.height * 0.06),
      _stroke(_gold.withValues(alpha: 0.9), 1.4),
    );
  }

  void _paintPlate(Canvas canvas, _GuardGeometry g) {
    final rect = g.plate;
    final plate = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.height * 0.16),
    );

    // Gold trim, then the brushed-steel face.
    canvas.drawRRect(
      plate.inflate(rect.height * 0.045),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE08A), Color(0xFFC9A227), Color(0xFF8A6512)],
        ).createShader(rect),
    );
    canvas.drawRRect(plate, Paint()..shader = _steel(rect));

    canvas.save();
    canvas.clipRRect(plate);
    // Brushed grain.
    final grain = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
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
        Paint()..color = Colors.white.withValues(alpha: 0.45),
      );
    }
    canvas.restore();

    canvas
      ..drawRRect(plate, _stroke(const Color(0xFF4A5057), 1.2))
      ..drawRRect(
        plate.deflate(2),
        _stroke(Colors.white.withValues(alpha: 0.7), 0.8),
      );

    // Chrome rivets at both ends of the plate.
    final r = rect.height * 0.12;
    for (final x in [
      rect.left + rect.width * 0.075,
      rect.right - rect.width * 0.075,
    ]) {
      final c = Offset(x, rect.center.dy);
      canvas
        ..drawCircle(
          c,
          r,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-0.4, -0.5),
              colors: [Colors.white, Color(0xFFB9C0C8), Color(0xFF5F666E)],
              stops: [0.0, 0.55, 1.0],
            ).createShader(Rect.fromCircle(center: c, radius: r)),
        )
        ..drawCircle(c, r, _stroke(const Color(0xFF3B4046), 1));
    }
  }

  Shader _steel(Rect rect) => const LinearGradient(
    begin: Alignment(-1, -0.4),
    end: Alignment(1, 0.4),
    colors: [
      Color(0xFFD9DEE3),
      Color(0xFFF7F8FA),
      Color(0xFFB8BFC7),
      Color(0xFFEEF1F4),
      Color(0xFFA9B1BA),
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
