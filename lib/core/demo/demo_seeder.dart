import 'dart:math';

import 'package:uuid/uuid.dart';

import '../database/database_service.dart';
import '../repositories/floor_plan_repository.dart';
import '../repositories/queue_repository.dart';
import '../repositories/shop_repository.dart';
import '../../features/auth_onboarding/domain/shop_profile.dart';
import '../../features/barbers/domain/barber.dart';
import '../../features/finance/domain/service_ticket.dart';

/// Creates a demo owner account with a fully populated shop: barbers,
/// services, a month of sales history, services in progress and clients
/// waiting. Used by the "Explore the demo shop" button (on this device only)
/// and to seed the public demo salon on the server.
class DemoSeeder {
  DemoSeeder({
    required this._dbService,
    required this._shops,
    required this._floor,
    required this._queue,
  });

  final DatabaseService _dbService;
  final ShopRepository _shops;
  final FloorPlanRepository _floor;
  final QueueRepository _queue;
  final _uuid = const Uuid();

  static const String email = 'demo@barbershop.app';
  static const String password = 'Demo2026!';

  static const _historyDays = 30;

  static const _clients = [
    ('Omar Ben Ali', '+216 22 145 870'),
    ('Mehdi Trabelsi', '+216 55 301 442'),
    ('Aziz Gharbi', '+216 98 774 120'),
    ('Yassine Jlassi', null),
    ('Hamza Chaabane', '+216 23 889 016'),
    ('Firas Mansour', null),
    ('Anis Khelifi', '+216 52 610 339'),
    ('Skander Bouazizi', '+216 97 452 781'),
    ('Rami Hammami', null),
    ('Walid Ayari', '+216 21 507 964'),
    ('Nizar Sassi', null),
    ('Bilel Mejri', '+216 29 336 105'),
    ('Karim Dridi', '+216 94 218 670'),
    ('Seif Riahi', null),
    ('Malek Zouari', '+216 50 993 214'),
    ('Adam Belhadj', null),
  ];

  /// Creates the demo account if it does not exist yet. Safe to call
  /// repeatedly.
  Future<void> ensureDemoAccount() async {
    final db = await _dbService.database;
    final existing = await db.query(
      'owners',
      columns: ['id'],
      where: 'email = ?',
      whereArgs: [email],
    );
    if (existing.isNotEmpty) return;

    final owner = await _shops.registerOwner(
      email: email,
      password: password,
      fullName: 'Demo Owner',
    );
    await populateShop(owner.id);
  }

  /// Creates the demo salon for [ownerId] and fills it: team, prices, a
  /// month of sales, two cuts in progress and three clients waiting.
  Future<ShopProfile> populateShop(String ownerId) async {
    final db = await _dbService.database;
    final now = DateTime.now();
    Barber barber(String name, String phone, double rate, int? chair) => Barber(
      id: _uuid.v4(),
      shopId: '',
      name: name,
      phone: phone,
      commissionRate: rate,
      assignedChair: chair,
      createdAt: now,
    );

    final team = [
      barber('Sami', '+216 20 111 222', 0.60, 1),
      barber('Karim', '+216 20 333 444', 0.55, 3),
      barber('Youssef', '+216 20 555 666', 0.50, 6),
      barber('Nour', '+216 20 777 888', 0.60, 7),
      barber('Ali', '+216 20 999 000', 0.50, null),
    ];

    final shop = await _shops.setupShopProfile(
      ownerId: ownerId,
      name: 'Blade & Crown',
      address: 'Avenue Habib Bourguiba, Tunis',
      phone: '+216 71 234 567',
      totalChairs: 8,
      initialBarbers: team,
      // Avenue Habib Bourguiba, Tunis.
      latitude: 36.8008,
      longitude: 10.1800,
      services: const [
        ServiceItem(id: '', shopId: '', name: 'Haircut', price: 25),
        ServiceItem(
          id: '',
          shopId: '',
          name: 'Beard Trim',
          price: 15,
          durationMinutes: 20,
        ),
        ServiceItem(
          id: '',
          shopId: '',
          name: 'Haircut + Beard',
          price: 35,
          durationMinutes: 45,
        ),
        ServiceItem(
          id: '',
          shopId: '',
          name: 'Kids Haircut',
          price: 20,
          durationMinutes: 25,
        ),
        ServiceItem(
          id: '',
          shopId: '',
          name: 'Hot Towel Shave',
          price: 18,
          durationMinutes: 25,
        ),
        ServiceItem(
          id: '',
          shopId: '',
          name: 'Hair Wash',
          price: 10,
          durationMinutes: 10,
        ),
      ],
    );

    // Ali is on the roster but off duty today.
    await db.update(
      'barbers',
      {'is_on_duty': 0},
      where: 'id = ?',
      whereArgs: [team.last.id],
    );

    await _insertHistory(shop, team.take(4).toList(), now);
    await _setLiveFloor(shop.id, now);
    return shop;
  }

