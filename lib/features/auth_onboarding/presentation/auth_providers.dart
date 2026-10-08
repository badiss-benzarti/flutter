import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud/cloud_auth.dart';
import '../../../core/cloud/cloud_shop_repository.dart';
import '../../../core/demo/demo_seeder.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/providers/cloud_providers.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/repositories/floor_plan_repository.dart';
import '../../../core/repositories/queue_repository.dart';
import '../../../core/repositories/shop_repository.dart';
import '../../../core/sync/sync_controller.dart';
import '../domain/owner_account.dart';
import '../domain/shop_profile.dart';
import '../../barbers/domain/barber.dart';

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  return ShopRepository(
    dbService: ref.watch(databaseServiceProvider),
    passwordHasher: ref.watch(passwordHasherProvider),
    sessionStorage: ref.watch(sessionStorageProvider),
  );
});

final demoSeederProvider = Provider<DemoSeeder>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return DemoSeeder(
    dbService: db,
    shops: ref.watch(shopRepositoryProvider),
    floor: FloorPlanRepository(dbService: db),
    queue: QueueRepository(dbService: db),
  );
});

/// The id of the signed-in owner's shop, or null. Feature providers watch
/// this instead of the whole [AuthState] so they only reload when the shop
/// itself changes.
final currentShopIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider.select((s) => s.shop?.id));
});

class AuthState {
  const AuthState({
    this.owner,
    this.shop,
    this.isLoading = false,
    this.errorMessage,
    this.infoMessage,
  });

  final OwnerAccount? owner;
  final ShopProfile? shop;
  final bool isLoading;
  final String? errorMessage;

  /// A notice that is not an error, e.g. "confirm your email".
  final String? infoMessage;

  bool get isAuthenticated => owner != null;
  bool get hasCompletedOnboarding => shop != null;

  AuthState copyWith({
    OwnerAccount? owner,
    ShopProfile? shop,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearShop = false,
  }) {
    return AuthState(
      owner: owner ?? this.owner,
      shop: clearShop ? null : (shop ?? this.shop),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearError ? null : infoMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(checkInitialSession);
    return const AuthState(isLoading: true);
  }

  ShopRepository get _repository => ref.read(shopRepositoryProvider);
  CloudAuth get _cloudAuth => ref.read(cloudAuthProvider);
  CloudShopRepository get _cloudShops => ref.read(cloudShopRepositoryProvider);

  /// Restores the owner signed in on this device. Works offline: the salon
  /// is read from the device and only downloaded if it is not there yet.
  Future<void> checkInitialSession() async {
    state = state.copyWith(isLoading: true, clearError: true);
    OwnerAccount? owner;
    try {
      owner = await _repository.getActiveOwner();
      if (owner == null) {
        state = const AuthState();
        return;
      }
      if (owner.isCloudAccount && _cloudAuth.currentUser?.id != owner.id) {
        // The cloud session ended (signed out or expired): sign in again.
        await _repository.logout();
        state = const AuthState();
        return;
      }
      var shop = await _repository.getShopProfileByOwnerId(owner.id);
      if (shop == null && owner.isCloudAccount) {
        final remote = await _cloudShops.fetchOwnedShop(owner.id);
        if (remote != null) shop = await _repository.importSnapshot(remote);
      }
      state = AuthState(owner: owner, shop: shop);
    } catch (e) {
      state = AuthState(owner: owner, errorMessage: describeError(e));
    }
  }

  /// Creates a cloud owner account. When the email must be confirmed first,
  /// nobody is signed in and [AuthState.infoMessage] says what to do.
  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final normalizedEmail = ShopRepository.normalizeEmail(email);
    try {
      final user = await _cloudAuth.signUp(
        email: normalizedEmail,
        password: password,
        fullName: fullName.trim(),
        role: AccountRole.owner,
      );
      if (user == null) {
        state = AuthState(
          infoMessage:
              'Account created. Open the link we sent to $normalizedEmail, '
              'then sign in.',
        );
        return true;
      }
      await _signInCloudUser(user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: describeError(e));
      return false;
    }
  }

