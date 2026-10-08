import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../core/errors/app_exception.dart';
import '../../core/maps/address_search.dart';
import '../../core/maps/map_tiles.dart';

/// Full-screen map to place the salon: the pin stays in the middle and the
/// owner moves the map under it. Pops with the chosen [LatLng].
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initial, this.addressHint});

  final LatLng? initial;

  /// Pre-filled search, e.g. the salon's address.
  final String? addressHint;

  static Future<LatLng?> pick(
    BuildContext context, {
    LatLng? initial,
    String? addressHint,
  }) {
    return Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) =>
            LocationPickerScreen(initial: initial, addressHint: addressHint),
      ),
    );
  }

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _ink = Color(0xFF111111);

  final _map = MapController();
  final _search = AddressSearch();
  late final _query = TextEditingController(text: widget.addressHint ?? '');

  late LatLng _center = widget.initial ?? MapTiles.defaultCenter;
  List<FoundPlace> _results = const [];
  bool _searching = false;
  String? _searchError;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await _search.search(_query.text);
      if (!mounted) return;
      setState(() {
        _results = results;
        if (results.isEmpty) _searchError = 'No address found. Move the map.';
      });
    } on AppException catch (e) {
      if (mounted) setState(() => _searchError = e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _goTo(FoundPlace place) {
    _map.move(place.position, 17);
    setState(() {
      _center = place.position;
      _results = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Place your salon')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.initial == null ? 12.5 : 17,
              onPositionChanged: (camera, _) =>
                  setState(() => _center = camera.center),
            ),
            children: [MapTiles.layer(), MapTiles.attribution()],
          ),
          // The pin's tip marks the map centre.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 46),
                child: Icon(
                  Icons.location_on,
                  size: 52,
                  color: _ink,
                  shadows: [Shadow(color: Colors.black38, blurRadius: 8)],
                ),
              ),
            ),
          ),
          Positioned(left: 12, right: 12, top: 12, child: _searchPanel()),
          Positioned(left: 12, right: 12, bottom: 12, child: _confirmPanel()),
        ],
      ),
    );
  }

  Widget _searchPanel() {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _runSearch(),
            decoration: InputDecoration(
              hintText: 'Search an address or area',
              prefixIcon: const Icon(Icons.search),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Search',
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _runSearch,
                    ),
            ),
          ),
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                _searchError!,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          for (final place in _results) ...[
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const Icon(Icons.place_outlined),
              title: Text(
                place.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _goTo(place),
            ),
          ],
        ],
      ),
    );
  }

  Widget _confirmPanel() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Move the map until the pin is on your salon\'s door.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${_center.latitude.toStringAsFixed(5)}, '
              '${_center.longitude.toStringAsFixed(5)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(_center),
              icon: const Icon(Icons.check),
              label: const Text('Use this spot'),
            ),
          ],
        ),
      ),
    );
  }
}
