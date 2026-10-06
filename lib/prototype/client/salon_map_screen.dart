import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../mock_data.dart';
import '../widgets/ui.dart';
import 'salon_page.dart';

/// Client home: a map of Tunis with every salon using the app. Pin colors
/// show live status; tapping one previews the salon.
class SalonMapScreen extends StatefulWidget {
  const SalonMapScreen({super.key});

  @override
  State<SalonMapScreen> createState() => _SalonMapScreenState();
}

class _SalonMapScreenState extends State<SalonMapScreen> {
  final _map = MapController();
  MockSalon? _selected;
  bool _openOnly = false;

  static const _you = LatLng(36.8190, 10.1900);

  @override
  Widget build(BuildContext context) {
    final visible = salons.where((s) => !_openOnly || s.open).toList();

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: const LatLng(36.835, 10.215),
            initialZoom: 12.2,
            onTap: (_, _) => setState(() => _selected = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.barberflow.barber_shop_owner',
            ),
            MarkerLayer(
              markers: [
                const Marker(
                  point: _you,
                  width: 26,
                  height: 26,
                  child: _YouDot(),
                ),
                for (final salon in visible)
                  Marker(
                    point: salon.position,
                    width: 120,
                    height: 64,
                    alignment: Alignment.topCenter,
                    child: _SalonPin(
                      salon: salon,
                      selected: salon == _selected,
                      onTap: () {
                        setState(() => _selected = salon);
                        _map.move(salon.position, 13.5);
                      },
                    ),
                  ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
              children: [
                InkCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Salons in Tunis',
                          style: TextStyle(fontWeight: FontWeight.w700),
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
              ],
            ),
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 14,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _selected == null
                ? _NearbyStrip(
                    salons: visible,
                    onSelect: (s) {
                      setState(() => _selected = s);
                      _map.move(s.position, 13.5);
                    },
                  )
                : _SalonPreview(
                    key: ValueKey(_selected!.id),
                    salon: _selected!,
                  ),
          ),
        ),
      ],
    );
  }
}

class _YouDot extends StatelessWidget {
  const _YouDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const [
          BoxShadow(color: Color(0x552563EB), blurRadius: 10, spreadRadius: 4),
        ],
      ),
    );
  }
}

class _SalonPin extends StatelessWidget {
  const _SalonPin({
    required this.salon,
    required this.selected,
    required this.onTap,
  });

  final MockSalon salon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(salon.status);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? ink : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ink, width: 1.5),
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
                Icon(
                  Icons.content_cut,
                  size: 13,
                  color: selected ? Colors.white : ink,
                ),
                const SizedBox(width: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  salon.open ? '${salon.waitMinutes}′' : '—',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: selected ? Colors.white : ink,
                  ),
                ),
              ],
            ),
          ),
          CustomPaint(
            size: const Size(12, 8),
            painter: _PinTail(selected ? ink : Colors.white),
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
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  @override
  bool shouldRepaint(_PinTail oldDelegate) => oldDelegate.fill != fill;
}

class _NearbyStrip extends StatelessWidget {
  const _NearbyStrip({required this.salons, required this.onSelect});

  final List<MockSalon> salons;
  final ValueChanged<MockSalon> onSelect;

  @override
  Widget build(BuildContext context) {
    final sorted = [...salons]
      ..sort((a, b) {
        if (a.open != b.open) return a.open ? -1 : 1;
        return a.waitMinutes.compareTo(b.waitMinutes);
      });
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = sorted[i];
          return SizedBox(
            width: 210,
            child: InkCard(
              onTap: () => onSelect(s),
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
                    s.area,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  Row(
                    children: [
                      StatusPill(s),
                      const Spacer(),
                      Stars(s.rating, size: 12),
                    ],
                  ),
                ],
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

  final MockSalon salon;

  @override
  Widget build(BuildContext context) {
    final onDuty = salon.barbers.where((b) => b.onDuty).length;
    return InkCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  salon.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                  ),
                ),
              ),
              Stars(salon.rating, reviews: salon.reviews),
            ],
          ),
          const SizedBox(height: 2),
          Text(salon.area, style: const TextStyle(color: muted)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusPill(salon),
              _Info(Icons.event_seat_outlined, '${salon.waiting} waiting'),
              _Info(Icons.content_cut, '$onDuty barbers on duty'),
            ],
          ),
          const SizedBox(height: 14),
          primaryButton(
            salon.open ? 'See the salon live' : 'See the salon',
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => SalonPage(salon: salon)),
            ),
            icon: Icons.storefront_outlined,
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: muted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
