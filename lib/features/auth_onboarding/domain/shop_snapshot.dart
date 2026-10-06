import '../../barbers/domain/barber.dart';
import 'shop_profile.dart';

/// A salon's setup (details, services and team) as copied between this
/// device and the cloud. Day-to-day activity is not part of it.
class ShopSnapshot {
  const ShopSnapshot({required this.shop, required this.barbers});

  /// Includes the services.
  final ShopProfile shop;
  final List<Barber> barbers;
}
