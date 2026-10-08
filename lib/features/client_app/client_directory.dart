import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/cloud/cloud_errors.dart';
import '../floor_plan/domain/station.dart';

/// A salon as clients see it on the map.
class ClientSalon {
  const ClientSalon({
    required this.id,
    required this.name,
    required this.address,
    required this.position,
    required this.isOpen,
    required this.waitingCount,
    required this.totalChairs,
    required this.established,
  });

  final String id;
  final String name;
  final String address;
  final LatLng position;
  final bool isOpen;
  final int waitingCount;
  final int totalChairs;
  final int established;

  SalonLoad get load => !isOpen
      ? SalonLoad.closed
      : waitingCount >= busyFrom
      ? SalonLoad.busy
      : SalonLoad.available;

  /// From this many clients waiting, a salon shows as busy.
  static const busyFrom = 4;
}

enum SalonLoad { available, busy, closed }

class ClientBarber {
  const ClientBarber({
    required this.id,
    required this.name,
    required this.specialty,
    required this.isOnDuty,
    required this.ratingAvg,
    required this.ratingCount,
  });

  final String id;
  final String name;
  final String specialty;
  final bool isOnDuty;

  /// From clients' ratings of real visits.
  final double ratingAvg;
  final int ratingCount;
}

class ClientService {
  const ClientService(this.name, this.price, this.minutes);

  final String name;
  final double price;
  final int minutes;
}

/// A photo of a cut, as shown on the salon page and in Social.
class ClientPost {
  const ClientPost({
    required this.id,
    required this.shopId,
    required this.barberName,
    required this.imageUrl,
    required this.caption,
    required this.ratingAvg,
    required this.ratingCount,
    required this.commentCount,
    required this.createdAt,
    this.shopName,
  });

  final String id;
  final String shopId;
  final String? shopName;
  final String barberName;
  final String imageUrl;
  final String caption;
  final double ratingAvg;
  final int ratingCount;
  final int commentCount;
  final DateTime createdAt;
}

class ClientComment {
  const ClientComment(this.authorName, this.body, this.createdAt);

  final String authorName;
  final String body;
  final DateTime createdAt;
}

/// Everything on a salon's page.
class SalonDetails {
  const SalonDetails({
    required this.salon,
    required this.barbers,
    required this.services,
    required this.stations,
    required this.posts,
  });

  final ClientSalon salon;
  final List<ClientBarber> barbers;
  final List<ClientService> services;

  /// Chairs with their barber; never who is seated.
  final List<Station> stations;
  final List<ClientPost> posts;

  int get barbersOnDuty => barbers.where((b) => b.isOnDuty).length;
}

/// What clients read from the server: listed salons only, and only their
/// public side (row-level security keeps the rest out). Works without an
/// account. Failures are thrown as `AppException`.
abstract class ClientDirectory {
  /// Listed salons inside the given area (the visible map, with a margin).
  Future<List<ClientSalon>> salonsIn({
    required double south,
    required double west,
    required double north,
    required double east,
  });

  Future<SalonDetails> salon(String shopId);

  /// Latest photos from all listed salons.
  Future<List<ClientPost>> latestPosts({int limit = 30});

  Future<List<ClientComment>> comments(String postId);
}

class SupabaseClientDirectory implements ClientDirectory {
  SupabaseClientDirectory(this._client);

  final SupabaseClient _client;

  static const _shopColumns =
      'id, name, address, latitude, longitude, is_open, waiting_count, '
      'total_chairs, created_at';
  static const _postColumns =
      'id, shop_id, image_path, caption, rating_avg, rating_count, '
      'comment_count, created_at, barbers(name)';

