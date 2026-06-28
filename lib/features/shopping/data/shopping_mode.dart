/// Spec 028 — the Compra tab's two sub-modes and the persisted default.
///
/// Both modes operate on the SAME shopping data and state machine; only the
/// presentation differs (Comandes = the full ordering screen; En persona = a
/// simplified checklist). The default is a device-local preference (like the
/// hints toggle, [HintsPrefs]) — it only chooses which tab opens first; the user
/// switches freely within a session.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Compra tab's sub-mode.
enum ShoppingMode { comandes, enPersona }

/// Device-local store for the default shopping sub-mode.
class ShoppingModePrefs {
  static const String _key = 'shopping_mode_default';

  static Future<ShoppingMode> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) == ShoppingMode.enPersona.name
        ? ShoppingMode.enPersona
        : ShoppingMode.comandes; // default: ordering
  }

  static Future<void> write(ShoppingMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

/// The default sub-mode the Compra tab opens in (Spec 028 §A). Mirrors the
/// hints-toggle notifier pattern.
final shoppingModeProvider =
    AsyncNotifierProvider<ShoppingModeNotifier, ShoppingMode>(
  ShoppingModeNotifier.new,
);

class ShoppingModeNotifier extends AsyncNotifier<ShoppingMode> {
  @override
  Future<ShoppingMode> build() => ShoppingModePrefs.read();

  Future<void> set(ShoppingMode mode) async {
    state = AsyncData(mode);
    await ShoppingModePrefs.write(mode);
  }
}
