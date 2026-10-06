import 'package:sqflite/sqflite.dart';

import '../database/database_service.dart';
import 'sync_remote.dart';
import 'sync_schema.dart';

/// Result of sending queued changes.
class PushReport {
  const PushReport({this.sent = 0, this.rejected = 0, this.offline = false});

  final int sent;
  final int rejected;
  final bool offline;
}

/// Where a salon stands with the server.
class SyncBacklog {
  const SyncBacklog({this.pending = 0, this.rejected = 0, this.lastError});

  /// Changes waiting to be sent.
  final int pending;

  /// Of which refused by the server at least once.
  final int rejected;
  final String? lastError;
}

/// Moves changes between this device's database and the server.
///
/// * [push] sends the rows queued in `sync_outbox` (see [SyncSchema]), in
///   dependency order. A row changed again while it was being sent keeps its
///   new queue entry, so nothing is lost.
/// * [pull] applies what changed on the server since the last pull. Rows
///   with unsent local changes are left alone: this device's latest change
///   wins until it has reached the server.
class SyncEngine {
  SyncEngine({required this._dbService, required this._remote});

  final DatabaseService _dbService;
  final SyncRemote _remote;

  Future<PushReport> push(String shopId) async {
    final db = await _dbService.database;
    // Entries of salons no longer on this device (e.g. a failed setup).
    await db.rawDelete(
      'DELETE FROM sync_outbox WHERE shop_id NOT IN (SELECT id FROM shops)',
    );
    final entries = await db.query(
      'sync_outbox',
      where: 'shop_id = ?',
      whereArgs: [shopId],
    );
    final ordered = [...entries]..sort(_byDependency);

    var sent = 0;
    var rejected = 0;
    for (final entry in ordered) {
      final entity = entry['entity'] as String;
      final key = entry['row_key'] as String;
      final changeId = entry['change_id'] as String;
      final row = await _readLocal(db, entity, shopId, key);
      try {
        await _remote.push(entity, shopId, key, row);
      } on SyncOffline {
        return PushReport(sent: sent, rejected: rejected, offline: true);
      } on SyncRejected catch (e) {
        rejected++;
        await db.rawUpdate(
          'UPDATE sync_outbox SET attempts = attempts + 1, last_error = ? '
          'WHERE entity = ? AND shop_id = ? AND row_key = ? AND change_id = ?',
          [e.message, entity, shopId, key, changeId],
        );
        continue;
      }
      await db.delete(
        'sync_outbox',
        where: 'entity = ? AND shop_id = ? AND row_key = ? AND change_id = ?',
        whereArgs: [entity, shopId, key, changeId],
      );
      sent++;
    }
    return PushReport(sent: sent, rejected: rejected);
  }

  /// Returns the tables that changed on this device. Throws [SyncOffline].
  Future<Set<String>> pull(String shopId) async {
    final changed = <String>{};
    for (final entity in SyncSchema.entities) {
      final db = await _dbService.database;
      final since = await _cursor(db, shopId, entity);
      final changes = await _remote.pull(entity, shopId, since);

      final applied = await db.transaction((txn) async {
        final applied = await SyncSchema.applyingRemote(
          txn,
          () => _apply(txn, entity, shopId, changes),
        );
        final cursor = changes.cursor;
        if (cursor != null) {
          await txn.insert('sync_cursors', {
            'shop_id': shopId,
            'entity': entity,
            'cursor': cursor.toUtc().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        return applied;
      });
      if (applied) changed.add(entity);
    }
    return changed;
  }

  /// Queues every row of a salon, so all of it reaches the server.
  Future<void> enqueueAll(String shopId) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      for (final entity in SyncSchema.entities) {
        await txn.rawInsert(SyncSchema.enqueueAllStatement(entity), [shopId]);
      }
    });
  }

