import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Spec 035 §D — in-app account deletion.
///
/// The deletion itself is server-side (the `delete-account` Edge Function):
/// it identifies the account from the session's JWT, so nothing here says
/// *which* account to delete. This class only triggers it and then forgets the
/// account on the device.
class AccountRepository {
  AccountRepository(this._client);

  final SupabaseClient _client;

  /// Must match `CONFIRM_TOKEN` in the Edge Function: a call without it is
  /// rejected, so no stray request can ever delete an account.
  static const String confirmToken = 'DELETE_MY_ACCOUNT';

  /// Permanently deletes the signed-in account and all its data. Throws when
  /// the server did not confirm the deletion; a retry is always safe (the
  /// function picks up wherever a previous attempt stopped).
  Future<void> deleteAccount() async {
    final res = await _client.functions.invoke(
      'delete-account',
      body: const {'confirm': confirmToken},
    );
    final data = res.data;
    if (data is! Map || data['deleted'] != true) {
      throw StateError('delete-account did not confirm the deletion');
    }
  }

  /// Drops what the device still holds for the deleted account: the session
  /// (locally only — the user no longer exists server-side, so there is
  /// nothing to revoke there) and every device-local preference.
  Future<void> forgetLocalAccount() async {
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('account: local sign-out failed — $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('account: clearing local preferences failed — $e');
    }
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(Supabase.instance.client);
});
