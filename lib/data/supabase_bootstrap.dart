import 'dart:ui' show PlatformDispatcher;

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
      // Spec 033 §A.4: a brand-new user's group is seeded with the demo
      // dataset in their device language. One-shot + guarded server-side;
      // non-fatal, so a seeding hiccup never blocks first launch.
      await _seedDemoForNewUser(client);
    }
  } catch (e) {
    throw StartupError(StartupErrorKind.network, e);
  }
}

/// Best-effort demo seed for a just-created anonymous user. Picks the device
/// language (ca/es/en, English fallback); failures are swallowed.
Future<void> _seedDemoForNewUser(SupabaseClient client) async {
  try {
    final lang = PlatformDispatcher.instance.locale.languageCode;
    final locale = const {'ca', 'es', 'en'}.contains(lang) ? lang : 'en';
    await client.rpc('seed_demo', params: {'p_locale': locale});
  } catch (_) {
    // Non-fatal: the user simply starts without the example dataset.
  }
}

/// Single source of truth for "is the backend ready to serve the home
/// screen?". Watched by [BootstrapGate]; invalidate it to retry.
final appBootstrapProvider = FutureProvider<void>((ref) async {
  await initSupabase();
  await _ensureSession();
});
