import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth_onboarding/presentation/auth_providers.dart';
import '../providers/core_providers.dart';
import 'supabase_sync_remote.dart';
import 'sync_engine.dart';
import 'sync_remote.dart';
import 'sync_revision.dart';

final syncRemoteProvider = Provider<SyncRemote>((ref) {
  return SupabaseSyncRemote(Supabase.instance.client);
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    dbService: ref.watch(databaseServiceProvider),
    remote: ref.watch(syncRemoteProvider),
  );
});

class SyncStatus {
  const SyncStatus({
    this.enabled = false,
    this.syncing = false,
    this.offline = false,
    this.pending = 0,
    this.rejected = 0,
    this.lastSyncedAt,
    this.error,
  });

  /// False for device-only salons (the demo), which never sync.
  final bool enabled;
  final bool syncing;
  final bool offline;

  /// Changes waiting to be sent, of which [rejected] were refused.
  final int pending;
  final int rejected;
  final DateTime? lastSyncedAt;
  final String? error;

  SyncStatus copyWith({bool? syncing}) => SyncStatus(
    enabled: enabled,
    syncing: syncing ?? this.syncing,
    offline: offline,
    pending: pending,
    rejected: rejected,
    lastSyncedAt: lastSyncedAt,
    error: error,
  );
}

/// Keeps the signed-in cloud salon in sync while the app runs: queued
/// changes are sent within seconds, server changes are fetched every minute
/// (and on [syncNow]).
final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);

class SyncController extends Notifier<SyncStatus> {
  static const tick = Duration(seconds: 5);
  static const pullEveryTicks = 12;

  Timer? _timer;
  bool _busy = false;
  int _ticks = 0;
  String? _shopId;

  @override
  SyncStatus build() {
    final shopId = ref.watch(currentShopIdProvider);
    final isCloud = ref.watch(
      authProvider.select((s) => s.owner?.isCloudAccount ?? false),
    );
    ref.onDispose(() => _timer?.cancel());

    _shopId = isCloud ? shopId : null;
    if (_shopId == null) return const SyncStatus();

    _ticks = 0;
    _timer = Timer.periodic(tick, (_) => _onTick());
    Future.microtask(syncNow);
    return const SyncStatus(enabled: true, syncing: true);
  }

  SyncEngine get _engine => ref.read(syncEngineProvider);

  Future<void> _onTick() async {
    final shopId = _shopId;
    if (shopId == null || _busy) return;
    _ticks++;
    final pullDue = _ticks % pullEveryTicks == 0;
    if (pullDue || (await _engine.backlog(shopId)).pending > 0) {
      await _run(pull: pullDue);
    }
  }

  /// Sends pending changes and fetches the server's, right away.
  Future<void> syncNow() => _run(pull: true);

  Future<void> _run({required bool pull}) async {
    final shopId = _shopId;
    if (shopId == null || _busy) return;
    _busy = true;
    if (ref.mounted) state = state.copyWith(syncing: true);

    var offline = false;
    String? error;
    try {
      final report = await _engine.push(shopId);
      offline = report.offline;
      if (!offline && pull) {
        final changed = await _engine.pull(shopId);
        if (changed.isNotEmpty && ref.mounted) _applied(changed);
      }
    } on SyncOffline {
      offline = true;
    } catch (e) {
      debugPrint('Sync failed: $e');
      error = 'Sync failed. It will retry automatically.';
    } finally {
      _busy = false;
    }

    if (!ref.mounted || _shopId != shopId) return;
    final backlog = await _engine.backlog(shopId);
    if (!ref.mounted) return;
    state = SyncStatus(
      enabled: true,
      offline: offline,
      pending: backlog.pending,
      rejected: backlog.rejected,
      lastSyncedAt: offline || error != null
          ? state.lastSyncedAt
          : DateTime.now(),
      error: error ?? (backlog.rejected > 0 ? backlog.lastError : null),
    );
  }

  void _applied(Set<String> changed) {
    ref.read(syncRevisionProvider.notifier).bump();
    if (changed.contains('shops') || changed.contains('services')) {
      unawaited(ref.read(authProvider.notifier).reloadShop());
    }
  }
}
