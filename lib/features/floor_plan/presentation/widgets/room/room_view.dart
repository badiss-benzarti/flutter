import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/station.dart';
import '../station_widget.dart';
import '../waiting_couch_widget.dart';
import 'room_shell_painter.dart';
import 'salon_sign.dart';

/// The illustrated salon room: clipper-guard sign hanging from the ceiling,
/// stations along both walls and the waiting couch at the front.
///
/// Used by the owner's floor plan and, read-only with [anonymizeClients],
/// by clients browsing a salon.
class RoomView extends StatelessWidget {
  const RoomView({
    super.key,
    required this.shopName,
    required this.established,
    required this.stations,
    required this.totalChairs,
    required this.waitingCount,
    this.onStationTap,
    this.onReserveTap,
    this.onQueueViewTap,
    this.onRefresh,
    this.anonymizeClients = false,
    this.reserveLabel,
  });

  final String shopName;
  final int established;
  final List<Station> stations;
  final int totalChairs;
  final int waitingCount;
  final ValueChanged<Station>? onStationTap;
  final VoidCallback? onReserveTap;
  final VoidCallback? onQueueViewTap;
  final Future<void> Function()? onRefresh;

  /// Hides seated clients' names, for public viewers.
  final bool anonymizeClients;

  /// Overrides the couch button text ("RESERVE WAITING SPOT").
  final String? reserveLabel;

  static const double _ceilingHeight = 64;
  static const double _wallWidth = 18;
  static const double _hudHeight = 70;
  static const double _couchAreaHeight = 196;
  static const double _minRowHeight = 106;
  static const double _maxRowHeight = 150;

  @override
  Widget build(BuildContext context) {
    // First half of the chairs on the left wall, the rest on the right.
    final left = <Station>[];
    final right = <Station>[];
    for (var i = 1; i <= totalChairs; i++) {
      var station = stations.firstWhere(
        (s) => s.chairNumber == i,
        orElse: () => Station(chairNumber: i, shopId: ''),
      );
      if (anonymizeClients && station.activeClientName != null) {
        station = Station(
          chairNumber: station.chairNumber,
          shopId: station.shopId,
          status: station.status,
          activeBarberId: station.activeBarberId,
          activeBarberName: station.activeBarberName,
          serviceStartTime: station.serviceStartTime,
        );
      }
      (i <= (totalChairs / 2).ceil() ? left : right).add(station);
    }
    final active = stations
        .where((s) => s.status == ChairStatus.occupied)
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Size the rows so the whole room, couch included, fits on one
        // screen when possible; larger shops scroll.
        const fixed = _ceilingHeight + _hudHeight + _couchAreaHeight;
        final rows = left.length;
        final rowHeight = rows == 0
            ? _maxRowHeight
            : ((constraints.maxHeight - fixed) / rows).clamp(
                _minRowHeight,
                _maxRowHeight,
              );

        Widget station(Station s, bool isLeftWall) => StationWidget(
          station: s,
          isLeftWall: isLeftWall,
          publicView: anonymizeClients,
          onTap: onStationTap == null ? () {} : () => onStationTap!(s),
        );

        final room = SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: CustomPaint(
              painter: const RoomShellPainter(
                ceilingHeight: _ceilingHeight,
                wallWidth: _wallWidth,
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: _ceilingHeight + _hudHeight,
                    child: _RoomHeader(
                      shopName: shopName,
                      established: established,
                      active: active,
                      total: totalChairs,
                      waiting: waitingCount,
                    ),
                  ),
                  for (var i = 0; i < rows; i++)
                    SizedBox(
                      height: rowHeight,
                      child: Row(
                        children: [
                          Expanded(child: station(left[i], true)),
                          Expanded(
                            child: i < right.length
                                ? station(right[i], false)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 14),
                    child: WaitingCouchWidget(
                      waitingCount: waitingCount,
                      onReserveTap: onReserveTap ?? () {},
                      onQueueViewTap: onQueueViewTap ?? () {},
                      reserveLabel: reserveLabel,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        return onRefresh == null
            ? room
            : RefreshIndicator(onRefresh: onRefresh!, child: room);
      },
    );
  }
}

/// Top of the room: the salon's marquee sign hanging from the ceiling, with
/// live status printed on the back wall to either side of it.
class _RoomHeader extends StatelessWidget {
  const _RoomHeader({
    required this.shopName,
    required this.established,
    required this.active,
    required this.total,
    required this.waiting,
  });

  final String shopName;
  final int established;
  final int active;
  final int total;
  final int waiting;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 9,
      height: 1.3,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: Color(0xFF6B7280),
    );
    final occupancy = total > 0 ? (active / total * 100).round() : 0;
    final today = DateFormat('EEE d MMM').format(DateTime.now()).toUpperCase();

    return LayoutBuilder(
      builder: (context, constraints) {
        final signWidth = math.min(
          constraints.maxWidth * 0.62,
          (constraints.maxHeight - 4) * SalonSign.aspectRatio,
        );
        final sideWidth = (constraints.maxWidth - signWidth) / 2 - 26;

        Widget side(String text, TextAlign align) => SizedBox(
          width: math.max(0, sideWidth),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: align == TextAlign.left
                ? Alignment.bottomLeft
                : Alignment.bottomRight,
            child: Text(text, textAlign: align, style: style),
          ),
        );

        return Stack(
          children: [
            Align(
              alignment: const Alignment(0, -0.2),
              child: SizedBox(
                width: signWidth,
                child: SalonSign(name: shopName, established: established),
              ),
            ),
            Positioned(left: 26, bottom: 4, child: side(today, TextAlign.left)),
            Positioned(
              right: 26,
              bottom: 4,
              child: side(
                '$active/$total ACTIVE\n$occupancy% · $waiting WAITING',
                TextAlign.right,
              ),
            ),
          ],
        );
      },
    );
  }
}
