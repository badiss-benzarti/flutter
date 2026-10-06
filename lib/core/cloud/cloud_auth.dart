import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart';
import 'cloud_errors.dart';

/// An account on the cloud backend.
class CloudUser {
  const CloudUser({
    required this.id,
    required this.email,
    required this.fullName,
  });

  final String id;
  final String email;
  final String fullName;
}

/// Sign-up, sign-in and session of cloud accounts. Failures are thrown as
/// [AppException] with a user-facing message.
abstract class CloudAuth {
  /// The account whose session is stored on this device, if any.
  CloudUser? get currentUser;

  /// Creates an owner account. Returns the signed-in user, or null when the
  /// project requires the email to be confirmed before the first sign-in.
  Future<CloudUser?> signUpOwner({
    required String email,
    required String password,
    required String fullName,
  });

  Future<CloudUser> signIn({required String email, required String password});

  Future<void> signOut();
}

class SupabaseCloudAuth implements CloudAuth {
  SupabaseCloudAuth(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  CloudUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : _toCloudUser(user);
  }

  @override
  Future<CloudUser?> signUpOwner({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email,
        password: password,
        // Read by the `handle_new_user` trigger to create the profile.
        data: {'role': 'owner', 'full_name': fullName},
      );
      final user = response.user;
      if (response.session != null && user != null) return _toCloudUser(user);
      // With email confirmation on, an existing address comes back as a user
      // without identities instead of an error (to hide who has an account).
      if (user != null && (user.identities?.isEmpty ?? false)) {
        throw const AppException('An account with this email already exists.');
      }
      return null;
    } catch (e) {
      throw cloudException(e);
    }
  }

  @override
  Future<CloudUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AppException('Invalid email or password.');
      }
      return _toCloudUser(user);
    } catch (e) {
      throw cloudException(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Offline: the local session is cleared anyway by the SDK.
    }
  }

  static CloudUser _toCloudUser(User user) => CloudUser(
    id: user.id,
    email: user.email ?? '',
    fullName: (user.userMetadata?['full_name'] as String?) ?? '',
  );
}
