import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/cloud/cloud_errors.dart';
import '../../core/errors/app_exception.dart';

/// A barber account's place in a salon: the roster entry it is linked to.
class BarberLink {
  const BarberLink({
    required this.barberId,
    required this.barberName,
    required this.shopId,
    required this.shopName,
    required this.commissionRate,
    required this.isOnDuty,
    this.assignedChair,
  });

  final String barberId;
  final String barberName;
  final String shopId;
  final String shopName;
  final double commissionRate;
  final bool isOnDuty;
  final int? assignedChair;
}

/// Server access for barber accounts. Failures are thrown as [AppException].
abstract class BarberLinkRepository {
  /// The salon this account is linked to, or null before joining one.
  Future<BarberLink?> myLink(String userId);

  /// Links this account with an invitation code from the salon owner.
  Future<BarberLink> join(String userId, String code);
}

class SupabaseBarberLinkRepository implements BarberLinkRepository {
  SupabaseBarberLinkRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<BarberLink?> myLink(String userId) async {
    try {
      final row = await _client
          .from('barbers')
          .select(
            'id, name, shop_id, assigned_chair, is_on_duty, '
            'shops(name), barber_private(commission_rate)',
          )
          .eq('profile_id', userId)
          .eq('is_archived', false)
          .maybeSingle();
      if (row == null) return null;
      final shop = _embedded(row['shops']);
      final private = _embedded(row['barber_private']);
      return BarberLink(
        barberId: row['id'] as String,
        barberName: row['name'] as String,
        shopId: row['shop_id'] as String,
        shopName: shop?['name'] as String? ?? '',
        commissionRate: (private?['commission_rate'] as num?)?.toDouble() ?? 0,
        isOnDuty: row['is_on_duty'] as bool,
        assignedChair: row['assigned_chair'] as int?,
      );
    } catch (e) {
      throw cloudException(e);
    }
  }

  @override
  Future<BarberLink> join(String userId, String code) async {
    final cleaned = code.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    if (cleaned.length != 8) {
      throw const AppException('The code has 8 characters.');
    }
    try {
      await _client.rpc<dynamic>(
        'join_with_invite',
        params: {'p_code': cleaned},
      );
    } catch (e) {
      throw cloudException(e);
    }
    final link = await myLink(userId);
    if (link == null) {
      throw const AppException('Could not join the salon. Please try again.');
    }
    return link;
  }

  /// One-to-one / many-to-one embeds come back as an object (older servers:
  /// a list).
  static Map<String, dynamic>? _embedded(Object? value) => switch (value) {
    Map<String, dynamic> m => m,
    [Map<String, dynamic> m, ...] => m,
    _ => null,
  };
}
