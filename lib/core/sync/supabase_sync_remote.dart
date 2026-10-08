import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/cloud_errors.dart';
import 'sync_remote.dart';

/// [SyncRemote] on Supabase. Translates between the local SQLite rows and
/// the server tables (see `supabase/migrations`), where some data is split
/// into private side tables and values have stricter types.
class SupabaseSyncRemote implements SyncRemote {
  SupabaseSyncRemote(this._client);

  final SupabaseClient _client;

  static const _pageSize = 500;

  /// Changes are fetched again for this long after the last one seen, so a
  /// slow write that committed late is not missed. Re-applying is harmless.
  static const _overlap = Duration(seconds: 60);

  // ---------------------------------------------------------------------------
  // Push
  // ---------------------------------------------------------------------------

  @override
  Future<void> push(
    String entity,
    String shopId,
    String key,
    Map<String, Object?>? row,
  ) async {
    try {
      switch (entity) {
        case 'shops':
          if (row != null) await _pushShop(shopId, row);
        case 'barbers':
          if (row != null) await _pushBarber(shopId, key, row);
        case 'services':
          await _pushService(shopId, key, row);
        case 'chairs':
          if (row != null) await _pushChair(shopId, int.parse(key), row);
        case 'queue':
          await _pushQueue(shopId, key, row);
        case 'tickets':
          if (row != null) await _pushTicket(shopId, row);
      }
    } on SyncRejected {
      rethrow;
    } catch (e) {
      if (isNetworkError(e)) throw const SyncOffline();
      if (e is PostgrestException) {
        throw SyncRejected('${e.code ?? ''} ${e.message}'.trim());
      }
      throw SyncRejected(e.toString());
    }
  }

  Future<void> _pushShop(String shopId, Map<String, Object?> row) => _client
      .from('shops')
      .update({
        'name': _clip(row['name'], 60),
        'address': _clip(row['address'], 160),
        'phone': _clip(row['phone'], 30),
        'total_chairs': row['total_chairs'],
        'latitude': row['latitude'],
        'longitude': row['longitude'],
        'is_open': _bool(row['is_open']),
        'is_listed': _bool(row['is_listed']),
      })
      .eq('id', shopId);

  Future<void> _pushBarber(
    String shopId,
    String id,
    Map<String, Object?> row,
  ) async {
    final mutable = {
      'name': _clip(row['name'], 60),
      'is_on_duty': _bool(row['is_on_duty']),
      'assigned_chair': row['assigned_chair'],
      'is_archived': _bool(row['is_archived']),
    };
    // Insert if new, then update: existing rows only accept these columns.
    await _client.from('barbers').upsert({
      'id': id,
      'shop_id': shopId,
      'created_at': _serverTime(row['created_at']),
      ...mutable,
    }, ignoreDuplicates: true);
    await _client.from('barbers').update(mutable).eq('id', id);
    await _client.from('barber_private').upsert({
      'barber_id': id,
      'phone': _clip(row['phone'], 30),
      'commission_rate': row['commission_rate'],
    });
  }

  Future<void> _pushService(
    String shopId,
    String id,
    Map<String, Object?>? row,
  ) async {
    if (row == null) {
      await _client
          .from('services')
          .delete()
          .eq('id', id)
          .eq('shop_id', shopId);
      return;
    }
    await _client.from('services').upsert({
      'id': id,
      'shop_id': shopId,
      'name': _clip(row['name'], 60),
      'price': row['price'],
      'duration_minutes': row['duration_minutes'],
    });
  }

  Future<void> _pushChair(
    String shopId,
    int number,
    Map<String, Object?> row,
  ) async {
    final updated = await _client
        .from('chairs')
        .update({
          'status': row['status'],
          'active_barber_id': row['active_barber_id'],
          'active_ticket_id': row['active_ticket_id'],
          'service_start_time': _serverTime(row['service_start_time']),
        })
        .eq('shop_id', shopId)
        .eq('chair_number', number)
        .select('chair_number');
    if (updated.isEmpty) {
      // The salon's new chair count has not reached the server yet.
      throw SyncRejected('Chair #$number is not on the server yet.');
    }

    final client = row['active_client_name'] as String?;
    final seat = _client.from('chair_clients');
    if (client == null) {
      await seat.delete().eq('shop_id', shopId).eq('chair_number', number);
    } else {
      await seat.upsert({
        'shop_id': shopId,
        'chair_number': number,
        'client_name': _clip(client, 80),
      });
    }
  }

