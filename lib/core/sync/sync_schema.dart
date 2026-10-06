import 'package:sqflite/sqflite.dart';

/// Local tables and triggers that record what must be sent to the server.
///
/// Every change to a synced table of a cloud salon adds (or refreshes) one
/// row in `sync_outbox`, inside the same transaction as the change, so no
/// write path can forget it. Device-only salons (the demo) are never queued.
/// While server changes are being applied, `sync_control.applying` is 1 and
/// nothing is queued, so pulled rows are not sent back.
abstract final class SyncSchema {
  /// Synced tables in the order they must reach the server (rows reference
  /// rows of earlier tables).
  static const List<String> entities = [
    'shops',
    'barbers',
    'services',
    'chairs',
    'queue',
    'tickets',
  ];

  /// SQL expressions giving (shop id, row key) of a row aliased as `X`.
  static const Map<String, (String, String)> _keys = {
    'shops': ('X.id', 'X.id'),
    'barbers': ('X.shop_id', 'X.id'),
    'services': ('X.shop_id', 'X.id'),
    'chairs': ('X.shop_id', 'CAST(X.chair_number AS TEXT)'),
    'queue': ('X.shop_id', 'X.id'),
    'tickets': ('X.shop_id', 'X.id'),
  };

  static List<String> createStatements() => [
    '''
    CREATE TABLE sync_outbox (
      entity TEXT NOT NULL,
      shop_id TEXT NOT NULL,
      row_key TEXT NOT NULL,
      change_id TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      PRIMARY KEY (entity, shop_id, row_key)
    );
    ''',
    '''
    CREATE TABLE sync_control (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      applying INTEGER NOT NULL DEFAULT 0
    );
    ''',
    'INSERT INTO sync_control (id, applying) VALUES (1, 0);',
    '''
    CREATE TABLE sync_cursors (
      shop_id TEXT NOT NULL,
      entity TEXT NOT NULL,
      cursor TEXT NOT NULL,
      PRIMARY KEY (shop_id, entity)
    );
    ''',
    for (final entity in entities)
      for (final (op, alias) in const [
        ('INSERT', 'NEW'),
        ('UPDATE', 'NEW'),
        ('DELETE', 'OLD'),
      ])
        _trigger(entity, op, alias),
  ];

  static String _trigger(String entity, String op, String alias) {
    final (shopExpr, keyExpr) = _keys[entity]!;
    final shop = shopExpr.replaceAll('X.', '$alias.');
    final key = keyExpr.replaceAll('X.', '$alias.');
    return '''
    CREATE TRIGGER sync_${entity}_${op.toLowerCase()} AFTER $op ON $entity
    WHEN (SELECT applying FROM sync_control WHERE id = 1) = 0
      AND EXISTS (
        SELECT 1 FROM shops s JOIN owners o ON o.id = s.owner_id
        WHERE s.id = $shop AND o.password_hash = ''
      )
    BEGIN
      INSERT OR REPLACE INTO sync_outbox (entity, shop_id, row_key, change_id)
      VALUES ('$entity', $shop, $key, lower(hex(randomblob(8))));
    END;
    ''';
  }

  /// Queues every row of one salon's [entity] table, e.g. when a salon that
  /// lived only on this device moves to the cloud. Takes the shop id.
  static String enqueueAllStatement(String entity) {
    final (shopExpr, keyExpr) = _keys[entity]!;
    return '''
    INSERT OR REPLACE INTO sync_outbox (entity, shop_id, row_key, change_id)
    SELECT '$entity', $shopExpr, $keyExpr, lower(hex(randomblob(8)))
    FROM $entity X WHERE $shopExpr = ?
    ''';
  }

  /// Runs [action] without queueing its changes (they came from the server).
  static Future<T> applyingRemote<T>(
    Transaction txn,
    Future<T> Function() action,
  ) async {
    await txn.update('sync_control', {'applying': 1}, where: 'id = 1');
    final result = await action();
    await txn.update('sync_control', {'applying': 0}, where: 'id = 1');
    return result;
  }
}