  @override
  Future<List<ClientSalon>> salonsIn({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    try {
      final rows = await _client
          .from('shops')
          .select(_shopColumns)
          .eq('is_listed', true)
          .gte('latitude', south)
          .lte('latitude', north)
          .gte('longitude', west)
          .lte('longitude', east)
          .limit(200);
      return rows.map(_salon).toList();
    } catch (e) {
      throw cloudException(e);
    }
  }

  @override
  Future<SalonDetails> salon(String shopId) async {
    try {
      final results = await Future.wait<dynamic>([
        _client.from('shops').select(_shopColumns).eq('id', shopId).single(),
        _client
            .from('barbers')
            .select('id, name, specialty, is_on_duty, rating_avg, rating_count')
            .eq('shop_id', shopId)
            .eq('is_archived', false)
            .order('name'),
        _client
            .from('services')
            .select('name, price, duration_minutes')
            .eq('shop_id', shopId)
            .order('price'),
        _client
            .from('chairs')
            .select(
              'chair_number, status, active_barber_id, service_start_time',
            )
            .eq('shop_id', shopId)
            .order('chair_number'),
        _client
            .from('portfolio_posts')
            .select(_postColumns)
            .eq('shop_id', shopId)
            .order('created_at', ascending: false)
            .limit(60),
      ]);
      final salon = _salon(results[0] as Map<String, dynamic>);
      final barbers = [
        for (final b in results[1] as List<Map<String, dynamic>>)
          ClientBarber(
            id: b['id'] as String,
            name: b['name'] as String,
            specialty: b['specialty'] as String,
            isOnDuty: b['is_on_duty'] as bool,
            ratingAvg: (b['rating_avg'] as num).toDouble(),
            ratingCount: b['rating_count'] as int,
          ),
      ];
      final names = {for (final b in barbers) b.id: b.name};
      return SalonDetails(
        salon: salon,
        barbers: barbers,
        services: [
          for (final s in results[2] as List<Map<String, dynamic>>)
            ClientService(
              s['name'] as String,
              (s['price'] as num).toDouble(),
              s['duration_minutes'] as int,
            ),
        ],
        stations: [
          for (final c in results[3] as List<Map<String, dynamic>>)
            Station(
              chairNumber: c['chair_number'] as int,
              shopId: shopId,
              status:
                  ChairStatus.values.asNameMap()[c['status']] ??
                  ChairStatus.empty,
              activeBarberId: c['active_barber_id'] as String?,
              activeBarberName: names[c['active_barber_id']],
              serviceStartTime: _time(c['service_start_time']),
            ),
        ],
        posts: [
          for (final p in results[4] as List<Map<String, dynamic>>)
            _post(p, shopName: salon.name),
        ],
      );
    } catch (e) {
      throw cloudException(e);
    }
  }

  @override
  Future<List<ClientPost>> latestPosts({int limit = 30}) async {
    try {
      final rows = await _client
          .from('portfolio_posts')
          .select('$_postColumns, shops(name)')
          .order('created_at', ascending: false)
          .limit(limit);
      return [
        for (final p in rows)
          _post(p, shopName: _embedded(p['shops'])?['name'] as String?),
      ];
    } catch (e) {
      throw cloudException(e);
    }
  }

  @override
  Future<List<ClientComment>> comments(String postId) async {
    try {
      final rows = await _client
          .from('post_comments')
          .select('author_name, body, created_at')
          .eq('post_id', postId)
          .order('created_at');
      return [
        for (final r in rows)
          ClientComment(
            r['author_name'] as String,
            r['body'] as String,
            _time(r['created_at'])!,
          ),
      ];
    } catch (e) {
      throw cloudException(e);
    }
  }

  ClientPost _post(Map<String, dynamic> p, {String? shopName}) => ClientPost(
    id: p['id'] as String,
    shopId: p['shop_id'] as String,
    shopName: shopName,
    barberName: _embedded(p['barbers'])?['name'] as String? ?? '',
    imageUrl: _client.storage
        .from('portfolio')
        .getPublicUrl(p['image_path'] as String),
    caption: p['caption'] as String,
    ratingAvg: (p['rating_avg'] as num).toDouble(),
    ratingCount: p['rating_count'] as int,
    commentCount: p['comment_count'] as int,
    createdAt: _time(p['created_at'])!,
  );

  static ClientSalon _salon(Map<String, dynamic> r) => ClientSalon(
    id: r['id'] as String,
    name: r['name'] as String,
    address: r['address'] as String,
    position: LatLng(
      (r['latitude'] as num).toDouble(),
      (r['longitude'] as num).toDouble(),
    ),
    isOpen: r['is_open'] as bool,
    waitingCount: r['waiting_count'] as int,
    totalChairs: r['total_chairs'] as int,
    established: DateTime.parse(r['created_at'] as String).year,
  );

  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();

  static Map<String, dynamic>? _embedded(Object? value) => switch (value) {
    Map<String, dynamic> m => m,
    [Map<String, dynamic> m, ...] => m,
    _ => null,
  };
}

final clientDirectoryProvider = Provider<ClientDirectory>(
  (ref) => SupabaseClientDirectory(Supabase.instance.client),
);

/// A salon's page, refreshed when reopened or pulled down.
final salonDetailsProvider = FutureProvider.autoDispose
    .family<SalonDetails, String>(
      (ref, shopId) => ref.read(clientDirectoryProvider).salon(shopId),
    );

final latestPostsProvider = FutureProvider.autoDispose<List<ClientPost>>(
  (ref) => ref.read(clientDirectoryProvider).latestPosts(),
);

final clientCommentsProvider = FutureProvider.autoDispose
    .family<List<ClientComment>, String>(
      (ref, postId) => ref.read(clientDirectoryProvider).comments(postId),
    );
