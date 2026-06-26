import 'package:shared_preferences/shared_preferences.dart';

/// Spec 011 §2.7 — remembers each event's last active detail tab on this device.
///
/// Key `event_last_tab:{eventId}` → `event` | `menu` | `guests` | `shopping`.
/// Persistence is **local** (SharedPreferences): it survives app restarts but
/// does not sync across devices — a fresh install starts every event on the
/// default tab. An orphan key left after an event is deleted is harmless and
/// never cleaned up.
class EventTabStore {
  const EventTabStore._();

  static const String _prefix = 'event_last_tab:';

  /// Wire values in the event detail screen's tab order: 0 Event · 1 Menu ·
  /// 2 Guests · 3 Shopping (Spec 023 inserts Convidats before Compra). The
  /// index into this list is the [TabController] index; values are matched by
  /// name, so inserting a tab keeps previously-stored values valid.
  static const List<String> _wire = ['event', 'menu', 'guests', 'shopping'];

  /// Default landing tab for an event with no remembered value: **Menu** (the
  /// most common starting point for planning), index 1.
  static const int defaultIndex = 1;

  /// The remembered tab index for [eventId], or [defaultIndex] (Menu) when none
  /// is stored or the stored value is unrecognised.
  static Future<int> readTabIndex(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('$_prefix$eventId');
    final index = value == null ? -1 : _wire.indexOf(value);
    return index < 0 ? defaultIndex : index;
  }

  /// Persists [index] as the last active tab for [eventId]. Out-of-range indices
  /// are ignored.
  static Future<void> writeTabIndex(String eventId, int index) async {
    if (index < 0 || index >= _wire.length) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$eventId', _wire[index]);
  }
}
