import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Hashes and verifies owner passwords with PBKDF2-HMAC-SHA256.
///
/// Stored format: `pbkdf2-sha256$<iterations>$<hex digest>`.
/// Hashes created by earlier builds (a single salted SHA-256 round) are still
/// accepted by [verify] and reported by [needsRehash] so they can be upgraded
/// on the next successful login.
class PasswordHasher {
  const PasswordHasher({this.iterations = defaultIterations});

  static const int defaultIterations = 100000;
  static const String _scheme = 'pbkdf2-sha256';
  static const int _keyLength = 32;

  final int iterations;

  /// Generates a random 16-byte salt encoded as hex.
  String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return _toHex(bytes);
  }

  /// Hashes [password] off the UI thread (inline on the web, which has no
  /// isolates).
  Future<String> hash(String password, String salt) {
    return compute(_hashJob, (password, salt, iterations));
  }

  /// Returns true when [password] matches [storedHash].
  Future<bool> verify(String password, String salt, String storedHash) async {
    final parts = storedHash.split(r'$');
    if (parts.length == 3 && parts[0] == _scheme) {
      final storedIterations = int.tryParse(parts[1]);
      if (storedIterations == null || storedIterations <= 0) return false;
      final candidate = await compute(_hashJob, (
        password,
        salt,
        storedIterations,
      ));
      return constantTimeEquals(candidate, storedHash);
    }
    return constantTimeEquals(legacyHash(password, salt), storedHash);
  }

  /// Whether [storedHash] should be replaced with a fresh hash.
  bool needsRehash(String storedHash) {
    final parts = storedHash.split(r'$');
    if (parts.length != 3 || parts[0] != _scheme) return true;
    final storedIterations = int.tryParse(parts[1]) ?? 0;
    return storedIterations < iterations;
  }

  static String _hashJob((String, String, int) job) =>
      hashSync(job.$1, job.$2, job.$3);

  /// Synchronous PBKDF2 hash in the stored format.
  static String hashSync(String password, String salt, int iterations) {
    final digest = pbkdf2(
      utf8.encode(password),
      utf8.encode(salt),
      iterations,
      _keyLength,
    );
    return '$_scheme\$$iterations\$${_toHex(digest)}';
  }

  /// Single-round salted SHA-256 used by builds before PBKDF2 was introduced.
  static String legacyHash(String password, String salt) {
    return sha256.convert(utf8.encode('$salt:$password')).toString();
  }

  /// PBKDF2-HMAC-SHA256 (RFC 8018).
  static List<int> pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int keyLength,
  ) {
    final hmac = Hmac(sha256, password);
    final output = <int>[];
    for (var block = 1; output.length < keyLength; block++) {
      var u = hmac.convert([
        ...salt,
        (block >> 24) & 0xff,
        (block >> 16) & 0xff,
        (block >> 8) & 0xff,
        block & 0xff,
      ]).bytes;
      final t = List<int>.of(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var k = 0; k < t.length; k++) {
          t[k] ^= u[k];
        }
      }
      output.addAll(t);
    }
    return output.sublist(0, keyLength);
  }

  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static String _toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
