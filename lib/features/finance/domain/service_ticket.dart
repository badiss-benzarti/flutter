enum PaymentMethod {
  cash,
  card,

  /// No longer offered at checkout; kept so older tickets still load.
  transfer;

  /// What the salon accepts at checkout.
  static const offered = [cash, card];
}

class ServiceTicket {
  const ServiceTicket({
    required this.id,
    required this.shopId,
    required this.clientName,
    this.clientPhone,
    required this.barberId,
    required this.chairNumber,
    required this.serviceNames,
    required this.totalPrice,
    required this.barberCut,
    required this.shopCut,
    this.tip = 0.0,
    required this.paymentMethod,
    required this.timestamp,
    this.isCompleted = true,
  });

  final String id;
  final String shopId;
  final String clientName;
  final String? clientPhone;
  final String barberId;
  final int chairNumber;
  final List<String> serviceNames;
  final double totalPrice;
  final double barberCut;
  final double shopCut;
  final double tip;
  final PaymentMethod paymentMethod;
  final DateTime timestamp;
  final bool isCompleted;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'client_name': clientName,
      'client_phone': clientPhone,
      'barber_id': barberId,
      'chair_number': chairNumber,
      'service_names': serviceNames.join(', '),
      'total_price': totalPrice,
      'barber_cut': barberCut,
      'shop_cut': shopCut,
      'tip': tip,
      'payment_method': paymentMethod.name,
      'timestamp': timestamp.toIso8601String(),
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  factory ServiceTicket.fromMap(Map<String, dynamic> map) {
    PaymentMethod method;
    try {
      method = PaymentMethod.values.byName(map['payment_method'] as String);
    } catch (_) {
      method = PaymentMethod.cash;
    }

    final rawServices = map['service_names'] as String? ?? '';
    final services = rawServices
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return ServiceTicket(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
      clientName: map['client_name'] as String,
      clientPhone: map['client_phone'] as String?,
      barberId: map['barber_id'] as String,
      chairNumber: map['chair_number'] as int,
      serviceNames: services,
      totalPrice: (map['total_price'] as num).toDouble(),
      barberCut: (map['barber_cut'] as num).toDouble(),
      shopCut: (map['shop_cut'] as num).toDouble(),
      tip: (map['tip'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: method,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isCompleted: (map['is_completed'] as int) == 1,
    );
  }
}
