enum ChairStatus {
  empty, // No barber at chair
  available, // Barber ready at chair, waiting for client
  occupied, // Haircut in progress
  cleaning, // Sanitizing between cuts
}

class Station {
  const Station({
    required this.chairNumber,
    required this.shopId,
    this.status = ChairStatus.empty,
    this.activeBarberId,
    this.activeBarberName,
    this.activeClientName,
    this.activeTicketId,
    this.serviceStartTime,
  });

  final int chairNumber;
  final String shopId;
  final ChairStatus status;
  final String? activeBarberId;
  final String? activeBarberName;
  final String? activeClientName;
  final String? activeTicketId;
  final DateTime? serviceStartTime;

  Station copyWith({
    int? chairNumber,
    String? shopId,
    ChairStatus? status,
    String? activeBarberId,
    String? activeBarberName,
    String? activeClientName,
    String? activeTicketId,
    DateTime? serviceStartTime,
    bool clearBarber = false,
    bool clearClient = false,
  }) {
    return Station(
      chairNumber: chairNumber ?? this.chairNumber,
      shopId: shopId ?? this.shopId,
      status: status ?? this.status,
      activeBarberId: clearBarber
          ? null
          : (activeBarberId ?? this.activeBarberId),
      activeBarberName: clearBarber
          ? null
          : (activeBarberName ?? this.activeBarberName),
      activeClientName: clearClient
          ? null
          : (activeClientName ?? this.activeClientName),
      activeTicketId: clearClient
          ? null
          : (activeTicketId ?? this.activeTicketId),
      serviceStartTime: clearClient
          ? null
          : (serviceStartTime ?? this.serviceStartTime),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chair_number': chairNumber,
      'shop_id': shopId,
      'status': status.name,
      'active_barber_id': activeBarberId,
      'active_client_name': activeClientName,
      'active_ticket_id': activeTicketId,
      'service_start_time': serviceStartTime?.toIso8601String(),
    };
  }

  factory Station.fromMap(Map<String, dynamic> map, {String? barberName}) {
    ChairStatus parsedStatus;
    try {
      parsedStatus = ChairStatus.values.byName(map['status'] as String);
    } catch (_) {
      parsedStatus = ChairStatus.empty;
    }

    return Station(
      chairNumber: map['chair_number'] as int,
      shopId: map['shop_id'] as String,
      status: parsedStatus,
      activeBarberId: map['active_barber_id'] as String?,
      activeBarberName: barberName,
      activeClientName: map['active_client_name'] as String?,
      activeTicketId: map['active_ticket_id'] as String?,
      serviceStartTime: map['service_start_time'] != null
          ? DateTime.tryParse(map['service_start_time'] as String)
          : null,
    );
  }
}
