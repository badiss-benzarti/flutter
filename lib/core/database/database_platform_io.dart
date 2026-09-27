import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Native (mobile and desktop) database factory and location.

bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

DatabaseFactory platformDatabaseFactory() {
  if (_isDesktop) {
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }
  return sqflite.databaseFactory;
}

Future<String> platformDatabasePath(String fileName) async {
  if (_isDesktop) {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory(join(supportDir.path, 'BarberShopOwner'));
    await dir.create(recursive: true);
    final path = join(dir.path, fileName);
    await _moveLegacyDesktopDatabase(fileName, path);
    return path;
  }
  return join(await sqflite.getDatabasesPath(), fileName);
}

/// Early desktop builds stored the database in the user's visible
/// Documents folder. Move it (with its WAL side files) into app support.
Future<void> _moveLegacyDesktopDatabase(String fileName, String newPath) async {
  if (await File(newPath).exists()) return;
  final docDir = await getApplicationDocumentsDirectory();
  final legacyPath = join(docDir.path, 'BarberShopOwner', fileName);
  if (!await File(legacyPath).exists()) return;
  for (final suffix in const ['', '-wal', '-shm']) {
    final legacyFile = File('$legacyPath$suffix');
    if (await legacyFile.exists()) {
      await legacyFile.rename('$newPath$suffix');
    }
  }
}
