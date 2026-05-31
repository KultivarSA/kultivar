/// Supabase project credentials, sourced from `--dart-define` at build time.
///
/// NEVER hardcode real keys into this file.  Pass them via the Flutter build
/// command or your IDE's run configuration:
///
/// ```sh
/// flutter run \
///   --dart-define=SUPABASE_URL=https://your-project.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGc...
/// ```
///
/// For local development, the recommended workflow is to put values in a
/// gitignored `env.json` at the project root and use:
///
/// ```sh
/// flutter run --dart-define-from-file=env.json
/// ```
///
/// A template lives in `env.example.json`.
///
/// ## Why this matters
///
/// The Supabase anon key isn't a server-side secret — it's intended to be
/// embedded in clients and protected by Row-Level Security policies on
/// every table.  However, committing it to source still:
///   • leaks it to anyone with read access to the repo,
///   • makes rotation painful (rebuild + re-commit + re-deploy),
///   • blurs the line between dev / staging / prod environments.
///
/// Reading from `String.fromEnvironment` solves all three.  CI/CD injects
/// the right values per environment; developers use their own `env.json`
/// for testing; rotation is a single dashboard action.
///
/// ## Behaviour when unconfigured
///
/// When either value is empty, [isConfigured] returns false and
/// `main.dart` skips `Supabase.initialize()`.  All community features
/// (benchmark fetch / submit) gracefully degrade to no-ops — the app
/// runs fine without any backend wired up, which is the same behaviour
/// users see when offline.
class SupabaseConfig {
  /// Supabase project URL — `https://<project-ref>.supabase.co`
  static const String url = String.fromEnvironment('SUPABASE_URL');

  /// Supabase anon (public) key — safe for client embedding when RLS is on.
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// True when both values were supplied at build time.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
