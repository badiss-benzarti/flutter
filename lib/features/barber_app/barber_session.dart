import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud/cloud_auth.dart';
import '../../core/errors/app_exception.dart';
import '../../core/providers/cloud_providers.dart';
import 'barber_link.dart';

class BarberSessionState {
  const BarberSessionState({
    this.user,
    this.link,
    this.isLoading = false,
    this.errorMessage,
    this.infoMessage,
  });

  /// The signed-in barber account, if any.
  final CloudUser? user;

  /// The salon the account is linked to; null until it joins one.
  final BarberLink? link;
  final bool isLoading;
  final String? errorMessage;
  final String? infoMessage;

  bool get isSignedIn => user != null;
}

/// The barber side's session: a barber account on the server, linked to a
/// salon with the owner's invitation code. Unlike the owner app it works
/// online: the barber's data lives in their salon, on the server.
final barberSessionProvider =
    NotifierProvider<BarberSessionNotifier, BarberSessionState>(
      BarberSessionNotifier.new,
    );

class BarberSessionNotifier extends Notifier<BarberSessionState> {
  CloudAuth get _auth => ref.read(cloudAuthProvider);
  BarberLinkRepository get _links => ref.read(barberLinkRepositoryProvider);

  @override
  BarberSessionState build() {
    final user = ref.read(cloudAuthProvider).currentUser;
    if (user == null || user.role != AccountRole.barber) {
      return const BarberSessionState();
    }
    Future.microtask(refresh);
    return BarberSessionState(user: user, isLoading: true);
  }

  /// Reloads which salon this account belongs to.
  Future<void> refresh() async {
    final user = state.user;
    if (user == null) return;
    state = BarberSessionState(user: user, link: state.link, isLoading: true);
    try {
      final link = await _links.myLink(user.id);
      state = BarberSessionState(user: user, link: link);
    } catch (e) {
      state = BarberSessionState(
        user: user,
        link: state.link,
        errorMessage: describeError(e),
      );
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = const BarberSessionState(isLoading: true);
    final normalized = email.toLowerCase().trim();
    try {
      final user = await _auth.signUp(
        email: normalized,
        password: password,
        fullName: fullName.trim(),
        role: AccountRole.barber,
      );
      if (user == null) {
        state = BarberSessionState(
          infoMessage:
              'Account created. Open the link we sent to $normalized, '
              'then sign in.',
        );
        return true;
      }
      state = BarberSessionState(user: user);
      await refresh();
      return true;
    } catch (e) {
      state = BarberSessionState(errorMessage: describeError(e));
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = const BarberSessionState(isLoading: true);
    try {
      final user = await _auth.signIn(
        email: email.toLowerCase().trim(),
        password: password,
      );
      if (user.role != AccountRole.barber) {
        await _auth.signOut();
        throw const AppException(
          'This is not a barber account. Go back and choose your space.',
        );
      }
      state = BarberSessionState(user: user);
      await refresh();
      return true;
    } catch (e) {
      state = BarberSessionState(errorMessage: describeError(e));
      return false;
    }
  }

  /// Joins the salon with the owner's invitation code.
  Future<bool> join(String code) async {
    final user = state.user;
    if (user == null) return false;
    state = BarberSessionState(user: user, isLoading: true);
    try {
      final link = await _links.join(user.id, code);
      state = BarberSessionState(user: user, link: link);
      return true;
    } catch (e) {
      state = BarberSessionState(user: user, errorMessage: describeError(e));
      return false;
    }
  }

  void clearMessages() {
    if (state.errorMessage == null && state.infoMessage == null) return;
    state = BarberSessionState(user: state.user, link: state.link);
  }

  Future<void> logout() async {
    await _auth.signOut();
    state = const BarberSessionState();
  }
}
