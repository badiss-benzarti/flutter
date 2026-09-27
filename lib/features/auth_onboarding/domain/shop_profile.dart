class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.shopId,
    required this.name,
    required this.price,
    this.durationMinutes = 30,
  });

  final String id;
  final String shopId;
  final String name;
  final double price;
  final int durationMinutes;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'name': name,
      'price': price,
      'duration_minutes': durationMinutes,
    };
  }

  factory ServiceItem.fromMap(Map<String, dynamic> map) {
    return ServiceItem(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      durationMinutes: map['duration_minutes'] as int? ?? 30,
    );
  }
}

class ShopProfile {
  const ShopProfile({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.address,
    required this.phone,
    required this.totalChairs,
    required this.createdAt,
    this.services = const [],
  });

  final String id;
  final String ownerId;
  final String name;
  final String address;
  final String phone;
  final int totalChairs;
  final DateTime createdAt;
  final List<ServiceItem> services;

  ShopProfile copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? address,
    String? phone,
    int? totalChairs,
    DateTime? createdAt,
    List<ServiceItem>? services,
  }) {
    return ShopProfile(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      totalChairs: totalChairs ?? this.totalChairs,
      createdAt: createdAt ?? this.createdAt,
      services: services ?? this.services,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'address': address,
      'phone': phone,
      'total_chairs': totalChairs,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ShopProfile.fromMap(
    Map<String, dynamic> map, {
    List<ServiceItem> services = const [],
  }) {
    return ShopProfile(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      name: map['name'] as String,
      address: map['address'] as String,
      phone: map['phone'] as String,
      totalChairs: map['total_chairs'] as int? ?? 8,
      createdAt: DateTime.parse(map['created_at'] as String),
      services: services,
    );
  }
}
