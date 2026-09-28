import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A vintage barbershop marquee sign: red banner in a gold frame lined with
/// twinkling bulbs, barber poles on both sides, a scissors badge on top and
/// a ribbon underneath. Shows the salon [name].
class SalonSign extends StatefulWidget {
  const SalonSign({super.key, required this.name, this.established});

  final String name;

  /// Year shown on the ribbon ("EST. 2026"); omitted when null.
  final int? established;

  /// Width / height of the sign.
  static const double aspectRatio = 2.35;

  @override
  State<SalonSign> createState() => _SalonSignState();
}

class _SalonSignState extends State<SalonSign>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lights = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _lights.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ribbon = widget.established == null
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
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _SignPainter(_lights)),
                  ),
                  // Salon name.
                  Positioned(
                    left: w * 0.17,
                    right: w * 0.17,
                    top: h * 0.27,
                    height: h * 0.40,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _GoldTitle(_balancedLines(widget.name.trim())),
                      ),
                    ),
                  ),
                  // Ribbon text.
                  Positioned(
                    left: w * 0.25,
                    right: w * 0.25,
                    top: h * 0.735,
                    height: h * 0.17,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          ribbon,
                          maxLines: 1,
                          style: const TextStyle(
                            fontFamily: 'Rye',
                            fontSize: 14,
                            letterSpacing: 1.2,
                            color: Color(0xFF7A1422),
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
/// they stay large enough to read on the sign.
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

/// Gold lettering with a dark outline and drop shadow.
class _GoldTitle extends StatelessWidget {
  const _GoldTitle(this.text);

  final String text;

  static const _gold = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF3B0), Color(0xFFFFD34D), Color(0xFFE09A1B)],
    stops: [0.0, 0.45, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(fontFamily: 'Rye', fontSize: 40, height: 1.1);
    return Stack(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF3A0710),
            shadows: const [
              Shadow(
                color: Color(0x80000000),
                offset: Offset(0, 3),
                blurRadius: 3,
              ),
            ],
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: _gold.createShader,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: base.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _SignPainter extends CustomPainter {
  _SignPainter(this.lights) : super(repaint: lights);

  final Animation<double> lights;

  static const _darkRed = Color(0xFF5E0B17);
  static const _red = Color(0xFFB3202F);
  static const _outline = Color(0xFF2B0509);
  static const _cream = Color(0xFFFFF4DC);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _paintPole(canvas, Rect.fromLTWH(0, h * 0.22, w * 0.07, h * 0.56));
    _paintPole(canvas, Rect.fromLTWH(w * 0.93, h * 0.22, w * 0.07, h * 0.56));

    // Banner: gold frame, red field, cream pinstripe.
    final frame = _bannerPath(
      Rect.fromLTRB(w * 0.075, h * 0.1, w * 0.925, h * 0.86),
    );
    final field = _bannerPath(
      Rect.fromLTRB(w * 0.11, h * 0.18, w * 0.89, h * 0.8),
    );
    final bulbTrack = _bannerPath(
      Rect.fromLTRB(w * 0.093, h * 0.14, w * 0.907, h * 0.83),
    );

    canvas.drawShadow(frame, Colors.black, 6, false);
    canvas.drawPath(
      frame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE08A), Color(0xFFD9A233), Color(0xFF9C6A12)],
        ).createShader(frame.getBounds()),
    );
    canvas.drawPath(frame, _stroke(_outline, 2));
    canvas.drawPath(
      field,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.9,
          colors: [_red, _darkRed],
        ).createShader(field.getBounds()),
    );
    canvas.drawPath(field, _stroke(_outline, 2));
    canvas.drawPath(
      _bannerPath(Rect.fromLTRB(w * 0.125, h * 0.215, w * 0.875, h * 0.77)),
      _stroke(_cream.withValues(alpha: 0.55), 1),
    );

    _paintBulbs(canvas, bulbTrack, math.max(4.0, h * 0.032));
    _paintRibbon(canvas, size);
    _paintBadge(canvas, Offset(w * 0.5, h * 0.105), h * 0.1);
  }

  /// Banner outline: arched top, softly flared sides, curved bottom.
  Path _bannerPath(Rect r) {
    return Path()
      ..moveTo(r.left, r.top + r.height * 0.28)
      ..quadraticBezierTo(
        r.center.dx,
        r.top - r.height * 0.22,
        r.right,
        r.top + r.height * 0.28,
      )
      ..quadraticBezierTo(
        r.right + r.width * 0.025,
        r.center.dy,
        r.right,
        r.bottom - r.height * 0.12,
      )
      ..quadraticBezierTo(
        r.center.dx,
        r.bottom + r.height * 0.1,
        r.left,
        r.bottom - r.height * 0.12,
      )
      ..quadraticBezierTo(
        r.left - r.width * 0.025,
        r.center.dy,
        r.left,
        r.top + r.height * 0.28,
      )
      ..close();
  }

  void _paintBulbs(Canvas canvas, Path track, double radius) {
    final phase = (lights.value * 6).floor();
    for (final metric in track.computeMetrics()) {
      final count = (metric.length / (radius * 4.2)).floor();
      for (var i = 0; i < count; i++) {
        final pos = metric
            .getTangentForOffset(metric.length * i / count)!
            .position;
        final lit = (i + phase) % 3 != 0;
        if (lit) {
          canvas.drawCircle(
            pos,
            radius * 2.2,
            Paint()
              ..shader =
                  RadialGradient(
                    colors: [
                      const Color(0xFFFFF1A8).withValues(alpha: 0.9),
                      const Color(0x00FFD34D),
                    ],
                  ).createShader(
                    Rect.fromCircle(center: pos, radius: radius * 2.2),
                  ),
          );
        }
        canvas
          ..drawCircle(
            pos,
            radius,
            Paint()
              ..color = lit ? const Color(0xFFFFFBE6) : const Color(0xFFB88A2A),
          )
          ..drawCircle(pos, radius, _stroke(_outline, 1));
      }
    }
  }

  void _paintRibbon(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final top = h * 0.72;
    final bottom = h * 0.92;
    final tailTop = top + (bottom - top) * 0.25;

    // Folded tails behind the ribbon ends.
    for (final dir in const [-1.0, 1.0]) {
      final inner = w * 0.5 + dir * w * 0.24;
      final outer = w * 0.5 + dir * w * 0.32;
      final tail = Path()
        ..moveTo(inner, tailTop)
        ..lineTo(outer, tailTop)
        ..lineTo(outer - dir * w * 0.025, (tailTop + bottom + 6) / 2)
        ..lineTo(outer, bottom + 6)
        ..lineTo(inner, bottom + 6)
        ..close();
      canvas
        ..drawPath(tail, Paint()..color = const Color(0xFFE2CFA6))
        ..drawPath(tail, _stroke(_outline, 1.5));
    }

    final ribbon = Path()
      ..moveTo(w * 0.24, top)
      ..quadraticBezierTo(w * 0.5, top + h * 0.05, w * 0.76, top)
      ..lineTo(w * 0.76, bottom)
      ..quadraticBezierTo(w * 0.5, bottom + h * 0.05, w * 0.24, bottom)
      ..close();
    canvas
      ..drawPath(ribbon, Paint()..color = _cream)
      ..drawPath(ribbon, _stroke(_outline, 2));
  }

  void _paintBadge(Canvas canvas, Offset center, double radius) {
    canvas
      ..drawCircle(
        center,
        radius * 1.25,
        Paint()
          ..shader =
              const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFE08A), Color(0xFF9C6A12)],
              ).createShader(
                Rect.fromCircle(center: center, radius: radius * 1.25),
              ),
      )
      ..drawCircle(center, radius * 1.25, _stroke(_outline, 1.5))
      ..drawCircle(center, radius, Paint()..color = _darkRed)
      ..drawCircle(center, radius, _stroke(_cream, 1));

    final icon = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.content_cut.codePoint),
        style: TextStyle(
          fontFamily: Icons.content_cut.fontFamily,
          package: Icons.content_cut.fontPackage,
          fontSize: radius * 1.35,
          color: _cream,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    icon.paint(canvas, center - Offset(icon.width / 2, icon.height / 2));
  }

  /// Classic red, white and blue barber pole with scrolling stripes.
  void _paintPole(Canvas canvas, Rect r) {
    final capHeight = r.height * 0.12;
    final tube = Rect.fromLTRB(
      r.left + r.width * 0.12,
      r.top + capHeight,
      r.right - r.width * 0.12,
      r.bottom - capHeight,
    );
    final tubeShape = RRect.fromRectAndRadius(
      tube,
      Radius.circular(tube.width / 2),
    );

    canvas.save();
    canvas.clipRRect(tubeShape);
    canvas.drawRect(tube, Paint()..color = Colors.white);
    final stripe = tube.width * 0.55;
    final shift = lights.value * stripe * 4;
    var i = 0;
    for (
      var y = tube.top - tube.width * 2 - stripe * 4 + shift;
      y < tube.bottom;
      y += stripe
    ) {
      final color = i.isEven ? _red : const Color(0xFF1F4E9C);
      i++;
      if (i % 3 == 0) continue; // White gap every third band.
      final band = Path()
        ..moveTo(tube.left, y)
        ..lineTo(tube.right, y + tube.width)
        ..lineTo(tube.right, y + tube.width + stripe * 0.6)
        ..lineTo(tube.left, y + stripe * 0.6)
        ..close();
      canvas.drawPath(band, Paint()..color = color);
    }
    // Glass highlight.
    canvas.drawRect(
      Rect.fromLTWH(
        tube.left + tube.width * 0.18,
        tube.top,
        tube.width * 0.16,
        tube.height,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
    canvas.restore();
    canvas.drawRRect(tubeShape, _stroke(_outline, 1.5));

    // Gold caps with round finials.
    final gold = Paint()..color = const Color(0xFFD9A233);
    for (final top in [true, false]) {
      final cap = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          r.left,
          top ? r.top + capHeight * 0.35 : r.bottom - capHeight,
          r.width,
          capHeight * 0.65,
        ),
        Radius.circular(capHeight * 0.2),
      );
      final knob = Offset(
        r.center.dx,
        top ? r.top + capHeight * 0.25 : r.bottom + capHeight * 0.1,
      );
      canvas
        ..drawRRect(cap, gold)
        ..drawRRect(cap, _stroke(_outline, 1.5))
        ..drawCircle(knob, r.width * 0.22, gold)
        ..drawCircle(knob, r.width * 0.22, _stroke(_outline, 1.5));
    }
  }

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round;

  @override
  bool shouldRepaint(_SignPainter oldDelegate) => false;
}
