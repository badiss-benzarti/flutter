/// Connection details of the Supabase project (the cloud backend).
///
/// The publishable key is designed to ship inside the app: everything it can
/// read or write is limited by the row-level security policies in
/// `supabase/migrations`. Never put the secret / service_role key here.
///
/// Both values can be overridden at build time, e.g. to point at a test
/// project: `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...`.
abstract final class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qnmlnvjisuwdxqnkvzqd.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_i9kqtQl3uS1y5zupEy156g_6om_D-3I',
  );
}
