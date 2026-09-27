import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The SQLite engine for each platform is selected by DatabaseService.
  runApp(const ProviderScope(child: BarberShopOwnerApp()));
}
