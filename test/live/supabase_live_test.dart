/// End-to-end check against the real Supabase project: sign-up, salon upload
/// and download, and what a signed-out visitor can see. It creates a
/// throwaway account, so it only runs on request:
///
///   flutter test test/live --dart-define=LIVE_SUPABASE=true
///
/// Delete the `live-check-...` user afterwards (Authentication → Users).
library;

import 'package:barber_shop_owner/core/cloud/cloud_auth.dart';
import 'package:barber_shop_owner/core/cloud/cloud_invites.dart';
import 'package:barber_shop_owner/core/cloud/cloud_shop_repository.dart';
import 'package:barber_shop_owner/core/config/supabase_config.dart';
import 'package:barber_shop_owner/core/errors/app_exception.dart';
import 'package:barber_shop_owner/core/sync/supabase_sync_remote.dart';
import 'package:barber_shop_owner/features/auth_onboarding/domain/shop_profile.dart';
import 'package:barber_shop_owner/features/auth_onboarding/domain/shop_snapshot.dart';
import 'package:barber_shop_owner/features/barber_app/barber_link.dart';
import 'package:barber_shop_owner/features/barbers/domain/barber.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const _enabled = bool.fromEnvironment('LIVE_SUPABASE');

SupabaseClient _client() => SupabaseClient(
  SupabaseConfig.url,
  SupabaseConfig.publishableKey,
  // No storage in tests, so no PKCE (the app gets storage from initialize).
  authOptions: const AuthClientOptions(
    autoRefreshToken: false,
    authFlowType: AuthFlowType.implicit,
  ),
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
      final user = await auth.signUp(
        role: AccountRole.owner,
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

        // Sync: device rows go up and come back identical.
        final sync = SupabaseSyncRemote(owner);
        final startedAt = DateTime.now().toIso8601String();
        final queueId = uuid.v4();
        final ticketId = uuid.v4();
        await sync.push('barbers', shopId, barberId, {
          'id': barberId,
          'shop_id': shopId,
          'name': 'Sami B.',
          'phone': '20000002',
          'commission_rate': 0.5,
          'is_on_duty': 1,
          'assigned_chair': 2,
          'created_at': startedAt,
          'is_archived': 0,
        });
        await sync.push('chairs', shopId, '2', {
          'shop_id': shopId,
          'chair_number': 2,
          'status': 'occupied',
          'active_barber_id': barberId,
          'active_client_name': 'Chedi',
          'active_ticket_id': uuid.v4(),
          'service_start_time': startedAt,
        });
        await sync.push('queue', shopId, queueId, {
          'id': queueId,
          'shop_id': shopId,
          'client_name': 'Walk-in',
          'client_phone': null,
          'requested_barber_id': barberId,
          'notes': null,
          'status': 'waiting',
          'created_at': startedAt,
        });
        final ticket = <String, Object?>{
          'id': ticketId,
          'shop_id': shopId,
          'client_name': 'Aziz',
          'client_phone': null,
          'barber_id': barberId,
          'chair_number': 2,
          'service_names': 'Haircut',
          'total_price': 25.5,
          'barber_cut': 12.75,
          'shop_cut': 12.75,
          'tip': 2.0,
          'payment_method': 'cash',
          'timestamp': startedAt,
          'is_completed': 1,
        };
        await sync.push('tickets', shopId, ticketId, ticket);
        await sync.push('tickets', shopId, ticketId, ticket); // idempotent

        final barbers = await sync.pull('barbers', shopId, null);
        expect(barbers.rows.single['phone'], '20000002');
        expect(barbers.rows.single['commission_rate'], 0.5);
        final seats = await sync.pull('chairs', shopId, null);
        final seat = seats.rows.firstWhere((r) => r['chair_number'] == 2);
        expect(seat['active_client_name'], 'Chedi');
        expect(seat['service_start_time'], startedAt);
        final tickets = await sync.pull('tickets', shopId, null);
        expect(tickets.rows.single, ticket);
        final queue = await sync.pull('queue', shopId, null);
        expect(queue.rows.single['client_name'], 'Walk-in');
        expect(queue.cursor, isNotNull);

        await sync.push('queue', shopId, queueId, null);
        final afterDelete = await sync.pull('queue', shopId, queue.cursor);
        expect(afterDelete.deletedKeys, contains(queueId));

        // Invitations (migrations 0003-0004): the owner invites Sami. Before
        // any account, the code shows the salon and his name; then he signs
        // up under that name and joins.
        final invite = await SupabaseCloudInvites(owner)
            .createBarberInvite(barberId);
        expect(invite.code, matches(RegExp(r'^[A-HJ-NP-Z2-9]{8}$')));
        final barberClient = _client();
        final links = SupabaseBarberLinkRepository(barberClient);
        final preview = await links.preview(invite.code.toLowerCase());
        expect(preview?.shopName, 'Live Check Salon');
        expect(preview?.barberName, 'Sami B.');
        expect(await links.preview('WRONG234'), isNull);

        final barberAuth = SupabaseCloudAuth(barberClient);
        final sami = await barberAuth.signUp(
          email: 'live-check-$stamp-barber@barberflow-test.com',
          password: 'Live-check-$stamp',
          fullName: preview!.barberName,
          role: AccountRole.barber,
        );
        final link = await links.join(sami!.id, preview.code);
        expect(link.barberId, barberId);
        expect(link.commissionRate, 0.5);
        await expectLater(
          links.join(sami.id, invite.code),
          throwsA(isA<AppException>()),
        );

        // He asks for another name; it applies once the owner accepts.
        await links.requestNameChange('Samy');
        expect((await links.myLink(sami.id))?.barberName, 'Sami B.');
        await SupabaseCloudInvites(owner)
            .answerNameChange(barberId, accept: true);
        expect((await links.myLink(sami.id))?.barberName, 'Samy');

        // He leaves: his account stays, the salon is no longer his.
        await links.leave();
        expect(await links.myLink(sami.id), isNull);
        expect(
          await barberClient.from('tickets').select().eq('shop_id', shopId),
          isEmpty,
        );
        await barberAuth.signOut();

        // Not listed yet, and private data never leaves the salon.
        expect(await visitor.from('shops').select().eq('id', shopId), isEmpty);
        expect(
          await visitor
              .from('barber_private')
              .select()
              .eq('barber_id', barberId),
          isEmpty,
        );
        expect(
          await visitor.from('chair_clients').select().eq('shop_id', shopId),
          isEmpty,
        );

        // Placed on the map and listed: visitors see the salon and its
        // floor, still never who is sitting in the chairs.
        await sync.push('shops', shopId, shopId, {
          'name': 'Live Check Salon',
          'address': 'Tunis',
          'phone': '71000000',
          'total_chairs': 3,
          'latitude': 36.8008,
          'longitude': 10.18,
          'is_open': 1,
          'is_listed': 1,
        });
        final pulledShop = await sync.pull('shops', shopId, null);
        expect(pulledShop.rows.single['is_listed'], 1);
        expect(pulledShop.rows.single['latitude'], 36.8008);
        final listed = await visitor
            .from('shops')
            .select('name, latitude, longitude, is_open')
            .eq('id', shopId);
        expect(listed.single['name'], 'Live Check Salon');
        expect(
          await visitor.from('chairs').select().eq('shop_id', shopId),
          hasLength(3),
        );
        expect(
          await visitor.from('chair_clients').select().eq('shop_id', shopId),
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