  /// Signs in with the cloud account. Accounts that exist only on this
  /// device (created before cloud accounts) still work, also offline.
  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final CloudUser user;
      try {
        user = await _cloudAuth.signIn(
          email: ShopRepository.normalizeEmail(email),
          password: password,
        );
      } on AppException {
        if (!await _repository.hasDeviceOnlyAccount(email)) rethrow;
        await _signInDeviceOnly(email, password);
        return true;
      }
      if (user.role != AccountRole.owner) {
        await _cloudAuth.signOut();
        throw const AppException(
          'This is not a salon owner account. Go back and choose your space.',
        );
      }
      await _signInCloudUser(user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: describeError(e));
      return false;
    }
  }

  /// Creates the demo shop on this device if needed, then signs into it.
  /// The demo never touches the cloud.
  Future<bool> loginDemo() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(demoSeederProvider).ensureDemoAccount();
      await _signInDeviceOnly(DemoSeeder.email, DemoSeeder.password);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: describeError(e));
      return false;
    }
  }

  Future<void> _signInDeviceOnly(String email, String password) async {
    final owner = await _repository.loginOwner(
      email: email,
      password: password,
    );
    final shop = await _repository.getShopProfileByOwnerId(owner.id);
    state = AuthState(owner: owner, shop: shop);
  }

  /// Links the cloud account to this device and brings its salon here: from
  /// the server, or the other way round for a salon created on this device
  /// before it had a cloud account.
  Future<void> _signInCloudUser(CloudUser user) async {
    final owner = await _repository.signInCloudOwner(
      id: user.id,
      email: user.email,
      fullName: user.fullName,
    );
    final local = await _repository.loadSnapshot(owner.id);
    final remote = await _cloudShops.fetchOwnedShop(owner.id);

    ShopProfile? shop;
    if (local != null) {
      if (remote == null) {
        await _cloudShops.uploadShop(local);
        // Its history (tickets, queue...) follows through sync.
        await ref.read(syncEngineProvider).enqueueAll(local.shop.id);
      }
      shop = local.shop;
    } else if (remote != null) {
      shop = await _repository.importSnapshot(remote);
    }
    state = AuthState(owner: owner, shop: shop);
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  Future<bool> completeOnboarding({
    required String name,
    required String address,
    required String phone,
    required int totalChairs,
    required List<Barber> initialBarbers,
    required List<ServiceItem> services,
    double? latitude,
    double? longitude,
  }) async {
    final owner = state.owner;
    if (owner == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (owner.isCloudAccount) {
        // Created meanwhile on another device: use that one.
        final remote = await _cloudShops.fetchOwnedShop(owner.id);
        if (remote != null) {
          final shop = await _repository.importSnapshot(remote);
          state = state.copyWith(shop: shop, isLoading: false);
          return true;
        }
      }
      final shop = await _repository.setupShopProfile(
        ownerId: owner.id,
        name: name,
        address: address,
        phone: phone,
        totalChairs: totalChairs,
        initialBarbers: initialBarbers,
        services: services,
        latitude: latitude,
        longitude: longitude,
      );
      if (owner.isCloudAccount) {
        try {
          final snapshot = await _repository.loadSnapshot(owner.id);
          await _cloudShops.uploadShop(snapshot!);
        } catch (_) {
          // Keep device and server identical: the whole setup is retried.
          await _repository.deleteShopLocally(shop.id);
          rethrow;
        }
      }
      state = state.copyWith(shop: shop, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: describeError(e));
      return false;
    }
  }

  /// Reloads the shop profile (details and services) from the database.
  Future<void> reloadShop() async {
    final owner = state.owner;
    if (owner == null) return;
    final shop = await _repository.getShopProfileByOwnerId(owner.id);
    state = state.copyWith(shop: shop, clearShop: shop == null);
  }

  Future<void> updateShopDetails({
    required String name,
    required String address,
    required String phone,
  }) async {
    final shop = state.shop;
    if (shop == null) return;
    await _repository.updateShopDetails(
      shopId: shop.id,
      name: name,
      address: address,
      phone: phone,
    );
    await reloadShop();
  }

  /// Throws [AppException] for an invalid position.
  Future<void> updateShopLocation(double latitude, double longitude) async {
    final shop = state.shop;
    if (shop == null) return;
    await _repository.updateShopLocation(
      shopId: shop.id,
      latitude: latitude,
      longitude: longitude,
    );
    await reloadShop();
  }

  Future<void> setShopOpen(bool isOpen) async {
    final shop = state.shop;
    if (shop == null) return;
    await _repository.setShopOpen(shopId: shop.id, isOpen: isOpen);
    await reloadShop();
  }

  /// Throws [AppException] when the salon has no location yet.
  Future<void> setShopListed(bool isListed) async {
    final shop = state.shop;
    if (shop == null) return;
    await _repository.setShopListed(shopId: shop.id, isListed: isListed);
    await reloadShop();
  }

  Future<void> saveService({
    String? serviceId,
    required String name,
    required double price,
    required int durationMinutes,
  }) async {
    final shop = state.shop;
    if (shop == null) return;
    await _repository.saveService(
      shopId: shop.id,
      serviceId: serviceId,
      name: name,
      price: price,
      durationMinutes: durationMinutes,
    );
    await reloadShop();
  }

  Future<void> deleteService(String serviceId) async {
    final shop = state.shop;
    if (shop == null) return;
    await _repository.deleteService(shopId: shop.id, serviceId: serviceId);
    await reloadShop();
  }

  /// Throws [AppException] when chairs being removed are in use.
  Future<void> updateChairCount(int newCount) async {
    final shop = state.shop;
    if (shop == null) return;
    await _repository.updateChairCapacity(
      shopId: shop.id,
      newCapacity: newCount,
    );
    state = state.copyWith(shop: shop.copyWith(totalChairs: newCount));
  }

  Future<void> logout() async {
    if (state.owner?.isCloudAccount ?? false) await _cloudAuth.signOut();
    await _repository.logout();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
