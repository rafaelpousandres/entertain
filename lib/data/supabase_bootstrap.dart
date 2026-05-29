import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Reasons the startup bootstrap can fail before the home screen renders.
/// The UI maps any of them to the same generic "couldn't connect" message,
/// but keeping them typed makes diagnostics easier in logs.
enum StartupErrorKind { notConfigured, network }

class StartupError implements Exception {
  const StartupError(this.kind, [this.cause]);

  final StartupErrorKind kind;
  final Object? cause;

  @override
  String toString() => 'StartupError($kind, cause: $cause)';
}

/// Initialises the Supabase client at app startup. Safe to call more than
/// once across hot restarts.
Future<void> initSupabase() async {
  if (!Env.hasSupabase) return;

  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  } on AssertionError {
    // Already initialised in a previous hot-restart cycle — fine.
  }
}

/// Ensures the caller has an anonymous Supabase session. The session
/// triggers the auto-provisioning trigger from spec 002, so by the time
/// this returns the user has a `group` and a `membership` to work with.
Future<void> _ensureSession() async {
  if (!Env.hasSupabase) {
    throw const StartupError(StartupErrorKind.notConfigured);
  }
  try {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      await client.auth.signInAnonymously();
    }
  } catch (e) {
    throw StartupError(StartupErrorKind.network, e);
  }
}

/// Single source of truth for "is the backend ready to serve the home
/// screen?". Watched by [BootstrapGate]; invalidate it to retry.
final appBootstrapProvider = FutureProvider<void>((ref) async {
  await initSupabase();
  await _ensureSession();
});
