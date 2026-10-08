import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/cloud/cloud_errors.dart';
import '../floor_plan/domain/station.dart';
import '../queue/domain/queue_item.dart';
import 'barber_session.dart';

/// The barber's salon right now: its floor and who is waiting.
class SalonFloor {
  const SalonFloor({
    required this.shopName,
    required this.established,
    required this.totalChairs,
    required this.isOpen,
    required this.stations,
    required this.queue,
  });

  final String shopName;
  final int established;
  final int totalChairs;
  final bool isOpen;
  final List<Station> stations;

  /// Clients waiting, first arrived first.
  final List<QueueItem> queue;
}

/// Reads the barber's salon from the server and changes what a barber may.
/// Failures are thrown as `AppException`.
abstract class BarberSalonRepository {
  Future<SalonFloor> load(String shopId);

  /// On or off duty. Going off duty frees the barber's chair, and is refused
  /// while serving a client (enforced by the server).
  Future<void> setMyDuty({required bool onDuty});

  Future<void> addWalkIn(String shopId, String clientName);
}

class SupabaseBarberSalonRepository implements BarberSalonRepository {
  SupabaseBarberSalonRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<SalonFloor> load(String shopId) async {
    try {
      final results = await Future.wait<dynamic>([
        _client
            .from('shops')
            .select('name, created_at, total_chairs, is_open')
            .eq('id', shopId)
            .single(),
        _client
            .from('chairs')
            .select(
              'chair_number, status, active_barber_id, active_ticket_id, '
              'service_start_time, chair_clients(client_name)',
            )
            .eq('shop_id', shopId)
            .order('chair_number'),
        _client.from('barbers').select('id, name').eq('shop_id', shopId),
        _client
            .from('queue')
            .select(
              'id, client_name, client_phone, requested_barber_id, notes, '
              'created_at',
            )
            .eq('shop_id', shopId)
            .eq('status', 'waiting')
            .order('created_at'),
      ]);
      final shop = results[0] as Map<String, dynamic>;
      final chairs = results[1] as List<Map<String, dynamic>>;
      final barbers = results[2] as List<Map<String, dynamic>>;
      final queue = results[3] as List<Map<String, dynamic>>;

      final names = {
        for (final b in barbers) b['id'] as String: b['name'] as String,
      };
      return SalonFloor(
        shopName: shop['name'] as String,
        established: DateTime.parse(shop['created_at'] as String).year,
        totalChairs: shop['total_chairs'] as int,
        isOpen: shop['is_open'] as bool,
        stations: [
          for (final c in chairs)
            Station(
              chairNumber: c['chair_number'] as int,
              shopId: shopId,
              status:
                  ChairStatus.values.asNameMap()[c['status']] ??
                  ChairStatus.empty,
              activeBarberId: c['active_barber_id'] as String?,
              activeBarberName: names[c['active_barber_id']],
              activeClientName:
                  _embedded(c['chair_clients'])?['client_name'] as String?,
              activeTicketId: c['active_ticket_id'] as String?,
              serviceStartTime: _time(c['service_start_time']),
            ),
        ],
        queue: [
          for (final q in queue)
            QueueItem(
              id: q['id'] as String,
              shopId: shopId,
              clientName: q['client_name'] as String,
              clientPhone: q['client_phone'] as String?,
              requestedBarberId: q['requested_barber_id'] as String?,
              notes: q['notes'] as String?,
              createdAt: _time(q['created_at'])!,
            ),
        ],
      );
    } catch (e) {
      throw cloudException(e);
    }
  }

  @override
  Future<void> setMyDuty({required bool onDuty}) async {
    try {
      await _client.rpc<dynamic>('set_my_duty', params: {'p_on_duty': onDuty});
    } catch (e) {
      throw cloudException(e);
    }
  }

  @override
  Future<void> addWalkIn(String shopId, String clientName) async {
    try {
      await _client.from('queue').insert({
        'shop_id': shopId,
        'client_name': clientName.trim(),
      });
    } catch (e) {
      throw cloudException(e);
    }
  }

  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toLocal();

  static Map<String, dynamic>? _embedded(Object? value) => switch (value) {
    Map<String, dynamic> m => m,
    [Map<String, dynamic> m, ...] => m,
    _ => null,
  };
}

final barberSalonRepositoryProvider = Provider<BarberSalonRepository>((ref) {
  return SupabaseBarberSalonRepository(Supabase.instance.client);
});

/// The linked salon's floor, refreshed every 30 seconds while shown.
final barberFloorProvider =
    AsyncNotifierProvider.autoDispose<BarberFloorNotifier, SalonFloor>(
      BarberFloorNotifier.new,
    );

class BarberFloorNotifier extends AsyncNotifier<SalonFloor> {
  static const refreshEvery = Duration(seconds: 30);

  BarberSalonRepository get _repo => ref.read(barberSalonRepositoryProvider);

  String? get _shopId => ref.read(barberSessionProvider).link?.shopId;

  @override
  Future<SalonFloor> build() async {
    final shopId = ref.watch(
      barberSessionProvider.select((s) => s.link?.shopId),
    );
    if (shopId == null) throw StateError('Not linked to a salon.');
    final timer = Timer.periodic(refreshEvery, (_) => _quietRefresh());
    ref.onDispose(timer.cancel);
    return _repo.load(shopId);
  }

  /// Background refresh: keeps the last floor if the network blips.
  Future<void> _quietRefresh() async {
    final shopId = _shopId;
    if (shopId == null) return;
    try {
      final floor = await _repo.load(shopId);
      if (ref.mounted) state = AsyncData(floor);
    } catch (_) {}
  }

  /// Pull-to-refresh; throws so the screen can say what went wrong.
  Future<void> refresh() async {
    final shopId = _shopId;
    if (shopId == null) return;
    final floor = await _repo.load(shopId);
    if (ref.mounted) state = AsyncData(floor);
  }

  Future<void> setDuty({required bool onDuty}) async {
    await _repo.setMyDuty(onDuty: onDuty);
    await ref.read(barberSessionProvider.notifier).refresh();
    await _quietRefresh();
  }

  Future<void> addWalkIn(String clientName) async {
    final shopId = _shopId;
    if (shopId == null) return;
    await _repo.addWalkIn(shopId, clientName);
    await _quietRefresh();
  }
}
