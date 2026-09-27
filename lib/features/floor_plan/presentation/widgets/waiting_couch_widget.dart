import 'package:flutter/material.dart';

class WaitingCouchWidget extends StatelessWidget {
  const WaitingCouchWidget({
    super.key,
    required this.waitingCount,
    required this.onReserveTap,
    required this.onQueueViewTap,
  });

  final int waitingCount;
  final VoidCallback onReserveTap;
  final VoidCallback onQueueViewTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 290),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Couch visual area
          InkWell(
            onTap: onQueueViewTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Column(
                children: [
                  CustomPaint(
                    size: const Size(120, 46),
                    painter: _SofaPainter(),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: waitingCount > 0
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        waitingCount == 1
                            ? '1 client waiting'
                            : '$waitingCount clients waiting',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom Reserve Waiting Spot button capsule
          InkWell(
            onTap: onReserveTap,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(18),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'RESERVE WAITING SPOT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.add_circle_outline, color: Colors.white, size: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SofaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Sofa outer outline
    final outerRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: 110,
        height: 40,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(outerRRect, fillPaint);
    canvas.drawRRect(outerRRect, strokePaint);

    // Left armrest
    final leftArm = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width / 2 - 55, size.height / 2 - 20, 14, 40),
      const Radius.circular(4),
    );
    canvas.drawRRect(leftArm, fillPaint);
    canvas.drawRRect(leftArm, strokePaint);

    // Right armrest
    final rightArm = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width / 2 + 41, size.height / 2 - 20, 14, 40),
      const Radius.circular(4),
    );
    canvas.drawRRect(rightArm, fillPaint);
    canvas.drawRRect(rightArm, strokePaint);

    // 3 cushions
    const cushionWidth = 27.0;
    for (int i = 0; i < 3; i++) {
      final left = size.width / 2 - 40.5 + (i * cushionWidth);
      final cushionRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height / 2 - 16, cushionWidth, 32),
        const Radius.circular(4),
      );
      canvas.drawRRect(cushionRect, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