  Future<void> _pushQueue(
    String shopId,
    String id,
    Map<String, Object?>? row,
  ) async {
    final table = _client.from('queue');
    if (row == null) {
      await table.delete().eq('id', id).eq('shop_id', shopId);
      return;
    }
    final mutable = {
      'client_name': _clip(row['client_name'], 80),
      'client_phone': _clip(row['client_phone'], 30),
      'requested_barber_id': row['requested_barber_id'],
      'notes': _clip(row['notes'], 200),
      'status': row['status'],
    };
    await table.upsert({
      'id': id,
      'shop_id': shopId,
      'created_at': _serverTime(row['created_at']),
      ...mutable,
    }, ignoreDuplicates: true);
    await _client.from('queue').update(mutable).eq('id', id);
  }

  /// Tickets never change once written.
  Future<void> _pushTicket(String shopId, Map<String, Object?> row) =>
      _client.from('tickets').upsert({
        'id': row['id'],
        'shop_id': shopId,
        'barber_id': row['barber_id'],
        'client_name': _clip(row['client_name'], 80),
        'client_phone': _clip(row['client_phone'], 30),
        'chair_number': row['chair_number'],
        'service_names': row['service_names'],
        'total_price': row['total_price'],
        'barber_cut': row['barber_cut'],
        'shop_cut': row['shop_cut'],
        'tip': row['tip'],
        'payment_method': row['payment_method'],
        'is_completed': _bool(row['is_completed']),
        'created_at': _serverTime(row['timestamp']),
      }, ignoreDuplicates: true);

  // ---------------------------------------------------------------------------
  // Pull
  // ---------------------------------------------------------------------------

