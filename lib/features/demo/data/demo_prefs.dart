import 'package:shared_preferences/shared_preferences.dart';

/// Spec 033 §A.5 — device-local dismiss state for the "start from scratch"
/// banner. Closing the banner (X) hides it but keeps the data; the flag is per
/// device, like [HintsPrefs].
class DemoPrefs {
  const DemoPrefs._();

  static const String _dismissedKey = 'demo_banner_dismissed';

  static Future<bool> readDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dismissedKey) ?? false;
  }

  static Future<void> writeDismissed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, value);
  }
}
