class QueueItem {
  const QueueItem({
    required this.id,
    required this.shopId,
    required this.clientName,
    this.clientPhone,
    this.requestedBarberId,
    this.notes,
    this.status = 'waiting',
    required this.createdAt,
  });

  final String id;
  final String shopId;
  final String clientName;
  final String? clientPhone;
  final String? requestedBarberId;
  final String? notes;
  final String status;
  final DateTime createdAt;

  QueueItem copyWith({
    String? id,
    String? shopId,
    String? clientName,
    String? clientPhone,
    String? requestedBarberId,
    String? notes,
    String? status,
    DateTime? createdAt,
  }) {
    return QueueItem(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      requestedBarberId: requestedBarberId ?? this.requestedBarberId,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'client_name': clientName,
      'client_phone': clientPhone,
      'requested_barber_id': requestedBarberId,
      'notes': notes,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory QueueItem.fromMap(Map<String, dynamic> map) {
    return QueueItem(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
      clientName: map['client_name'] as String,
      clientPhone: map['client_phone'] as String?,
      requestedBarberId: map['requested_barber_id'] as String?,
      notes: map['notes'] as String?,
      status: map['status'] as String? ?? 'waiting',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
