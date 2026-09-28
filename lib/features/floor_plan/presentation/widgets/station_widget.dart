import 'dart:async';

import 'package:barber_shop_owner/features/floor_plan/domain/station.dart';
import 'package:barber_shop_owner/features/floor_plan/presentation/widgets/room/station_painter.dart';
import 'package:flutter/material.dart';

/// One illustrated station in the room, with a name tag underneath.
class StationWidget extends StatefulWidget {
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
  State<StationWidget> createState() => _StationWidgetState();
}

class _StationWidgetState extends State<StationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _snip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _clock;

  bool get _isServing => widget.station.status == ChairStatus.occupied;

  @override
  void initState() {
    super.initState();
    _syncActivity();
  }

  @override
  void didUpdateWidget(StationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.station.status != widget.station.status) _syncActivity();
  }

  /// Animates scissors and refreshes the elapsed time only while serving.
  void _syncActivity() {
    if (_isServing) {
      if (!_snip.isAnimating) _snip.repeat();
      _clock ??= Timer.periodic(
        const Duration(seconds: 30),
        (_) => setState(() {}),
      );
    } else {
      _snip.stop();
      _clock?.cancel();
      _clock = null;
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _snip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final station = widget.station;
    return Semantics(
      button: true,
      label: _semanticLabel(station),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: widget.isLeftWall
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CustomPaint(
                size: Size.infinite,
                painter: StationPainter(
                  status: station.status,
                  mirrored: !widget.isLeftWall,
                  animation: _snip,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 2, 28, 0),
              child: _NameTag(station: station),
            ),
          ],
        ),
      ),
    );
  }

  static String _semanticLabel(Station s) => switch (s.status) {
    ChairStatus.empty =>
      'Chair ${s.chairNumber}, free. Tap to assign a barber.',
    ChairStatus.cleaning => 'Chair ${s.chairNumber}, cleaning.',
    ChairStatus.available =>
      'Chair ${s.chairNumber}, ${s.activeBarberName ?? 'barber'} ready. Tap to seat a client.',
    ChairStatus.occupied =>
      'Chair ${s.chairNumber}, ${s.activeBarberName ?? 'barber'} serving '
          '${s.activeClientName ?? 'a client'}. Tap to check out.',
  };
}

class _NameTag extends StatelessWidget {
  const _NameTag({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    final number = '#${station.chairNumber}';
    final (text, background, foreground, dot) = switch (station.status) {
      ChairStatus.empty => (
        '$number · Tap to assign',
        const Color(0xFFF4F4F5),
        const Color(0xFF6B7280),
        null,
      ),
      ChairStatus.cleaning => (
        '$number · Cleaning',
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
        const Color(0xFFF59E0B),
      ),
      ChairStatus.available => (
        '$number · ${station.activeBarberName ?? 'Ready'}',
        Colors.white,
        const Color(0xFF111111),
        const Color(0xFF10B981),
      ),
      ChairStatus.occupied => (
        '$number · ${station.activeClientName ?? 'Client'} · ${_elapsed()}',
        const Color(0xFF111111),
        Colors.white,
        null,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF111111), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _elapsed() {
    final start = station.serviceStartTime;
    if (start == null) return 'now';
    final minutes = DateTime.now().difference(start).inMinutes;
    return minutes < 1 ? 'now' : '${minutes}m';
  }
}
