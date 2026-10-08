import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

/// Map settings shared by every map in the app, so the tile provider can be
/// changed in one place (roadmap 3.2b: leave the public OpenStreetMap
/// servers before the beta).
abstract final class MapTiles {
  /// Centre of Tunis, the launch city.
  static const LatLng defaultCenter = LatLng(36.8065, 10.1815);

  static TileLayer layer() => TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.barberflow.barber_shop_owner',
  );

  static RichAttributionWidget attribution() => const RichAttributionWidget(
    attributions: [TextSourceAttribution('OpenStreetMap contributors')],
  );
}