  Future<SyncBacklog> backlog(String shopId) async {
    final db = await _dbService.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS pending, '
      'SUM(CASE WHEN attempts > 0 THEN 1 ELSE 0 END) AS rejected, '
      'MAX(last_error) AS last_error '
      'FROM sync_outbox WHERE shop_id = ?',
      [shopId],
    );
    final row = rows.first;
    return SyncBacklog(
      pending: row['pending'] as int? ?? 0,
      rejected: row['rejected'] as int? ?? 0,
      lastError: row['last_error'] as String?,
    );
  }

  // ---------------------------------------------------------------------------
  // Applying server changes
  // ---------------------------------------------------------------------------

  Future<bool> _apply(
    Transaction txn,
    String entity,
    String shopId,
    RemoteChanges changes,
  ) async {
    final pending = {
      for (final row in await txn.query(
        'sync_outbox',
        columns: ['row_key'],
        where: 'entity = ? AND shop_id = ?',
        whereArgs: [entity, shopId],
      ))
        row['row_key'] as String,
    };

    var applied = false;
    for (final row in changes.rows) {
      final key = _keyOf(entity, row);
      if (pending.contains(key)) continue;
      final changed = switch (entity) {
        'shops' => await _applyShop(txn, row),
        'tickets' =>
          await txn.insert(
                'tickets',
                row,
                conflictAlgorithm: ConflictAlgorithm.ignore,
              ) >
              0,
        _ => await _upsert(txn, entity, shopId, key, row),
      };
      applied |= changed;
    }
    for (final key in changes.deletedKeys) {
      if (pending.contains(key)) continue;
      final (where, args) = _keyWhere(entity, shopId, key);
      applied |= await txn.delete(entity, where: where, whereArgs: args) > 0;
    }
    return applied;
  }

  /// Salon details, and its chairs when the server changed their number.
  Future<bool> _applyShop(Transaction txn, Map<String, Object?> row) async {
    final shopId = row['id'] as String;
    final rows = await txn.query('shops', where: 'id = ?', whereArgs: [shopId]);
    if (rows.isEmpty) return false;
    final existing = rows.first;
    final diff = _diff(existing, row);
    if (diff.isEmpty) return false;

    final oldCount = existing['total_chairs'] as int;
    final newCount = row['total_chairs'] as int? ?? oldCount;
    if (newCount > oldCount) {
      for (var n = oldCount + 1; n <= newCount; n++) {
        await txn.insert('chairs', {
          'chair_number': n,
          'shop_id': shopId,
          'status': 'empty',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    } else if (newCount < oldCount) {
      // The server only allows this when the removed chairs are free.
      await txn.update(
        'barbers',
        {'assigned_chair': null},
        where: 'shop_id = ? AND assigned_chair > ?',
        whereArgs: [shopId, newCount],
      );
      await txn.delete(
        'chairs',
        where: 'shop_id = ? AND chair_number > ?',
        whereArgs: [shopId, newCount],
      );
    }
    await txn.update('shops', diff, where: 'id = ?', whereArgs: [shopId]);
    return true;
  }

  /// Inserts the row, or updates the columns that differ. True if written.
  Future<bool> _upsert(
    Transaction txn,
    String entity,
    String shopId,
    String key,
    Map<String, Object?> row,
  ) async {
    final (where, args) = _keyWhere(entity, shopId, key);
    final rows = await txn.query(entity, where: where, whereArgs: args);
    if (rows.isEmpty) {
      await txn.insert(entity, row);
      return true;
    }
    final diff = _diff(rows.first, row);
    if (diff.isEmpty) return false;
    await txn.update(entity, diff, where: where, whereArgs: args);
    return true;
  }

  static Map<String, Object?> _diff(
    Map<String, Object?> existing,
    Map<String, Object?> incoming,
  ) => {
    for (final MapEntry(:key, :value) in incoming.entries)
      if (existing.containsKey(key) && !_same(existing[key], value)) key: value,
  };

  static bool _same(Object? a, Object? b) =>
      (a is num && b is num) ? a.toDouble() == b.toDouble() : a == b;

  // ---------------------------------------------------------------------------
  // Keys
  // ---------------------------------------------------------------------------

  static String _keyOf(String entity, Map<String, Object?> row) =>
      entity == 'chairs' ? '${row['chair_number']}' : row['id'] as String;

  static (String, List<Object?>) _keyWhere(
    String entity,
    String shopId,
    String key,
  ) => switch (entity) {
    'shops' => ('id = ?', [key]),
    'chairs' => ('shop_id = ? AND chair_number = ?', [shopId, int.parse(key)]),
    _ => ('id = ? AND shop_id = ?', [key, shopId]),
  };

  static Future<Map<String, Object?>?> _readLocal(
    DatabaseExecutor db,
    String entity,
    String shopId,
    String key,
  ) async {
    final (where, args) = _keyWhere(entity, shopId, key);
    final rows = await db.query(entity, where: where, whereArgs: args);
    return rows.isEmpty ? null : rows.first;
  }

  static int _byDependency(Map<String, Object?> a, Map<String, Object?> b) {
    const order = SyncSchema.entities;
    final byEntity = order
        .indexOf(a['entity'] as String)
        .compareTo(order.indexOf(b['entity'] as String));
    if (byEntity != 0) return byEntity;
    final ka = a['row_key'] as String;
    final kb = b['row_key'] as String;
    final na = int.tryParse(ka);
    final nb = int.tryParse(kb);
    return (na != null && nb != null) ? na.compareTo(nb) : ka.compareTo(kb);
  }

  static Future<DateTime?> _cursor(
    DatabaseExecutor db,
    String shopId,
    String entity,
  ) async {
    final rows = await db.query(
      'sync_cursors',
      where: 'shop_id = ? AND entity = ?',
      whereArgs: [shopId, entity],
    );
    return rows.isEmpty ? null : DateTime.parse(rows.first['cursor'] as String);
  }
}