  @override
  Future<RemoteChanges> pull(
    String entity,
    String shopId,
    DateTime? since,
  ) async {
    final after = since?.subtract(_overlap);
    try {
      return switch (entity) {
        'shops' => _changes(
          await _fetch(
            'shops',
            'id, name, address, phone, total_chairs, latitude, longitude, '
                'is_open, is_listed, updated_at',
            'id',
            shopId,
            after,
          ),
          since,
          (r) => {
            'id': r['id'],
            'name': r['name'],
            'address': r['address'],
            'phone': r['phone'],
            'total_chairs': r['total_chairs'],
            'latitude': r['latitude'],
            'longitude': r['longitude'],
            'is_open': _int(r['is_open']),
            'is_listed': _int(r['is_listed']),
          },
        ),
        'barbers' => _changes(
          await _fetch(
            'barbers',
            'id, shop_id, profile_id, name, requested_name, is_on_duty, '
                'assigned_chair, '
                'is_archived, '
                'created_at, updated_at, barber_private(phone, commission_rate)',
            'shop_id',
            shopId,
            after,
          ),
          since,
          _localBarber,
        ),
        'services' => _changes(
          await _fetch(
            'services',
            'id, shop_id, name, price, duration_minutes, updated_at',
            'shop_id',
            shopId,
            after,
          ),
          since,
          (r) => {
            'id': r['id'],
            'shop_id': r['shop_id'],
            'name': r['name'],
            'price': r['price'],
            'duration_minutes': r['duration_minutes'],
          },
          deletions: await _deletions('services', shopId, after),
        ),
        'chairs' => _changes(
          await _fetch(
            'chairs',
            'shop_id, chair_number, status, active_barber_id, '
                'active_ticket_id, service_start_time, updated_at, '
                'chair_clients(client_name)',
            'shop_id',
            shopId,
            after,
            tieBreak: 'chair_number',
          ),
          since,
          _localChair,
        ),
        'queue' => _changes(
          await _fetch(
            'queue',
            'id, shop_id, client_name, client_phone, requested_barber_id, '
                'notes, status, created_at, updated_at',
            'shop_id',
            shopId,
            after,
          ),
          since,
          (r) => {
            'id': r['id'],
            'shop_id': r['shop_id'],
            'client_name': r['client_name'],
            'client_phone': r['client_phone'],
            'requested_barber_id': r['requested_barber_id'],
            'notes': r['notes'],
            'status': r['status'],
            'created_at': _localTime(r['created_at']),
          },
          deletions: await _deletions('queue', shopId, after),
        ),
        'tickets' => _changes(
          await _fetch(
            'tickets',
            'id, shop_id, barber_id, client_name, client_phone, chair_number, '
                'service_names, total_price, barber_cut, shop_cut, tip, '
                'payment_method, is_completed, created_at, updated_at',
            'shop_id',
            shopId,
            after,
          ),
          since,
          _localTicket,
        ),
        _ => throw ArgumentError.value(entity, 'entity'),
      };
    } catch (e) {
      if (isNetworkError(e)) throw const SyncOffline();
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetch(
    String table,
    String columns,
    String shopColumn,
    String shopId,
    DateTime? after, {
    String tieBreak = 'id',
  }) async {
    final rows = <Map<String, dynamic>>[];
    for (var from = 0; ; from += _pageSize) {
      var query = _client.from(table).select(columns).eq(shopColumn, shopId);
      if (after != null) {
        query = query.gt('updated_at', after.toUtc().toIso8601String());
      }
      final page = await query
          .order('updated_at', ascending: true)
          .order(tieBreak, ascending: true)
          .range(from, from + _pageSize - 1);
      rows.addAll(page);
      if (page.length < _pageSize) return rows;
    }
  }

  Future<List<Map<String, dynamic>>> _deletions(
    String table,
    String shopId,
    DateTime? after,
  ) async {
    var query = _client
        .from('sync_deletions')
        .select('row_id, deleted_at')
        .eq('shop_id', shopId)
        .eq('table_name', table);
    if (after != null) {
      query = query.gt('deleted_at', after.toUtc().toIso8601String());
    }
    return query.order('deleted_at', ascending: true);
  }

  static RemoteChanges _changes(
    List<Map<String, dynamic>> rows,
    DateTime? since,
    Map<String, Object?> Function(Map<String, dynamic>) toLocal, {
    List<Map<String, dynamic>> deletions = const [],
  }) {
    var cursor = since;
    void see(Object? time) {
      if (time == null) return;
      final t = DateTime.parse(time as String);
      if (cursor == null || t.isAfter(cursor!)) cursor = t;
    }

    for (final r in rows) {
      see(r['updated_at']);
    }
    for (final d in deletions) {
      see(d['deleted_at']);
    }
    return RemoteChanges(
      rows: rows.map(toLocal).toList(),
      deletedKeys: [for (final d in deletions) d['row_id'] as String],
      cursor: cursor,
    );
  }

  static Map<String, Object?> _localBarber(Map<String, dynamic> r) {
    final private = _embedded(r['barber_private']);
    return {
      'id': r['id'],
      'shop_id': r['shop_id'],
      'name': r['name'],
      'phone': private?['phone'] ?? '',
      'commission_rate': private?['commission_rate'] ?? 0.6,
      'is_on_duty': _int(r['is_on_duty']),
      'assigned_chair': r['assigned_chair'],
      'created_at': _localTime(r['created_at']),
      'is_archived': _int(r['is_archived']),
      'profile_id': r['profile_id'],
      'requested_name': r['requested_name'],
    };
  }

  static Map<String, Object?> _localChair(Map<String, dynamic> r) => {
    'shop_id': r['shop_id'],
    'chair_number': r['chair_number'],
    'status': r['status'],
    'active_barber_id': r['active_barber_id'],
    'active_client_name': _embedded(r['chair_clients'])?['client_name'],
    'active_ticket_id': r['active_ticket_id'],
    'service_start_time': _localTime(r['service_start_time']),
  };

  static Map<String, Object?> _localTicket(Map<String, dynamic> r) => {
    'id': r['id'],
    'shop_id': r['shop_id'],
    'client_name': r['client_name'],
    'client_phone': r['client_phone'],
    'barber_id': r['barber_id'],
    'chair_number': r['chair_number'],
    'service_names': r['service_names'],
    'total_price': r['total_price'],
    'barber_cut': r['barber_cut'],
    'shop_cut': r['shop_cut'],
    'tip': r['tip'],
    'payment_method': r['payment_method'],
    'timestamp': _localTime(r['created_at']),
    'is_completed': _int(r['is_completed']),
  };

  // ---------------------------------------------------------------------------
  // Value conversions
  // ---------------------------------------------------------------------------

  /// One-to-one embeds come back as an object (older servers: a list).
  static Map<String, dynamic>? _embedded(Object? value) => switch (value) {
    Map<String, dynamic> m => m,
    [Map<String, dynamic> m, ...] => m,
    _ => null,
  };

  /// Local times are ISO strings without offset, in the device's time zone.
  static String? _serverTime(Object? local) => local == null
      ? null
      : DateTime.parse(local as String).toUtc().toIso8601String();

  static String? _localTime(Object? server) => server == null
      ? null
      : DateTime.parse(server as String).toLocal().toIso8601String();

  static bool _bool(Object? value) => value == 1 || value == true;

  static int _int(Object? value) => value == true ? 1 : 0;

  static String? _clip(Object? value, int max) {
    final text = value as String?;
    return text == null || text.length <= max ? text : text.substring(0, max);
  }
}
