/// The server side of sync, in terms of local rows: column names and value
/// formats are those of the SQLite tables (see `DatabaseService`).
abstract class SyncRemote {
  /// Sends the current local state of one row. [row] is null when the row no
  /// longer exists on this device.
  Future<void> push(
    String entity,
    String shopId,
    String key,
    Map<String, Object?>? row,
  );

  /// Rows of [entity] changed on the server after [since] (null: all).
  Future<RemoteChanges> pull(String entity, String shopId, DateTime? since);
}

class RemoteChanges {
  const RemoteChanges({
    this.rows = const [],
    this.deletedKeys = const [],
    this.cursor,
  });

  /// Local-format rows, oldest change first.
  final List<Map<String, Object?>> rows;
  final List<String> deletedKeys;

  /// Server time of the newest change seen, to pass as `since` next time.
  final DateTime? cursor;
}

/// The server could not be reached; nothing was changed.
class SyncOffline implements Exception {
  const SyncOffline();
}

/// The server refused a change (it will be retried, and reported).
class SyncRejected implements Exception {
  const SyncRejected(this.message);

  final String message;

  @override
  String toString() => message;
}
