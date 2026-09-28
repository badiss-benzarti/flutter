import 'dart:math' as math;

import 'package:barber_shop_owner/core/ui/ui_helpers.dart';
import 'package:barber_shop_owner/features/auth_onboarding/presentation/auth_providers.dart';
import 'package:barber_shop_owner/features/floor_plan/domain/station.dart';
import 'package:barber_shop_owner/features/floor_plan/presentation/floor_plan_providers.dart';
import 'package:barber_shop_owner/features/floor_plan/presentation/widgets/floor_modals.dart';
import 'package:barber_shop_owner/features/floor_plan/presentation/widgets/room/room_shell_painter.dart';
import 'package:barber_shop_owner/features/floor_plan/presentation/widgets/room/salon_sign.dart';
import 'package:barber_shop_owner/features/floor_plan/presentation/widgets/station_widget.dart';
import 'package:barber_shop_owner/features/floor_plan/presentation/widgets/waiting_couch_widget.dart';
import 'package:barber_shop_owner/features/queue/presentation/queue_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class FloorPlanScreen extends ConsumerWidget {
  const FloorPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(authProvider).shop;
    final stationsAsync = ref.watch(floorPlanProvider);
    final queueItems = ref.watch(queueProvider).value ?? [];

    if (shop == null) {
      return const Scaffold(body: Center(child: Text('No shop loaded')));
    }

    final totalChairs = shop.totalChairs;
    final stations = stationsAsync.value ?? [];

    final activeCount = stations
        .where((s) => s.status == ChairStatus.occupied)
        .length;

    // First half of the chairs on the left wall, the rest on the right.
    final leftStations = <Station>[];
    final rightStations = <Station>[];
    for (int i = 1; i <= totalChairs; i++) {
      final station = stations.firstWhere(
        (s) => s.chairNumber == i,
        orElse: () => Station(chairNumber: i, shopId: shop.id),
      );
      if (i <= (totalChairs / 2).ceil()) {
        leftStations.add(station);
      } else {
        rightStations.add(station);
      }
    }

    Widget body;
    if (!stationsAsync.hasValue && stationsAsync.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!stationsAsync.hasValue && stationsAsync.hasError) {
      body = _ErrorView(
        onRetry: () => ref.read(floorPlanProvider.notifier).loadStations(),
      );
    } else {
      final rows = leftStations.length;
      final couch = WaitingCouchWidget(
        waitingCount: queueItems.length,
        onReserveTap: () =>
            showAppSheet<void>(context, (_) => const _AddWaitingSheet()),
        onQueueViewTap: () =>
            showAppSheet<void>(context, (_) => const _QueueListSheet()),
      );
      body = LayoutBuilder(
        builder: (context, constraints) {
          // Size the rows so the whole room, couch included, fits on one
          // screen when possible; larger shops scroll.
          const fixed = _ceilingHeight + _hudHeight + _couchAreaHeight;
          final rowHeight = rows == 0
              ? _maxRowHeight
              : ((constraints.maxHeight - fixed) / rows).clamp(
                  _minRowHeight,
                  _maxRowHeight,
                );

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(queueProvider);
              await ref.read(floorPlanProvider.notifier).loadStations();
            },
            child: SingleChildScrollView(
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
                          shopName: shop.name,
                          established: shop.createdAt.year,
                          active: activeCount,
                          total: totalChairs,
                          waiting: queueItems.length,
                        ),
                      ),
                      for (var i = 0; i < rows; i++)
                        SizedBox(
                          height: rowHeight,
                          child: Row(
                            children: [
                              Expanded(
                                child: StationWidget(
                                  station: leftStations[i],
                                  isLeftWall: true,
                                  onTap: () => _handleStationTap(
                                    context,
                                    ref,
                                    leftStations[i],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: i < rightStations.length
                                    ? StationWidget(
                                        station: rightStations[i],
                                        isLeftWall: false,
                                        onTap: () => _handleStationTap(
                                          context,
                                          ref,
                                          rightStations[i],
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 14),
                        child: couch,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(bottom: false, child: body),
    );
  }

  static const double _ceilingHeight = 64;
  static const double _wallWidth = 18;
  static const double _hudHeight = 50;
  static const double _couchAreaHeight = 196;
  static const double _minRowHeight = 112;
  static const double _maxRowHeight = 150;

  void _handleStationTap(BuildContext context, WidgetRef ref, Station station) {
    switch (station.status) {
      case ChairStatus.empty:
      case ChairStatus.cleaning:
        FloorModals.showAssignBarberDialog(context, ref, station.chairNumber);
      case ChairStatus.available:
        FloorModals.showSeatClientDialog(context, ref, station);
      case ChairStatus.occupied:
        FloorModals.showCheckoutDialog(context, ref, station);
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          const Text('Could not load the floor plan.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _AddWaitingSheet extends ConsumerStatefulWidget {
  const _AddWaitingSheet();

  @override
  ConsumerState<_AddWaitingSheet> createState() => _AddWaitingSheetState();
}

class _AddWaitingSheetState extends ConsumerState<_AddWaitingSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(
      children: [
        const Text(
          'Reserve Waiting Spot',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Client Name',
            prefixIcon: Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone Number (Optional)',
            prefixIcon: Icon(Icons.phone),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: _busy ? null : _submit,
          child: const Text('Add to Waiting Couch'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showSnack(context, 'Enter the client name.', isError: true);
      return;
    }
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => ref
          .read(queueProvider.notifier)
          .addToQueue(clientName: name, clientPhone: _phoneController.text),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }
}

class _QueueListSheet extends ConsumerWidget {
  const _QueueListSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueItems = ref.watch(queueProvider).value ?? [];

    return SheetBody(
      children: [
        const Text(
          'Waiting Area Queue',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap a chair with a free barber to seat the next client.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (queueItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('No clients currently waiting.')),
          )
        else
          ...queueItems.asMap().entries.map((entry) {
            final item = entry.value;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.black,
                child: Text(
                  '${entry.key + 1}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                item.clientName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Waiting since ${DateFormat('h:mm a').format(item.createdAt)}',
              ),
              trailing: IconButton(
                tooltip: 'Remove from queue',
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => runAction(
                  context,
                  () =>
                      ref.read(queueProvider.notifier).removeFromQueue(item.id),
                ),
              ),
            );
          }),
      ],
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
