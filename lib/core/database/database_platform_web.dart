import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Browser database: SQLite compiled to WebAssembly, persisted in IndexedDB.

DatabaseFactory platformDatabaseFactory() => databaseFactoryFfiWeb;

Future<String> platformDatabasePath(String fileName) async => fileName;
