import 'package:shared_preferences/shared_preferences.dart';

/// Spec 026 A.2 — local persistence for the hints-on-entry surface.
///
/// Two device-local flags (SharedPreferences, like [EventTabStore]):
///  * `hints_enabled` — the "show hints on entry" preference, **default ON**.
///    The checkbox on the screen and the Settings toggle both write it.
///  * `hints_welcome_seen` — whether the one-time welcome hint has been shown,
///    so the first-ever open greets the user and later opens go straight to a
///    random tip. Default OFF (not yet seen).
class HintsPrefs {
  const HintsPrefs._();

  static const String _enabledKey = 'hints_enabled';
  static const String _welcomeSeenKey = 'hints_welcome_seen';

  static Future<bool> readEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  static Future<void> writeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  static Future<bool> readWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_welcomeSeenKey) ?? false;
  }

  static Future<void> markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeSeenKey, true);
  }
}
