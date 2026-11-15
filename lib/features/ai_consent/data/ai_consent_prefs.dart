import 'package:shared_preferences/shared_preferences.dart';

/// Spec 035 §E — whether the user has agreed to their requests being sent to
/// the third-party AI provider (App Review Guideline 5.1.2(i): disclose the
/// sharing and obtain explicit permission first).
///
/// Device-local, like [HintsPrefs]: asked once per install, and again after an
/// account deletion (which clears every local preference).
class AiConsentPrefs {
  const AiConsentPrefs._();

  static const String _key = 'ai_consent_given';

  static Future<bool> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> grant() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
