import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Increases whenever changes from the server were written to this device.
/// Screens showing salon data watch it so they reload.
final syncRevisionProvider = NotifierProvider<SyncRevision, int>(
  SyncRevision.new,
);

class SyncRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}
