/// End-to-end check against the real Supabase project: sign-up, salon upload
/// and download, and what a signed-out visitor can see. It creates a
/// throwaway account, so it only runs on request:
///
///   flutter test test/live --dart-define=LIVE_SUPABASE=true
///
/// Delete the `live-check-...` user afterwards (Authentication → Users).
library;

import 'package:barber_shop_owner/core/cloud/cloud_auth.dart';
import 'package:barber_shop_owner/core/cloud/cloud_shop_repository.dart';
import 'package:barber_shop_owner/core/config/supabase_config.dart';
import 'package:barber_shop_owner/features/auth_onboarding/domain/shop_profile.dart';
import 'package:barber_shop_owner/features/auth_onboarding/domain/shop_snapshot.dart';
import 'package:barber_shop_owner/features/barbers/domain/barber.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const _enabled = bool.fromEnvironment('LIVE_SUPABASE');

SupabaseClient _client() => SupabaseClient(
  SupabaseConfig.url,
  SupabaseConfig.publishableKey,
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

void main() {
  test(
    'salon round trip on the live project',
    () async {
      final owner = _client();
      final visitor = _client();
      final auth = SupabaseCloudAuth(owner);
      final shops = SupabaseCloudShopRepository(owner);
      const uuid = Uuid();

      final stamp = DateTime.now().millisecondsSinceEpoch;
      final user = await auth.signUpOwner(
        email: 'live-check-$stamp@barberflow-test.com',
        password: 'Live-check-$stamp',
        fullName: 'Live Check',
      );
      expect(
        user,
        isNotNull,
        reason: 'Turn off "Confirm email" to run this check.',
      );

      final shopId = uuid.v4();
      final barberId = uuid.v4();
      final snapshot = ShopSnapshot(
        shop: ShopProfile(
          id: shopId,
          ownerId: user!.id,
          name: 'Live Check Salon',
          address: 'Tunis',
          phone: '71000000',
          totalChairs: 3,
          createdAt: DateTime.now(),
          services: [
            ServiceItem(
              id: uuid.v4(),
              shopId: shopId,
              name: 'Haircut',
              price: 25,
            ),
          ],
        ),
        barbers: [
          Barber(
            id: barberId,
            shopId: shopId,
            name: 'Sami',
            phone: '20000001',
            commissionRate: 0.6,
            assignedChair: 2,
            createdAt: DateTime.now(),
          ),
        ],
      );

      try {
        await shops.uploadShop(snapshot);

        final back = await shops.fetchOwnedShop(user.id);
        expect(back?.shop.id, shopId);
        expect(back!.shop.totalChairs, 3);
        expect(back.shop.services.single.price, 25);
        expect(back.barbers.single.phone, '20000001');
        expect(back.barbers.single.commissionRate, 0.6);

        final chairs = await owner
            .from('chairs')
            .select('chair_number, status, active_barber_id')
            .eq('shop_id', shopId)
            .order('chair_number');
        expect(chairs.length, 3);
        expect(chairs[1]['active_barber_id'], barberId);
        expect(
          await owner.from('shop_invites').select().eq('shop_id', shopId),
          hasLength(1),
        );

        // Not listed yet, and private data never leaves the salon.
        expect(await visitor.from('shops').select().eq('id', shopId), isEmpty);
        expect(
          await visitor
              .from('barber_private')
              .select()
              .eq('barber_id', barberId),
          isEmpty,
        );
      } finally {
        await owner.from('shops').delete().eq('id', shopId);
        await auth.signOut();
      }
    },
    skip: _enabled
        ? false
        : 'Live check: pass --dart-define=LIVE_SUPABASE=true',
  );
}
