import 'package:barber_shop_owner/features/floor_plan/domain/station.dart';
import 'package:flutter/material.dart';

class StationWidget extends StatelessWidget {
  const StationWidget({
    super.key,
    required this.station,
    required this.isLeftWall,
    required this.onTap,
  });

  final Station station;
  final bool isLeftWall;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getBorderColor(),
            width: station.status == ChairStatus.occupied ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: isLeftWall
              ? [
                  _buildMirrorAndClippers(),
                  const SizedBox(width: 8),
                  _buildChairArea(),
                ]
              : [
                  _buildChairArea(),
                  const SizedBox(width: 8),
                  _buildMirrorAndClippers(),
                ],
        ),
      ),
    );
  }

  Color _getBorderColor() {
    switch (station.status) {
      case ChairStatus.occupied:
        return Colors.black;
      case ChairStatus.available:
        return const Color(0xFF10B981);
      case ChairStatus.cleaning:
        return const Color(0xFFF59E0B);
      case ChairStatus.empty:
        return const Color(0xFFD1D5DB);
    }
  }

  Widget _buildMirrorAndClippers() {
    return Container(
      width: 44,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF9CA3AF), width: 1.2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mirror header
          Container(
            width: 28,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF6B7280),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Clipper icons
          const Icon(Icons.content_cut, size: 16, color: Color(0xFF374151)),
          Container(
            width: 22,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: const Color(0xFF9CA3AF), width: 1),
            ),
            child: const Center(
              child: Text(
                '0.5',
                style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChairArea() {
    return SizedBox(
      width: 100,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Station ID watermark
          Positioned(
            top: 0,
            left: isLeftWall ? 0 : null,
            right: isLeftWall ? null : 0,
            child: Text(
              '#${station.chairNumber}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),

          // Central Barber Chair
          CustomPaint(
            size: const Size(60, 50),
            painter: _BarberChairPainter(status: station.status),
          ),

          // Occupied Indicator: Barber + Client
          if (station.status == ChairStatus.occupied)
            Positioned(
              bottom: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      station.activeClientName ?? 'Client',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'by ${station.activeBarberName ?? 'Barber'}',
                    style: const TextStyle(
                      fontSize: 8,
                      color: Color(0xFF4B5563),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Available Indicator: Barber Ready
          if (station.status == ChairStatus.available)
            Positioned(
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Text(
                  station.activeBarberName ?? 'Ready',
                  style: const TextStyle(
                    color: Color(0xFF166534),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

          // Empty Chair: Tap to Assign
          if (station.status == ChairStatus.empty)
            Positioned(
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 10, color: Color(0xFF6B7280)),
                    SizedBox(width: 2),
                    Text(
                      'Assign',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BarberChairPainter extends CustomPainter {
  const _BarberChairPainter({required this.status});
  final ChairStatus status;

  @override
  void paint(Canvas canvas, Size size) {
    final paintFill = Paint()
      ..color = status == ChairStatus.empty
          ? const Color(0xFFE5E7EB)
          : const Color(0xFF1F2937)
      ..style = PaintingStyle.fill;

    final paintStroke = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Chair base circle
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.7), 16, paintFill);
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.7),
      16,
      paintStroke,
    );

    // Chair backrest
    final backrestRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.35),
        width: 32,
        height: 18,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(backrestRect, paintFill);
    canvas.drawRRect(backrestRect, paintStroke);

    // Headrest
    final headrestRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.15),
        width: 18,
        height: 6,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(headrestRect, paintFill);
    canvas.drawRRect(headrestRect, paintStroke);

    // Footrest
    canvas.drawLine(
      Offset(size.width / 2 - 12, size.height * 0.95),
      Offset(size.width / 2 + 12, size.height * 0.95),
      paintStroke,
    );
  }

  @override
  bool shouldRepaint(covariant _BarberChairPainter oldDelegate) =>
      oldDelegate.status != status;
}
