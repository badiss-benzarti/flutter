import '../database/database_service.dart';
import '../../features/finance/domain/finance_summary.dart';
import '../../features/finance/domain/service_ticket.dart';

class FinanceRepository {
  FinanceRepository({required this._dbService});

  final DatabaseService _dbService;

  /// Tickets with `start <= timestamp < end`, newest first.
  Future<List<ServiceTicket>> getTicketsInRange({
    required String shopId,
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _dbService.database;
    final results = await db.query(
      'tickets',
      where: 'shop_id = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [shopId, start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp DESC',
    );
    return results.map(ServiceTicket.fromMap).toList();
  }

  /// Totals, register balances and per-barber payouts for a period.
  Future<FinanceSummary> getSummary({
    required String shopId,
    required DateTime start,
    required DateTime end,
  }) async {
    final tickets = await getTicketsInRange(
      shopId: shopId,
      start: start,
      end: end,
    );
    return FinanceSummary.fromTickets(
      tickets,
      barberNames: await _barberNames(shopId),
    );
  }

  /// Every client who has been served, most recent visit first.
  Future<List<ClientHistory>> getClientHistory(String shopId) async {
    final db = await _dbService.database;
    final rows = await db.rawQuery(
      '''
      SELECT client_name,
             MAX(client_phone) AS client_phone,
             COUNT(*) AS visits,
             SUM(total_price + tip) AS total_spent,
             MAX(timestamp) AS last_visit
      FROM tickets
      WHERE shop_id = ?
      GROUP BY LOWER(TRIM(client_name))
      ORDER BY last_visit DESC
    ''',
      [shopId],
    );
    return rows.map(ClientHistory.fromMap).toList();
  }

  Future<Map<String, String>> _barberNames(String shopId) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'barbers',
      columns: ['id', 'name'],
      where: 'shop_id = ?',
      whereArgs: [shopId],
    );
    return {for (final r in rows) r['id'] as String: r['name'] as String};
  }
}