  /// A month of completed sales, deterministic so the demo looks the same
  /// on every device.
  Future<void> _insertHistory(
    ShopProfile shop,
    List<Barber> barbers,
    DateTime now,
  ) async {
    final random = Random(2026);
    final services = shop.services;
    final db = await _dbService.database;
    final batch = db.batch();
    final today = DateTime(now.year, now.month, now.day);

    for (var dayOffset = _historyDays; dayOffset >= 0; dayOffset--) {
      final day = today.subtract(Duration(days: dayOffset));
      final isWeekend = day.weekday >= DateTime.friday;
      final count = (isWeekend ? 11 : 6) + random.nextInt(6);

      for (var i = 0; i < count; i++) {
        final minutes = 9 * 60 + random.nextInt(10 * 60);
        final time = day.add(Duration(minutes: minutes));
        if (!time.isBefore(now.subtract(const Duration(minutes: 30)))) {
          continue; // Nothing in the future for today.
        }

        final barber = barbers[random.nextInt(barbers.length)];
        final chair = barber.assignedChair ?? 2;
        final picked = <ServiceItem>{services[random.nextInt(services.length)]};
        if (random.nextDouble() < 0.3) {
          picked.add(services[random.nextInt(services.length)]);
        }
        final subtotal = picked.fold<double>(0, (s, e) => s + e.price);
        final barberCut = FloorPlanRepository.roundMoney(
          subtotal * barber.commissionRate,
        );
        final tipRoll = random.nextDouble();
        final tip = tipRoll < 0.55
            ? 0.0
            : FloorPlanRepository.roundMoney(
                subtotal * (tipRoll < 0.85 ? 0.10 : 0.15),
              );
        final payRoll = random.nextDouble();
        final client = _clients[random.nextInt(_clients.length)];

        batch.insert(
          'tickets',
          ServiceTicket(
            id: _uuid.v4(),
            shopId: shop.id,
            clientName: client.$1,
            clientPhone: client.$2,
            barberId: barber.id,
            chairNumber: chair,
            serviceNames: picked.map((s) => s.name).toList(),
            totalPrice: subtotal,
            barberCut: barberCut,
            shopCut: FloorPlanRepository.roundMoney(subtotal - barberCut),
            tip: tip,
            paymentMethod: payRoll < 0.6
                ? PaymentMethod.cash
                : PaymentMethod.card,
            timestamp: time,
          ).toMap(),
        );
      }
    }
    await batch.commit(noResult: true);
  }

  /// Two cuts in progress and three clients on the waiting couch.
  Future<void> _setLiveFloor(String shopId, DateTime now) async {
    final db = await _dbService.database;
    for (final (chair, client, minutesAgo) in const [
      (3, 'Omar Ben Ali', 12),
      (6, 'Mehdi Trabelsi', 25),
    ]) {
      await _floor.seatClient(
        shopId: shopId,
        chairNumber: chair,
        clientName: client,
      );
      await db.update(
        'chairs',
        {
          'service_start_time': now
              .subtract(Duration(minutes: minutesAgo))
              .toIso8601String(),
        },
        where: 'shop_id = ? AND chair_number = ?',
        whereArgs: [shopId, chair],
      );
    }

    for (final (name, phone) in const [
      ('Aziz Gharbi', '+216 98 774 120'),
      ('Hamza Chaabane', '+216 23 889 016'),
      ('Firas Mansour', null),
    ]) {
      await _queue.addToQueue(
        shopId: shopId,
        clientName: name,
        clientPhone: phone,
      );
    }
  }
}
