import 'package:barber_shop_owner/core/ui/ui_helpers.dart';
import 'package:barber_shop_owner/features/auth_onboarding/presentation/auth_providers.dart';
import 'package:barber_shop_owner/features/floor_plan/domain/station.dart';
import 'package:barber_shop_owner/features/floor_plan/presentation/floor_plan_providers.dart';
import 'package:barber_shop_owner/features/floor_plan/presentation/widgets/floor_modals.dart';
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
      body = Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(queueProvider);
                await ref.read(floorPlanProvider.notifier).loadStations();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(
                  top: 12,
                  bottom: 150, // Room for the floating waiting couch
                  left: 8,
                  right: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: leftStations.map((s) {
                          return StationWidget(
                            station: s,
                            isLeftWall: true,
                            onTap: () => _handleStationTap(context, ref, s),
                          );
                        }).toList(),
                      ),
                    ),
                    // Central corridor walkway line
                    Container(
                      width: 1.5,
                      height: leftStations.length * 96.0,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: const Color(0xFFE5E7EB),
                    ),
                    Expanded(
                      child: Column(
                        children: rightStations.map((s) {
                          return StationWidget(
                            station: s,
                            isLeftWall: false,
                            onTap: () => _handleStationTap(context, ref, s),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Center(
              child: WaitingCouchWidget(
                waitingCount: queueItems.length,
                onReserveTap: () => showAppSheet<void>(
                  context,
                  (_) => const _AddWaitingSheet(),
                ),
                onQueueViewTap: () =>
                    showAppSheet<void>(context, (_) => const _QueueListSheet()),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(
              shop.name,
              activeCount,
              totalChairs,
              queueItems.length,
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String shopName, int active, int total, int waiting) {
    final today = DateFormat('EEE d MMM').format(DateTime.now());
    final occupancyRate = total > 0 ? ((active / total) * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              today,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Column(
            children: [
              Text(
                shopName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$active/$total Chairs Active ($occupancyRate%)',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.event_seat_outlined, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$waiting waiting',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
