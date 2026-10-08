import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart';

/// The app is newer than the server: a migration has not been applied yet.
const _notOnServerMessage =
    'This feature is not switched on for your salon yet. Ask your '
    'administrator to update the server, then try again.';

const _offlineMessage =
    'No internet connection. Check your network and try again.';

/// Converts a Supabase / network failure into a message the user can act on.
AppException cloudException(Object error) {
  if (error is AppException) return error;
  if (isNetworkError(error)) {
    return const AppException(_offlineMessage);
  }
  if (error is AuthException) {
    return AppException(switch (error.code) {
      'invalid_credentials' => 'Invalid email or password.',
      'email_not_confirmed' =>
        'Confirm your email first: open the link we sent you, then sign in.',
      'user_already_exists' ||
      'email_exists' => 'An account with this email already exists.',
      'weak_password' => 'This password is too weak. Try a longer one.',
      'email_address_invalid' => 'Enter a valid email address.',
      'over_email_send_rate_limit' || 'over_request_rate_limit' =>
        'Too many attempts. Wait a minute and try again.',
      'signup_disabled' => 'New accounts are closed for now.',
      _ => error.message,
    });
  }
  if (error is PostgrestException) {
    if (error.code != 'P0001') {
      debugPrint('Server refused: ${error.code} ${error.message}');
    }
    return AppException(switch (error.code) {
      // Raised by our own triggers with a message written for users.
      'P0001' => error.message,
      '42501' => 'You are not allowed to do this.',
      '23505' => 'This already exists.',
      // Unknown table or function: the server lacks a migration.
      'PGRST202' || 'PGRST205' || '42P01' || '42883' => _notOnServerMessage,
      _ => 'The server refused the change. Please try again.',
    });
  }
  if (error is StorageException) {
    debugPrint('Storage refused: ${error.statusCode} ${error.message}');
    return AppException(
      error.message.contains('Bucket not found')
          ? _notOnServerMessage
          : error.statusCode == '413'
          ? 'This photo is too large.'
          : 'The photo could not be uploaded. Please try again.',
    );
  }
  debugPrint('Unexpected cloud error: $error');
  return const AppException('Something went wrong. Please try again.');
}

/// Whether [error] means the server could not be reached.
bool isNetworkError(Object error) {
  if (error is AuthRetryableFetchException) return true;
  if (error is TimeoutException) return true;
  final text = error.toString();
  return text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('XMLHttpRequest error');
}
