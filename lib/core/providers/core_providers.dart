import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_service.dart';
import '../security/password_hasher.dart';
import '../security/session_storage.dart';

/// The single database connection shared by every repository.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final service = DatabaseService();
  ref.onDispose(service.close);
  return service;
});

final passwordHasherProvider = Provider<PasswordHasher>((ref) {
  return const PasswordHasher();
});

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return SecureSessionStorage();
});
