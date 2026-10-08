import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/maps/map_tiles.dart';
import 'client_directory.dart';
import 'client_salon_page.dart';

const _ink = Color(0xFF111111);
const _muted = Color(0xFF6B7280);

Color loadColor(SalonLoad load) => switch (load) {
  SalonLoad.available => const Color(0xFF10B981),
  SalonLoad.busy => const Color(0xFFF59E0B),
  SalonLoad.closed => const Color(0xFF9CA3AF),
};

String loadLabel(ClientSalon s) => switch (s.load) {
  SalonLoad.closed => 'Closed',
  _ when s.waitingCount == 0 => 'No wait',
  _ => '${s.waitingCount} waiting',
};

/// Client home: the listed salons around, with their live status. Loads the
/// visible area once the map stops moving, and refreshes every minute while
/// the map is on screen ([active]).
class ClientMapScreen extends ConsumerStatefulWidget {
  const ClientMapScreen({super.key, required this.active});

  final bool active;

  static const refreshEvery = Duration(minutes: 1);

  @override
  ConsumerState<ClientMapScreen> createState() => _ClientMapScreenState();
}

class _ClientMapScreenState extends ConsumerState<ClientMapScreen> {
  final _map = MapController();
  Timer? _debounce;
  Timer? _refresh;
  List<ClientSalon> _salons = const [];
  ClientSalon? _selected;
  bool _openOnly = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(ClientMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncTimer();
      if (widget.active) _load();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _refresh?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _refresh?.cancel();
    _refresh = widget.active
        ? Timer.periodic(ClientMapScreen.refreshEvery, (_) => _load())
        : null;
  }

  /// Waits for the map to settle before asking the server.
  void _scheduleLoad() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _load);
  }

  Future<void> _load() async {
    final LatLngBounds bounds;
    try {
      bounds = _map.camera.visibleBounds;
    } catch (_) {
      return; // Map not laid out yet.
    }
    // A margin around the screen, so small pans need no new request.
    final latPad = (bounds.north - bounds.south) * 0.5;
    final lngPad = (bounds.east - bounds.west) * 0.5;
    try {
      final salons = await ref
          .read(clientDirectoryProvider)
          .salonsIn(
            south: bounds.south - latPad,
            north: bounds.north + latPad,
            west: bounds.west - lngPad,
            east: bounds.east + lngPad,
          );
      if (!mounted) return;
      setState(() {
        _salons = salons;
        _loading = false;
        _error = null;
        final selected = _selected;
        if (selected != null) {
          _selected = salons.where((s) => s.id == selected.id).firstOrNull;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = describeError(e);
      });
    }
  }

  void _select(ClientSalon salon) {
    setState(() => _selected = salon);
    _map.move(salon.position, 15);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _salons.where((s) => !_openOnly || s.isOpen).toList();
    final selected = _selected;

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: MapTiles.defaultCenter,
            initialZoom: 12.5,
            onMapReady: _load,
            onPositionChanged: (_, hasGesture) {
              if (hasGesture) _scheduleLoad();
            },
            onTap: (_, _) => setState(() => _selected = null),
          ),
          children: [
            MapTiles.layer(),
            MarkerLayer(
              markers: [
                for (final salon in visible)
                  Marker(
                    point: salon.position,
                    width: 120,
                    height: 64,
                    alignment: Alignment.topCenter,
                    child: _SalonPin(
                      salon: salon,
                      selected: salon.id == selected?.id,
                      onTap: () => _select(salon),
                    ),
                  ),
              ],
            ),
            MapTiles.attribution(),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _loading
                            ? 'Finding salons…'
                            : visible.isEmpty
                            ? 'No salons here yet'
                            : '${visible.length} salon'
                                  '${visible.length == 1 ? '' : 's'} nearby',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    FilterChip(
                      label: const Text('Open now'),
                      selected: _openOnly,
                      onSelected: (v) => setState(() => _openOnly = v),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 14,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _error != null && _salons.isEmpty
                ? _InfoCard(
                    key: const ValueKey('error'),
                    message: _error!,
                    onRetry: _load,
                  )
                : selected != null
                ? _SalonPreview(key: ValueKey(selected.id), salon: selected)
                : visible.isEmpty
                ? const SizedBox.shrink()
                : _NearbyStrip(salons: visible, onSelect: _select),
          ),
        ),
      ],
    );
  }
}

class _SalonPin extends StatelessWidget {
  const _SalonPin({
    required this.salon,
    required this.selected,
    required this.onTap,
  });

  final ClientSalon salon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : _ink;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? _ink : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _ink, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.content_cut, size: 13, color: fg),
                const SizedBox(width: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: loadColor(salon.load),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.person, size: 13, color: fg),
                Text(
                  salon.isOpen ? '${salon.waitingCount}' : '—',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
          CustomPaint(
            size: const Size(12, 8),
            painter: _PinTail(selected ? _ink : Colors.white),
          ),
        ],
      ),
    );
  }
}

class _PinTail extends CustomPainter {
  const _PinTail(this.fill);

  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas
      ..drawPath(path, Paint()..color = fill)
      ..drawPath(
        path,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  @override
  bool shouldRepaint(_PinTail oldDelegate) => oldDelegate.fill != fill;
}

/// Small pill: colored dot and "No wait" / "3 waiting" / "Closed".
class LoadPill extends StatelessWidget {
  const LoadPill(this.salon, {super.key});

  final ClientSalon salon;

  @override
  Widget build(BuildContext context) {
    final color = loadColor(salon.load);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            loadLabel(salon),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyStrip extends StatelessWidget {
  const _NearbyStrip({required this.salons, required this.onSelect});

  final List<ClientSalon> salons;
  final ValueChanged<ClientSalon> onSelect;

  @override
  Widget build(BuildContext context) {
    // Open salons first, the shortest line first.
    final sorted = [...salons]
      ..sort((a, b) {
        if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
        return a.waitingCount.compareTo(b.waitingCount);
      });
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = sorted[i];
          return SizedBox(
            width: 220,
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelect(s),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        s.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                      LoadPill(s),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SalonPreview extends StatelessWidget {
  const _SalonPreview({super.key, required this.salon});

  final ClientSalon salon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              salon.name,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
            ),
            const SizedBox(height: 2),
            Text(salon.address, style: const TextStyle(color: _muted)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                LoadPill(salon),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chair_outlined, size: 15, color: _muted),
                    const SizedBox(width: 4),
                    Text(
                      '${salon.totalChairs} chairs',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ClientSalonPage(shopId: salon.id),
                ),
              ),
              icon: const Icon(Icons.storefront_outlined),
              label: Text(
                salon.isOpen ? 'See the salon live' : 'See the salon',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.cloud_off_outlined),
        title: Text(message),
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
      ),
    );
  }
}
