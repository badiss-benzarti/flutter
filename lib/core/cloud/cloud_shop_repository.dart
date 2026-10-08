import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart';
import '../../features/auth_onboarding/domain/shop_profile.dart';
import '../../features/auth_onboarding/domain/shop_snapshot.dart';
import '../../features/barbers/domain/barber.dart';
import 'cloud_errors.dart';

/// Copies a salon's setup to and from the cloud. Failures are thrown as
/// [AppException] with a user-facing message.
abstract class CloudShopRepository {
  /// The salon owned by [ownerId], or null if they have not created one yet.
  Future<ShopSnapshot?> fetchOwnedShop(String ownerId);

  /// Creates the salon on the server with the same ids as on this device.
  /// Nothing is left behind on the server if it fails.
  Future<void> uploadShop(ShopSnapshot snapshot);
}

class SupabaseCloudShopRepository implements CloudShopRepository {
  SupabaseCloudShopRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ShopSnapshot?> fetchOwnedShop(String ownerId) async {
    try {
      final shopRow = await _client
          .from('shops')
          .select(
            'id, owner_id, name, address, phone, total_chairs, created_at, '
            'latitude, longitude, is_open, is_listed',
          )
          .eq('owner_id', ownerId)
          .order('created_at')
          .limit(1)
          .maybeSingle();
      if (shopRow == null) return null;
      final shopId = shopRow['id'] as String;

      final serviceRows = await _client
          .from('services')
          .select('id, shop_id, name, price, duration_minutes')
          .eq('shop_id', shopId);
      final barberRows = await _client
          .from('barbers')
          .select(
            'id, shop_id, profile_id, name, is_on_duty, assigned_chair, '
            'is_archived, '
            'created_at, barber_private(phone, commission_rate)',
          )
          .eq('shop_id', shopId)
          .order('created_at');

      return ShopSnapshot(
        shop: ShopProfile.fromMap(
          shopRow,
          services: serviceRows.map(ServiceItem.fromMap).toList(),
        ),
        barbers: barberRows.map(_barberFromRow).toList(),
      );
    } catch (e) {
      throw cloudException(e);
    }
  }

  @override
  Future<void> uploadShop(ShopSnapshot snapshot) async {
    final shop = snapshot.shop;
    try {
      // Chairs and the invite code are created by a trigger.
      await _client.from('shops').insert({
        'id': shop.id,
        'owner_id': shop.ownerId,
        'name': shop.name,
        'address': shop.address,
        'phone': shop.phone,
        'total_chairs': shop.totalChairs,
        'created_at': shop.createdAt.toUtc().toIso8601String(),
        'latitude': shop.latitude,
        'longitude': shop.longitude,
        'is_open': shop.isOpen,
        'is_listed': shop.isListed && shop.hasLocation,
      });
    } catch (e) {
      throw cloudException(e);
    }

    try {
      if (snapshot.barbers.isNotEmpty) {
        await _client.from('barbers').insert([
          for (final b in snapshot.barbers)
            {
              'id': b.id,
              'shop_id': shop.id,
              'name': b.name,
              'is_on_duty': b.isOnDuty,
              'assigned_chair': b.assignedChair,
              'is_archived': b.isArchived,
              'created_at': b.createdAt.toUtc().toIso8601String(),
            },
        ]);
        await _client.from('barber_private').insert([
          for (final b in snapshot.barbers)
            {
              'barber_id': b.id,
              'phone': b.phone,
              'commission_rate': b.commissionRate,
            },
        ]);
      }
      if (shop.services.isNotEmpty) {
        await _client.from('services').insert([
          for (final s in shop.services)
            {
              'id': s.id,
              'shop_id': shop.id,
              'name': s.name,
              'price': s.price,
              'duration_minutes': s.durationMinutes,
            },
        ]);
      }
      // Barbers sitting at their chair, as on the local floor.
      for (final b in snapshot.barbers) {
        final chair = b.assignedChair;
        if (chair == null || b.isArchived) continue;
        await _client
            .from('chairs')
            .update({'status': 'available', 'active_barber_id': b.id})
            .eq('shop_id', shop.id)
            .eq('chair_number', chair);
      }
    } catch (e) {
      // Deleting the salon removes everything created above with it.
      try {
        await _client.from('shops').delete().eq('id', shop.id);
      } catch (_) {}
      throw cloudException(e);
    }
  }

  static Barber _barberFromRow(Map<String, dynamic> row) {
    // One-to-one embeds come back as an object (older servers: a list).
    final embed = row['barber_private'];
    final private = switch (embed) {
      Map<String, dynamic> m => m,
      [Map<String, dynamic> m, ...] => m,
      _ => const <String, dynamic>{},
    };
    return Barber(
      id: row['id'] as String,
      shopId: row['shop_id'] as String,
      name: row['name'] as String,
      phone: private['phone'] as String? ?? '',
      commissionRate: (private['commission_rate'] as num?)?.toDouble() ?? 0.6,
      isOnDuty: row['is_on_duty'] as bool,
      assignedChair: row['assigned_chair'] as int?,
      createdAt: DateTime.parse(row['created_at'] as String),
      isArchived: row['is_archived'] as bool,
      profileId: row['profile_id'] as String?,
    );
  }
}
