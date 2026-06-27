import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'hint.dart';
import 'hints_prefs.dart';
import 'hints_repository.dart';

final hintsRepositoryProvider = Provider<HintsRepository>((ref) {
  return HintsRepository(Supabase.instance.client);
});

/// The DB-backed hint set localized to [localeCode]. Reference content, fetched
/// once per locale and cached for the session.
final hintsProvider = FutureProvider.family<List<Hint>, String>((
  ref,
  localeCode,
) async {
  return ref.watch(hintsRepositoryProvider).listHints(localeCode);
});

/// Spec 026 A.2 — the persisted "show hints on entry" preference (default ON).
/// Both the on-entry checkbox and the Settings toggle write through [set].
final hintsEnabledProvider =
    AsyncNotifierProvider<HintsEnabledNotifier, bool>(HintsEnabledNotifier.new);

class HintsEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => HintsPrefs.readEnabled();

  Future<void> set(bool value) async {
    state = AsyncData(value);
    await HintsPrefs.writeEnabled(value);
  }
}

/// In-memory guard: the entry hint is shown **once per app open**, not on every
/// navigation back to the home. Reset on each cold start.
final hintsSessionShownProvider =
    NotifierProvider<HintsSessionShownNotifier, bool>(
      HintsSessionShownNotifier.new,
    );

class HintsSessionShownNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markShown() => state = true;
}
