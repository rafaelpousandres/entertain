import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Bootstrap state of the backend connection. Phase 0 doesn't render real
/// data, so this is the surface the placeholder screen uses to prove the
/// Supabase wiring actually works.
enum BackendStatus { notConfigured, connecting, connected, failed }

class BackendBootstrap {
  const BackendBootstrap(this.status, {this.userId, this.errorMessage});

  final BackendStatus status;

  /// Anonymous-user id once the session is established. Useful for the
  /// connectivity check the user runs against the dashboard.
  final String? userId;

  /// Human-readable error from Supabase / network — surfaced only for
  /// developer-facing diagnostics, never logged with PII.
  final String? errorMessage;
}

/// Initialises the Supabase client at app startup. The client itself does
/// no network I/O on init; it only sets up storage for sessions. Real
/// connectivity is proved by [ensureSession].
///
/// Returns true when initialisation ran (credentials were provided).
Future<bool> initSupabase() async {
  if (!Env.hasSupabase) return false;

  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  } on AssertionError {
    // Already initialised in a previous hot-restart cycle — fine.
  }
  return true;
}

/// Ensures the caller has an anonymous Supabase session. Doubles as the
/// temporary connectivity check from spec 002 §2.4.
Future<BackendBootstrap> ensureSession() async {
  if (!Env.hasSupabase) {
    return const BackendBootstrap(BackendStatus.notConfigured);
  }

  try {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      await client.auth.signInAnonymously();
    }
    return BackendBootstrap(
      BackendStatus.connected,
      userId: client.auth.currentUser?.id,
    );
  } catch (e) {
    return BackendBootstrap(
      BackendStatus.failed,
      errorMessage: e.toString(),
    );
  }
}

/// Single-shot provider that runs the session check once per app session
/// and caches the result. Watched by the placeholder screen.
final backendBootstrapProvider = FutureProvider<BackendBootstrap>((ref) {
  return ensureSession();
});
