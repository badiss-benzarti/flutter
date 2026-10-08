import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../core/maps/map_tiles.dart';
import '../../core/ui/ui_helpers.dart';
import '../auth_onboarding/domain/shop_profile.dart';
import '../auth_onboarding/presentation/auth_providers.dart';
import 'location_picker_screen.dart';

/// Settings card: where the salon is, whether clients can find it on the
/// map, and whether it is open now.
class SalonMapCard extends ConsumerWidget {
  const SalonMapCard({super.key, required this.shop});

  final ShopProfile shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authProvider.notifier);
    final position = shop.hasLocation
        ? LatLng(shop.latitude!, shop.longitude!)
        : null;

    Future<void> place() async {
      final picked = await LocationPickerScreen.pick(
        context,
        initial: position,
        addressHint: position == null ? shop.address : null,
      );
      if (picked == null || !context.mounted) return;
      await runAction(
        context,
        () => auth.updateShopLocation(picked.latitude, picked.longitude),
        successMessage: 'Location saved.',
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Salon on the map',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Clients near you find the salon, its wait time and its '
              'barbers on the map.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          SizedBox(
            height: 150,
            child: position == null
                ? _NotPlaced(onTap: place)
                : _MapPreview(position: position, onTap: place),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: OutlinedButton.icon(
              onPressed: place,
              icon: Icon(
                position == null ? Icons.add_location_alt : Icons.edit_location,
              ),
              label: Text(
                position == null ? 'Place on the map' : 'Change location',
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Show my salon to clients'),
            subtitle: Text(
              !shop.hasLocation
                  ? 'Place your salon on the map first.'
                  : shop.isListed
                  ? 'Clients can find you on the map.'
                  : 'Hidden from clients.',
            ),
            value: shop.isListed && shop.hasLocation,
            onChanged: shop.hasLocation
                ? (v) => runAction(context, () => auth.setShopListed(v))
                : null,
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Open now'),
            subtitle: Text(
              shop.isOpen
                  ? 'Clients see the salon as open.'
                  : 'Clients see the salon as closed.',
            ),
            value: shop.isOpen,
            onChanged: (v) => runAction(context, () => auth.setShopOpen(v)),
          ),
        ],
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.position, required this.onTap});

  final LatLng position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          // Rebuilt when the location changes.
          key: ValueKey(position),
          options: MapOptions(
            initialCenter: position,
            initialZoom: 16,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            MapTiles.layer(),
            MarkerLayer(
              markers: [
                Marker(
                  point: position,
                  width: 40,
                  height: 40,
                  alignment: Alignment.topCenter,
                  child: const Icon(
                    Icons.location_on,
                    size: 40,
                    color: Color(0xFF111111),
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(onTap: onTap),
          ),
        ),
      ],
    );
  }
}

class _NotPlaced extends StatelessWidget {
  const _NotPlaced({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: const Color(0xFFF3F4F6),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 40, color: Colors.grey),
            SizedBox(height: 6),
            Text(
              'Not on the map yet',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
