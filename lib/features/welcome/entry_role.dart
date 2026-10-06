import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Who opened the app, picked on the welcome screen before signing in.
enum EntryRole { owner, barber, client }

/// The role picked on the welcome screen; null shows the welcome screen.
final entryRoleProvider = NotifierProvider<EntryRoleNotifier, EntryRole?>(
  EntryRoleNotifier.new,
);

class EntryRoleNotifier extends Notifier<EntryRole?> {
  @override
  EntryRole? build() => null;

  void choose(EntryRole role) => state = role;

  void reset() => state = null;
}
