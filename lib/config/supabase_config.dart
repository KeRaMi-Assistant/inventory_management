/// Static Supabase project configuration.
///
/// The publishable (anon) key is intentionally part of the client bundle —
/// it only grants access through Row Level Security policies and is safe
/// to ship. The PostgreSQL direct-connect password lives outside the app.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = 'https://uzpkrdymlrrydtuxnvhy.supabase.co';
  static const String anonKey =
      'sb_publishable_6t00CUF7N9DLR7Rem33DaA_ZUElt3sQ';
}
