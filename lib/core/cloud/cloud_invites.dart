import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_errors.dart';

/// A code the owner gives one barber to link their account.
class BarberInvite {
  const BarberInvite(this.code, this.expiresAt);

  final String code;
  final DateTime expiresAt;
}

/// Creates invitation codes on the server. Failures are thrown as
/// `AppException` with a user-facing message.
abstract class CloudInvites {
  /// A new code for [barberId], replacing any previous one.
  Future<BarberInvite> createBarberInvite(String barberId);
}

class SupabaseCloudInvites implements CloudInvites {
  SupabaseCloudInvites(this._client);

  final SupabaseClient _client;

  @override
  Future<BarberInvite> createBarberInvite(String barberId) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'create_barber_invite',
        params: {'p_barber_id': barberId},
      );
      final row = rows.single as Map<String, dynamic>;
      return BarberInvite(
        row['code'] as String,
        DateTime.parse(row['expires_at'] as String).toLocal(),
      );
    } catch (e) {
      throw cloudException(e);
    }
  }
}
