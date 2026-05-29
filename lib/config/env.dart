/// Compile-time configuration read from `--dart-define-from-file=<path>`.
///
/// Values come from a JSON file kept outside source control. See `README.md`
/// for the expected file layout and how to pass it to `flutter run / build`.
///
/// No secrets are stored in this repository: when no env file is supplied,
/// every value below resolves to an empty string and the relevant subsystem
/// (e.g. Supabase) is simply not initialised.
class Env {
  Env._();

  /// Supabase project URL (e.g. `https://xxxx.supabase.co`).
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Supabase anonymous public key.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// True when Supabase credentials have been provided at compile time.
  /// Spec 001 leaves Supabase wired but not connected; later phases use this
  /// gate to decide whether to call `Supabase.initialize`.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
