import 'package:barber_shop_owner/core/database/database_service.dart';
import 'package:barber_shop_owner/core/repositories/barber_repository.dart';
import 'package:barber_shop_owner/core/repositories/finance_repository.dart';
import 'package:barber_shop_owner/core/repositories/floor_plan_repository.dart';
import 'package:barber_shop_owner/core/repositories/queue_repository.dart';
import 'package:barber_shop_owner/core/repositories/shop_repository.dart';
import 'package:barber_shop_owner/core/security/password_hasher.dart';
import 'package:barber_shop_owner/core/security/session_storage.dart';
import 'package:barber_shop_owner/features/auth_onboarding/domain/shop_profile.dart';
import 'package:barber_shop_owner/features/barbers/domain/barber.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// All repositories wired to one fresh in-memory database.
class TestEnv {
  TestEnv._(this.db, this.session)
    : shops = ShopRepository(
        dbService: db,
        passwordHasher: const PasswordHasher(iterations: 1000),
        sessionStorage: session,
      ),
      barbers = BarberRepository(dbService: db),
      floor = FloorPlanRepository(dbService: db),
      finance = FinanceRepository(dbService: db),
      queue = QueueRepository(dbService: db);

  static Future<TestEnv> create() async {
    sqfliteFfiInit();
    final db = DatabaseService(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    return TestEnv._(db, InMemorySessionStorage());
  }

  final DatabaseService db;
  final InMemorySessionStorage session;
  final ShopRepository shops;
  final BarberRepository barbers;
  final FloorPlanRepository floor;
  final FinanceRepository finance;
  final QueueRepository queue;

  Future<void> dispose() => db.close();

  /// Registers an owner and creates a 4-chair shop with one barber at
  /// chair 1 (60% commission) and two services.
  Future<ShopFixture> seedShop() async {
    final owner = await shops.registerOwner(
      email: 'Owner@Example.com',
      password: 'password123',
      fullName: 'Owner',
    );
    final barber = Barber(
      id: 'barber-1',
      shopId: '',
      name: 'Sam',
      phone: '555',
      commissionRate: 0.6,
      assignedChair: 1,
      createdAt: DateTime.now(),
    );
    final shop = await shops.setupShopProfile(
      ownerId: owner.id,
      name: 'Blade',
      address: '1 Main St',
      phone: '555-0000',
      totalChairs: 4,
      initialBarbers: [barber],
      services: const [
        ServiceItem(id: 'x', shopId: '', name: 'Haircut', price: 25),
        ServiceItem(id: 'y', shopId: '', name: 'Beard', price: 15),
      ],
    );
    return ShopFixture(shop, barber.id);
  }
}

class ShopFixture {
  const ShopFixture(this.shop, this.barberId);

  final ShopProfile shop;
  final String barberId;

  String get shopId => shop.id;

  String serviceId(String name) =>
      shop.services.firstWhere((s) => s.name == name).id;
}
