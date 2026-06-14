import 'package:entertain/features/events/data/event_tab_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Spec 011 §2.7 — each event remembers its last active detail tab on this
/// device. The store reads/writes `event_last_tab:{eventId}` and defaults a
/// never-seen event to Menu.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EventTabStore (§2.7)', () {
    test('an unseen event defaults to the Menu tab (criterion 19)', () async {
      expect(
        await EventTabStore.readTabIndex('evt-new'),
        EventTabStore.defaultIndex,
      );
      expect(EventTabStore.defaultIndex, 1); // Menu
    });

    test('a written tab round-trips (criterion 20/21)', () async {
      await EventTabStore.writeTabIndex('evt-1', 2); // Shopping
      expect(await EventTabStore.readTabIndex('evt-1'), 2);

      await EventTabStore.writeTabIndex('evt-1', 0); // Event
      expect(await EventTabStore.readTabIndex('evt-1'), 0);
    });

    test('each event keeps its own tab (criterion 22)', () async {
      await EventTabStore.writeTabIndex('evt-a', 2);
      await EventTabStore.writeTabIndex('evt-b', 0);
      expect(await EventTabStore.readTabIndex('evt-a'), 2);
      expect(await EventTabStore.readTabIndex('evt-b'), 0);
      // A different id with no value still defaults to Menu.
      expect(await EventTabStore.readTabIndex('evt-c'), 1);
    });

    test('out-of-range indices are ignored on write', () async {
      await EventTabStore.writeTabIndex('evt-x', 5);
      expect(
        await EventTabStore.readTabIndex('evt-x'),
        EventTabStore.defaultIndex,
      );
    });

    test('an unrecognised stored value falls back to the default', () async {
      SharedPreferences.setMockInitialValues({
        'event_last_tab:evt-y': 'nonsense',
      });
      expect(
        await EventTabStore.readTabIndex('evt-y'),
        EventTabStore.defaultIndex,
      );
    });
  });
}
