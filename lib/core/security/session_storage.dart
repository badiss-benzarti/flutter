import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists which owner is signed in on this device.
abstract class SessionStorage {
  Future<String?> readActiveOwnerId();
  Future<void> writeActiveOwnerId(String ownerId);
  Future<void> clear();
}

/// [SessionStorage] backed by the platform keystore / keychain.
class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  static const String _activeOwnerIdKey = 'barber_shop_active_owner_id';

  @override
  Future<String?> readActiveOwnerId() => _storage.read(key: _activeOwnerIdKey);

  @override
  Future<void> writeActiveOwnerId(String ownerId) =>
      _storage.write(key: _activeOwnerIdKey, value: ownerId);

  @override
  Future<void> clear() => _storage.delete(key: _activeOwnerIdKey);
}

/// Non-persistent [SessionStorage], used by tests.
class InMemorySessionStorage implements SessionStorage {
  String? _ownerId;

  @override
  Future<String?> readActiveOwnerId() async => _ownerId;

  @override
  Future<void> writeActiveOwnerId(String ownerId) async => _ownerId = ownerId;

  @override
  Future<void> clear() async => _ownerId = null;
}
