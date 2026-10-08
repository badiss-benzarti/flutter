import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/barber_app/barber_link.dart';
import '../cloud/cloud_auth.dart';
import '../cloud/cloud_invites.dart';
import '../cloud/cloud_shop_repository.dart';

/// Cloud services. Supabase must be initialized in `main()` before these are
/// read; tests override them with fakes.
final cloudAuthProvider = Provider<CloudAuth>((ref) {
  return SupabaseCloudAuth(Supabase.instance.client);
});

final cloudShopRepositoryProvider = Provider<CloudShopRepository>((ref) {
  return SupabaseCloudShopRepository(Supabase.instance.client);
});

final cloudInvitesProvider = Provider<CloudInvites>((ref) {
  return SupabaseCloudInvites(Supabase.instance.client);
});

final barberLinkRepositoryProvider = Provider<BarberLinkRepository>((ref) {
  return SupabaseBarberLinkRepository(Supabase.instance.client);
});
