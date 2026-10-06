import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/database_service.dart';
import '../errors/app_exception.dart';
import '../security/password_hasher.dart';
import '../security/session_storage.dart';
import '../sync/sync_schema.dart';
import '../../features/auth_onboarding/domain/owner_account.dart';
import '../../features/auth_onboarding/domain/shop_profile.dart';
import '../../features/auth_onboarding/domain/shop_snapshot.dart';
import '../../features/barbers/domain/barber.dart';

class ShopRepository {
  ShopRepository({
    required this._dbService,
    required this._passwordHasher,
    required this._sessionStorage,
  });

  final DatabaseService _dbService;
  final PasswordHasher _passwordHasher;
  final SessionStorage _sessionStorage;
  final _uuid = const Uuid();

  static const int minChairs = 2;
  static const int maxChairs = 16;
  static const int minPasswordLength = 8;

  static String normalizeEmail(String email) => email.toLowerCase().trim();

  /// Registers a new owner account and signs it in.
  Future<OwnerAccount> registerOwner({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    if (!_isValidEmail(normalizedEmail)) {
      throw const AppException('Enter a valid email address.');
    }
    if (password.length < minPasswordLength) {
      throw const AppException(
        'Password must be at least $minPasswordLength characters.',
      );
    }
    if (fullName.trim().isEmpty) {
      throw const AppException('Please enter your full name.');
    }

    final db = await _dbService.database;
    final existing = await db.query(
      'owners',
      columns: ['id'],
      where: 'email = ?',
      whereArgs: [normalizedEmail],
    );
    if (existing.isNotEmpty) {
      throw const AppException('An account with this email already exists.');
    }

    final salt = _passwordHasher.generateSalt();
    final owner = OwnerAccount(
      id: _uuid.v4(),
      email: normalizedEmail,
      passwordHash: await _passwordHasher.hash(password, salt),
      salt: salt,
      fullName: fullName.trim(),
      createdAt: DateTime.now(),
    );

    await db.insert('owners', owner.toMap());
    await _sessionStorage.writeActiveOwnerId(owner.id);
    return owner;
  }

  /// Authenticates an owner. Legacy password hashes are upgraded in place.
  Future<OwnerAccount> loginOwner({
    required String email,
    required String password,
  }) async {
    final db = await _dbService.database;
    final results = await db.query(
      'owners',
      where: 'email = ?',
      whereArgs: [normalizeEmail(email)],
    );
    if (results.isEmpty) {
      throw const AppException('Invalid email or password.');
    }

    var owner = OwnerAccount.fromMap(results.first);
    // Cloud accounts have no password on the device.
    if (owner.isCloudAccount) {
      throw const AppException('Invalid email or password.');
    }
    final valid = await _passwordHasher.verify(
      password,
      owner.salt,
      owner.passwordHash,
    );
    if (!valid) {
      throw const AppException('Invalid email or password.');
    }

    if (_passwordHasher.needsRehash(owner.passwordHash)) {
      final salt = _passwordHasher.generateSalt();
      final newHash = await _passwordHasher.hash(password, salt);
      await db.update(
        'owners',
        {'password_hash': newHash, 'salt': salt},
        where: 'id = ?',
        whereArgs: [owner.id],
      );
      owner = OwnerAccount.fromMap({
        ...owner.toMap(),
        'password_hash': newHash,
        'salt': salt,
      });
    }

    await _sessionStorage.writeActiveOwnerId(owner.id);
    return owner;
  }

  /// Gets the currently signed-in owner, if any.
  Future<OwnerAccount?> getActiveOwner() async {
    final activeOwnerId = await _sessionStorage.readActiveOwnerId();
    if (activeOwnerId == null) return null;

    final db = await _dbService.database;
    final results = await db.query(
      'owners',
      where: 'id = ?',
      whereArgs: [activeOwnerId],
    );

    if (results.isEmpty) {
      await _sessionStorage.clear();
      return null;
    }
    return OwnerAccount.fromMap(results.first);
  }

  Future<void> logout() => _sessionStorage.clear();

  // ---------------------------------------------------------------------------
  // Cloud accounts
  //
  // Cloud accounts are verified by the server; this device keeps a password-
  // less copy of the owner so their salon can be used offline. Accounts with
  // a password hash here are device-only (created before cloud accounts, and
  // the demo shop).
  // ---------------------------------------------------------------------------

  /// Whether [email] belongs to a device-only account.
  Future<bool> hasDeviceOnlyAccount(String email) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'owners',
      columns: ['password_hash'],
      where: 'email = ?',
      whereArgs: [normalizeEmail(email)],
    );
    return rows.isNotEmpty &&
        (rows.first['password_hash'] as String).isNotEmpty;
  }

  /// Signs in the cloud account [id] on this device. A device-only account
  /// with the same email becomes this cloud account and keeps its salon.
  Future<OwnerAccount> signInCloudOwner({
    required String id,
    required String email,
    required String fullName,
  }) async {
    final normalizedEmail = normalizeEmail(email);
    final name = fullName.trim().isNotEmpty
        ? fullName.trim()
        : normalizedEmail.split('@').first;
    final db = await _dbService.database;

    await db.transaction((txn) async {
      final known = await txn.query(
        'owners',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (known.isNotEmpty) return;

      final sameEmail = await txn.query(
        'owners',
        columns: ['id'],
        where: 'email = ?',
        whereArgs: [normalizedEmail],
      );
      if (sameEmail.isEmpty) {
        await txn.insert('owners', {
          'id': id,
          'email': normalizedEmail,
          'password_hash': '',
          'salt': '',
          'full_name': name,
          'created_at': DateTime.now().toIso8601String(),
        });
        return;
      }

      // Re-key the device-only account; checked at commit.
      final oldId = sameEmail.first['id'] as String;
      await txn.execute('PRAGMA defer_foreign_keys = ON');
      await txn.update(
        'shops',
        {'owner_id': id},
        where: 'owner_id = ?',
        whereArgs: [oldId],
      );
      await txn.update(
        'owners',
        {'id': id, 'password_hash': '', 'salt': ''},
        where: 'id = ?',
        whereArgs: [oldId],
      );
    });

    await _sessionStorage.writeActiveOwnerId(id);
    final rows = await db.query('owners', where: 'id = ?', whereArgs: [id]);
    return OwnerAccount.fromMap(rows.first);
  }

  /// The salon's setup as stored on this device.
  Future<ShopSnapshot?> loadSnapshot(String ownerId) async {
    final shop = await getShopProfileByOwnerId(ownerId);
    if (shop == null) return null;
    final db = await _dbService.database;
    final barbers = await db.query(
      'barbers',
      where: 'shop_id = ?',
      whereArgs: [shop.id],
      orderBy: 'created_at ASC',
    );
    return ShopSnapshot(
      shop: shop,
      barbers: barbers.map(Barber.fromMap).toList(),
    );
  }

  /// Stores a salon downloaded from the cloud on this device.
  Future<ShopProfile> importSnapshot(ShopSnapshot snapshot) async {
    final shop = snapshot.shop;
    final db = await _dbService.database;
    // Came from the server: not queued to be sent back.
    await db.transaction(
      (txn) =>
          SyncSchema.applyingRemote(txn, () => _insertSnapshot(txn, snapshot)),
    );
    return (await getShopProfileByOwnerId(shop.ownerId))!;
  }

  Future<void> _insertSnapshot(Transaction txn, ShopSnapshot snapshot) async {
    final shop = snapshot.shop;
    await txn.insert('shops', shop.toMap());
    for (int i = 1; i <= shop.totalChairs; i++) {
      await txn.insert('chairs', {
        'chair_number': i,
        'shop_id': shop.id,
        'status': 'empty',
      });
    }
    for (final barber in snapshot.barbers) {
      await txn.insert('barbers', barber.copyWith(shopId: shop.id).toMap());
      final chair = barber.assignedChair;
      if (chair != null && !barber.isArchived) {
        await txn.update(
          'chairs',
          {'status': 'available', 'active_barber_id': barber.id},
          where: 'shop_id = ? AND chair_number = ?',
          whereArgs: [shop.id, chair],
        );
      }
    }
    for (final service in shop.services) {
      await txn.insert('services', {...service.toMap(), 'shop_id': shop.id});
    }
  }

  /// Removes a salon and everything in it from this device.
  Future<void> deleteShopLocally(String shopId) async {
    final db = await _dbService.database;
    await db.delete('shops', where: 'id = ?', whereArgs: [shopId]);
  }

  /// Creates the shop with its chairs, initial barbers and services.
  Future<ShopProfile> setupShopProfile({
    required String ownerId,
    required String name,
    required String address,
    required String phone,
    required int totalChairs,
    required List<Barber> initialBarbers,
    required List<ServiceItem> services,
  }) async {
    _validateShopDetails(name: name, address: address, phone: phone);
    _validateChairCount(totalChairs);
    for (final service in services) {
      _validateService(service.name, service.price, service.durationMinutes);
    }

    final db = await _dbService.database;
    final existing = await getShopProfileByOwnerId(ownerId);
    if (existing != null) return existing;

    final shopId = _uuid.v4();

    await db.transaction((txn) async {
      await txn.insert('shops', {
        'id': shopId,
        'owner_id': ownerId,
        'name': name.trim(),
        'address': address.trim(),
        'phone': phone.trim(),
        'total_chairs': totalChairs,
        'created_at': DateTime.now().toIso8601String(),
      });

      for (int i = 1; i <= totalChairs; i++) {
        await txn.insert('chairs', {
          'chair_number': i,
          'shop_id': shopId,
          'status': 'empty',
        });
      }

      final takenChairs = <int>{};
      for (final barber in initialBarbers) {
        final chair = barber.assignedChair;
        final canSit =
            chair != null &&
            chair >= 1 &&
            chair <= totalChairs &&
            takenChairs.add(chair);
        final row = barber.copyWith(
          shopId: shopId,
          clearAssignedChair: !canSit,
        );
        await txn.insert('barbers', row.toMap());
        if (canSit) {
          await txn.update(
            'chairs',
            {'status': 'available', 'active_barber_id': barber.id},
            where: 'shop_id = ? AND chair_number = ?',
            whereArgs: [shopId, chair],
          );
        }
      }

      for (final service in services) {
        await txn.insert('services', {
          'id': _uuid.v4(),
          'shop_id': shopId,
          'name': service.name.trim(),
          'price': service.price,
          'duration_minutes': service.durationMinutes,
        });
      }
    });

    final shop = await getShopProfileByOwnerId(ownerId);
    if (shop == null) {
      throw const AppException('Failed to load the created shop profile.');
    }
    return shop;
  }

  Future<ShopProfile?> getShopProfileByOwnerId(String ownerId) async {
    final db = await _dbService.database;
    final shopResults = await db.query(
      'shops',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      limit: 1,
    );
    if (shopResults.isEmpty) return null;

    final shopRow = shopResults.first;
    final services = await getServices(shopRow['id'] as String);
    return ShopProfile.fromMap(shopRow, services: services);
  }

  Future<void> updateShopDetails({
    required String shopId,
    required String name,
    required String address,
    required String phone,
  }) async {
    _validateShopDetails(name: name, address: address, phone: phone);
    final db = await _dbService.database;
    await db.update(
      'shops',
      {'name': name.trim(), 'address': address.trim(), 'phone': phone.trim()},
      where: 'id = ?',
      whereArgs: [shopId],
    );
  }

  // ---------------------------------------------------------------------------
  // Services catalog
  // ---------------------------------------------------------------------------

  Future<List<ServiceItem>> getServices(String shopId) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'services',
      where: 'shop_id = ?',
      whereArgs: [shopId],
      orderBy: 'price ASC, name ASC',
    );
    return rows.map(ServiceItem.fromMap).toList();
  }

  Future<void> saveService({
    required String shopId,
    String? serviceId,
    required String name,
    required double price,
    required int durationMinutes,
  }) async {
    _validateService(name, price, durationMinutes);
    final db = await _dbService.database;

    final duplicate = await db.query(
      'services',
      columns: ['id'],
      where: 'shop_id = ? AND LOWER(name) = ? AND id != ?',
      whereArgs: [shopId, name.trim().toLowerCase(), serviceId ?? ''],
    );
    if (duplicate.isNotEmpty) {
      throw const AppException('A service with this name already exists.');
    }

    final values = {
      'name': name.trim(),
      'price': price,
      'duration_minutes': durationMinutes,
    };
    if (serviceId == null) {
      await db.insert('services', {
        'id': _uuid.v4(),
        'shop_id': shopId,
        ...values,
      });
    } else {
      await db.update(
        'services',
        values,
        where: 'id = ? AND shop_id = ?',
        whereArgs: [serviceId, shopId],
      );
    }
  }

  Future<void> deleteService({
    required String shopId,
    required String serviceId,
  }) async {
    final db = await _dbService.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM services WHERE shop_id = ?',
      [shopId],
    );
    if ((rows.first['n'] as int) <= 1) {
      throw const AppException(
        'Keep at least one service so clients can be checked out.',
      );
    }
    await db.delete(
      'services',
      where: 'id = ? AND shop_id = ?',
      whereArgs: [serviceId, shopId],
    );
  }

  // ---------------------------------------------------------------------------
  // Floor capacity
  // ---------------------------------------------------------------------------

  /// Changes the number of chairs. Removing chairs is refused while any of
  /// them is serving a client; barbers on removed chairs are unassigned.
  Future<void> updateChairCapacity({
    required String shopId,
    required int newCapacity,
  }) async {
    _validateChairCount(newCapacity);
    final db = await _dbService.database;
    await db.transaction((txn) async {
      final currentChairs = await txn.query(
        'chairs',
        where: 'shop_id = ?',
        whereArgs: [shopId],
        orderBy: 'chair_number ASC',
      );
      final currentCount = currentChairs.length;

      if (newCapacity < currentCount) {
        final removed = currentChairs.where(
          (c) => (c['chair_number'] as int) > newCapacity,
        );
        final busy = removed
            .where((c) => c['status'] == 'occupied')
            .map((c) => c['chair_number'])
            .toList();
        if (busy.isNotEmpty) {
          throw AppException(
            'Chair ${busy.join(', ')} is serving a client. '
            'Check out the client before removing it.',
          );
        }

        await txn.update(
          'barbers',
          {'assigned_chair': null},
          where: 'shop_id = ? AND assigned_chair > ?',
          whereArgs: [shopId, newCapacity],
        );
        await txn.delete(
          'chairs',
          where: 'shop_id = ? AND chair_number > ?',
          whereArgs: [shopId, newCapacity],
        );
      } else {
        for (int i = currentCount + 1; i <= newCapacity; i++) {
          await txn.insert('chairs', {
            'chair_number': i,
            'shop_id': shopId,
            'status': 'empty',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      await txn.update(
        'shops',
        {'total_chairs': newCapacity},
        where: 'id = ?',
        whereArgs: [shopId],
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  static bool _isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  void _validateShopDetails({
    required String name,
    required String address,
    required String phone,
  }) {
    if (name.trim().isEmpty || address.trim().isEmpty || phone.trim().isEmpty) {
      throw const AppException('Shop name, address and phone are required.');
    }
  }

  void _validateChairCount(int count) {
    if (count < minChairs || count > maxChairs) {
      throw const AppException(
        'A shop must have between $minChairs and $maxChairs chairs.',
      );
    }
  }

  void _validateService(String name, double price, int durationMinutes) {
    if (name.trim().isEmpty) {
      throw const AppException('Service name is required.');
    }
    if (price.isNaN || price < 0) {
      throw const AppException('Service price cannot be negative.');
    }
    if (durationMinutes <= 0) {
      throw const AppException('Service duration must be positive.');
    }
  }
}
