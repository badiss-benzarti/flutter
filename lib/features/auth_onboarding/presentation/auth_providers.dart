import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/repositories/shop_repository.dart';
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
  });

  final OwnerAccount? owner;
  final ShopProfile? shop;
  final bool isLoading;
  final String? errorMessage;

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

  Future<void> checkInitialSession() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final owner = await _repository.getActiveOwner();
      if (owner != null) {
        final shop = await _repository.getShopProfileByOwnerId(owner.id);
        state = AuthState(owner: owner, shop: shop);
      } else {
        state = const AuthState();
      }
    } catch (e) {
      state = AuthState(errorMessage: describeError(e));
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final owner = await _repository.registerOwner(
        email: email,
        password: password,
        fullName: fullName,
      );
      state = AuthState(owner: owner);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: describeError(e));
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final owner = await _repository.loginOwner(
        email: email,
        password: password,
      );
      final shop = await _repository.getShopProfileByOwnerId(owner.id);
      state = AuthState(owner: owner, shop: shop);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: describeError(e));
      return false;
    }
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
  }) async {
    final owner = state.owner;
    if (owner == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final shop = await _repository.setupShopProfile(
        ownerId: owner.id,
        name: name,
        address: address,
        phone: phone,
        totalChairs: totalChairs,
        initialBarbers: initialBarbers,
        services: services,
      );
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
    await _repository.logout();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
