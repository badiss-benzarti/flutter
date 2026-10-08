import 'package:barber_shop_owner/core/cloud/cloud_auth.dart';
import 'package:barber_shop_owner/core/errors/app_exception.dart';
import 'package:barber_shop_owner/core/providers/cloud_providers.dart';
import 'package:barber_shop_owner/core/sync/sync_engine.dart';
import 'package:barber_shop_owner/features/barber_app/barber_link.dart';
import 'package:barber_shop_owner/features/barber_app/barber_session.dart';
import 'package:barber_shop_owner/features/barbers/domain/barber.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_cloud_auth.dart';
import '../helpers/fake_sync_server.dart';
import '../helpers/test_database.dart';

/// Stand-in for the server's invitation codes and barber roster.
class FakeBarberLinks implements BarberLinkRepository {
  final codes = <String, BarberLink>{};
  final linked = <String, BarberLink>{};

  @override
  Future<BarberLink?> myLink(String userId) async => linked[userId];

  @override
  Future<BarberLink> join(String userId, String code) async {
    if (linked.containsKey(userId)) {
      throw const AppException('Your account is already linked to a salon.');
    }
    final link = codes.remove(code.trim().toUpperCase());
    if (link == null) {
      throw const AppException('This code is not valid or has expired.');
    }
    return linked[userId] = link;
  }
}

const _sami = BarberLink(
  barberId: 'b1',
  barberName: 'Sami',
  shopId: 's1',
  shopName: 'Blade & Crown',
  commissionRate: 0.6,
  isOnDuty: true,
  assignedChair: 1,
);

void main() {
  late FakeCloudAuth auth;
  late FakeBarberLinks links;

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        cloudAuthProvider.overrideWithValue(auth),
        barberLinkRepositoryProvider.overrideWithValue(links),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    auth = FakeCloudAuth();
    links = FakeBarberLinks()..codes['ABCD2345'] = _sami;
  });

  test('a barber signs up, then joins with the code from the owner', () async {
    final c = container();
    final session = c.read(barberSessionProvider.notifier);

    expect(
      await session.register(
        email: 'Sami@Test.tn',
        password: 'password123',
        fullName: 'Sami',
      ),
      isTrue,
    );
    var state = c.read(barberSessionProvider);
    expect(state.user?.role, AccountRole.barber);
    expect(state.link, isNull);

    expect(await session.join('WRONG234'), isFalse);
    expect(c.read(barberSessionProvider).errorMessage, contains('not valid'));

    expect(await session.join(' abcd2345 '), isTrue);
    state = c.read(barberSessionProvider);
    expect(state.link?.shopName, 'Blade & Crown');
    expect(state.errorMessage, isNull);

    // The code was used up.
    expect(links.codes, isEmpty);
  });

  test('reopening the app finds the salon again', () async {
    final first = container();
    await first
        .read(barberSessionProvider.notifier)
        .register(
          email: 'sami@test.tn',
          password: 'password123',
          fullName: 'S',
        );
    await first.read(barberSessionProvider.notifier).join('ABCD2345');

    final reopened = container();
    expect(reopened.read(barberSessionProvider).isLoading, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(reopened.read(barberSessionProvider).link?.barberName, 'Sami');
  });

  test('an owner account cannot sign in as a barber', () async {
    await auth.signUp(
      email: 'owner@test.tn',
      password: 'password123',
      fullName: 'Olfa',
      role: AccountRole.owner,
    );
    auth.currentUser = null;

    final c = container();
    expect(
      await c
          .read(barberSessionProvider.notifier)
          .login(email: 'owner@test.tn', password: 'password123'),
      isFalse,
    );
    expect(c.read(barberSessionProvider).isSignedIn, isFalse);
    expect(
      c.read(barberSessionProvider).errorMessage,
      contains('not a barber account'),
    );
    expect(auth.currentUser, isNull);
  });

  test('signing out returns to the barber sign-in', () async {
    final c = container();
    await c
        .read(barberSessionProvider.notifier)
        .register(
          email: 'sami@test.tn',
          password: 'password123',
          fullName: 'S',
        );
    await c.read(barberSessionProvider.notifier).logout();
    expect(c.read(barberSessionProvider).isSignedIn, isFalse);
    expect(auth.currentUser, isNull);
  });

  test("the owner's phone learns that a barber joined", () async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);
    const ownerId = '00000000-0000-4000-8000-000000000001';
    await env.shops.signInCloudOwner(
      id: ownerId,
      email: 'owner@test.tn',
      fullName: 'Olfa',
    );
    final barber = Barber(
      id: 'b0000000-0000-4000-8000-000000000001',
      shopId: '',
      name: 'Sami',
      phone: '20000001',
      commissionRate: 0.6,
      createdAt: DateTime(2026),
    );
    final shop = await env.shops.setupShopProfile(
      ownerId: ownerId,
      name: 'Blade',
      address: 'Tunis',
      phone: '71000000',
      totalChairs: 4,
      initialBarbers: [barber],
      services: const [],
    );
    expect((await env.barbers.getBarbers(shop.id)).single.isLinkedToApp, false);

    // The salon reached the server; then the server links Sami's account
    // (join_with_invite).
    final server = FakeServer();
    final engine = SyncEngine(dbService: env.db, remote: server);
    await engine.push(shop.id);
    server.serverWrite('barbers', barber.id, {
      ...barber.copyWith(shopId: shop.id).toMap(),
      'profile_id': '00000000-0000-4000-8000-0000000000b1',
    });
    await engine.pull(shop.id);

    expect((await env.barbers.getBarbers(shop.id)).single.isLinkedToApp, true);
  });
}
