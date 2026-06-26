import 'package:entertain/features/events/data/event.dart';
import 'package:entertain/features/events/data/event_guest.dart';
import 'package:entertain/features/events/data/guest_invitation.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:entertain/util/contact_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Spec 023 §1.5/§1.6 — pure guest helpers: invitation prefill, over-capacity,
/// available channels, contact mapping, grouping/subtotals.
Event _event({
  String title = 'Sopar de Sant Joan',
  DateTime? date,
  TimeOfDay? time,
  String? place,
  int guestCount = 8,
}) => Event(
  id: 'e1',
  groupId: 'g1',
  title: title,
  type: EventType.dinner,
  format: EventFormat.seated,
  guestCount: guestCount,
  createdAt: DateTime(2026, 1, 1),
  eventDate: date,
  eventTime: time,
  locationName: place,
);

EventGuest _guest(GuestState state, {String? phone, String? email}) => EventGuest(
  id: 'x',
  name: 'X',
  state: state,
  phone: phone,
  email: email,
);

void main() {
  late AppLocalizations l10n;
  const locale = Locale('en');
  setUpAll(() async {
    await initializeDateFormatting();
    l10n = await AppLocalizations.delegate.load(locale);
  });

  group('composeInvitationPrefill', () {
    test('includes title, when (date+time) and where when present', () {
      final text = composeInvitationPrefill(
        l10n,
        locale,
        _event(
          date: DateTime(2026, 6, 23),
          time: const TimeOfDay(hour: 21, minute: 0),
          place: 'Mas Pous',
        ),
      );
      expect(text, contains('Sopar de Sant Joan'));
      expect(text, contains('Mas Pous'));
      // when line carries the date + the time.
      expect(text, contains('21:00'));
      expect(text, contains(l10n.invitationGreeting));
    });

    test('omits the when/where lines when the event has no date/place', () {
      final text = composeInvitationPrefill(l10n, locale, _event());
      expect(text, contains('Sopar de Sant Joan'));
      // No "When:" / "Where:" prefixes appear (their lines are skipped).
      expect(text.contains('When:'), isFalse);
      expect(text.contains('Where:'), isFalse);
    });
  });

  test('isOverCapacity: only when confirmed strictly exceeds the planned count', () {
    expect(isOverCapacity(confirmedCount: 9, guestCount: 8), isTrue);
    expect(isOverCapacity(confirmedCount: 8, guestCount: 8), isFalse);
    expect(isOverCapacity(confirmedCount: 3, guestCount: 8), isFalse);
  });

  group('availableInviteChannels', () {
    test('phone only → text; email only → email', () {
      expect(availableInviteChannels(hasPhone: true, hasEmail: false),
          [InviteChannel.text]);
      expect(availableInviteChannels(hasPhone: false, hasEmail: true),
          [InviteChannel.email]);
    });
    test('both → both (text first); neither → empty', () {
      expect(availableInviteChannels(hasPhone: true, hasEmail: true),
          [InviteChannel.text, InviteChannel.email]);
      expect(availableInviteChannels(hasPhone: false, hasEmail: false), isEmpty);
    });
  });

  test('guestFieldsFromContact maps name + first phone + first email', () {
    final r = guestFieldsFromContact(const PickedContact(
      name: 'Carla',
      phones: ['+34600111222', '+34699888777'],
      emails: ['carla@example.test'],
    ));
    expect(r.name, 'Carla');
    expect(r.phone, '+34600111222');
    expect(r.email, 'carla@example.test');

    final empty = guestFieldsFromContact(
      const PickedContact(name: null, phones: [], emails: []),
    );
    expect(empty.name, isNull);
    expect(empty.phone, isNull);
    expect(empty.email, isNull);
  });

  test('groupGuestsByState buckets all states with correct subtotals', () {
    final guests = [
      _guest(GuestState.pendent),
      _guest(GuestState.confirmat),
      _guest(GuestState.confirmat),
      _guest(GuestState.excusat),
    ];
    final byState = groupGuestsByState(guests);
    expect(byState[GuestState.pendent]!.length, 1);
    expect(byState[GuestState.confirmat]!.length, 2);
    expect(byState[GuestState.excusat]!.length, 1);
    // Grand total is the input length; every state key is present.
    expect(byState.values.expand((x) => x).length, 4);
    expect(byState.keys.toSet(), GuestState.values.toSet());
  });
}
