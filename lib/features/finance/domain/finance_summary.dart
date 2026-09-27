import 'service_ticket.dart';

/// Earnings of one barber over a period.
class BarberPayout {
  const BarberPayout({
    required this.barberId,
    required this.barberName,
    required this.clientsServed,
    required this.commission,
    required this.tips,
  });

  final String barberId;
  final String barberName;
  final int clientsServed;
  final double commission;
  final double tips;

  /// What the shop owes the barber: commission plus tips.
  double get totalOwed => commission + tips;
}

/// Aggregated financial metrics for a set of tickets.
class FinanceSummary {
  const FinanceSummary({
    required this.grossRevenue,
    required this.shopNetRevenue,
    required this.barberPayouts,
    required this.tipsTotal,
    required this.cashTotal,
    required this.cardTotal,
    required this.transferTotal,
    required this.totalClientsServed,
    required this.tickets,
    this.payoutsByBarber = const [],
  });

  /// Service revenue, excluding tips.
  final double grossRevenue;
  final double shopNetRevenue;

  /// Barber commissions, excluding tips.
  final double barberPayouts;
  final double tipsTotal;

  /// Register balances include tips, since tips are collected with payment.
  final double cashTotal;
  final double cardTotal;
  final double transferTotal;
  final int totalClientsServed;
  final List<ServiceTicket> tickets;
  final List<BarberPayout> payoutsByBarber;

  double get averageTicket =>
      totalClientsServed == 0 ? 0 : grossRevenue / totalClientsServed;

  factory FinanceSummary.fromTickets(
    List<ServiceTicket> tickets, {
    Map<String, String> barberNames = const {},
  }) {
    double gross = 0.0;
    double shopNet = 0.0;
    double barberPayout = 0.0;
    double tips = 0.0;
    double cash = 0.0;
    double card = 0.0;
    double transfer = 0.0;
    final perBarber = <String, _PayoutAccumulator>{};

    for (final ticket in tickets) {
      gross += ticket.totalPrice;
      shopNet += ticket.shopCut;
      barberPayout += ticket.barberCut;
      tips += ticket.tip;

      final collected = ticket.totalPrice + ticket.tip;
      switch (ticket.paymentMethod) {
        case PaymentMethod.cash:
          cash += collected;
        case PaymentMethod.card:
          card += collected;
        case PaymentMethod.transfer:
          transfer += collected;
      }

      perBarber.putIfAbsent(ticket.barberId, _PayoutAccumulator.new)
        ..clients += 1
        ..commission += ticket.barberCut
        ..tips += ticket.tip;
    }

    final payouts =
        perBarber.entries
            .map(
              (e) => BarberPayout(
                barberId: e.key,
                barberName: barberNames[e.key] ?? 'Former barber',
                clientsServed: e.value.clients,
                commission: e.value.commission,
                tips: e.value.tips,
              ),
            )
            .toList()
          ..sort((a, b) => b.totalOwed.compareTo(a.totalOwed));

    return FinanceSummary(
      grossRevenue: gross,
      shopNetRevenue: shopNet,
      barberPayouts: barberPayout,
      tipsTotal: tips,
      cashTotal: cash,
      cardTotal: card,
      transferTotal: transfer,
      totalClientsServed: tickets.length,
      tickets: tickets,
      payoutsByBarber: payouts,
    );
  }
}

class _PayoutAccumulator {
  int clients = 0;
  double commission = 0;
  double tips = 0;
}

/// A returning-client record derived from the ticket ledger.
class ClientHistory {
  const ClientHistory({
    required this.clientName,
    this.clientPhone,
    required this.visits,
    required this.totalSpent,
    required this.lastVisit,
  });

  final String clientName;
  final String? clientPhone;
  final int visits;
  final double totalSpent;
  final DateTime lastVisit;

  factory ClientHistory.fromMap(Map<String, Object?> map) {
    return ClientHistory(
      clientName: map['client_name'] as String,
      clientPhone: map['client_phone'] as String?,
      visits: map['visits'] as int,
      totalSpent: (map['total_spent'] as num? ?? 0).toDouble(),
      lastVisit: DateTime.parse(map['last_visit'] as String),
    );
  }
}
