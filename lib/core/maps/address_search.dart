import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' show LatLng;

import '../errors/app_exception.dart';

/// A place found by [AddressSearch].
class FoundPlace {
  const FoundPlace(this.label, this.position);

  final String label;
  final LatLng position;
}

/// Finds addresses in Tunisia with OpenStreetMap's free Nominatim service.
///
/// Meant for occasional use (an owner placing a salon), as its usage policy
/// requires: one search per submit, never per keystroke.
class AddressSearch {
  AddressSearch({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<FoundPlace>> search(String query) async {
    final text = query.trim();
    if (text.length < 3) return const [];
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': text,
      'format': 'jsonv2',
      'limit': '5',
      'countrycodes': 'tn',
      'accept-language': 'fr,en',
    });
    try {
      final response = await _client
          .get(
            uri,
            // Browsers send their own User-Agent and refuse to override it.
            headers: kIsWeb
                ? const {}
                : const {'User-Agent': 'BarberFlow/1.0 (salon locator)'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw const AppException('Address search is unavailable right now.');
      }
      final results = jsonDecode(response.body) as List<dynamic>;
      return [
        for (final r in results.cast<Map<String, dynamic>>())
          FoundPlace(
            r['display_name'] as String,
            LatLng(
              double.parse(r['lat'] as String),
              double.parse(r['lon'] as String),
            ),
          ),
      ];
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(
        'Could not search addresses. Check your connection.',
      );
    }
  }
}
