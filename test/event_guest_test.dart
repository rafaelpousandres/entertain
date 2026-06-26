import 'package:entertain/features/events/data/event_guest.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 023 §1.3/§1.7 — the EventGuest read model + GuestState wire mapping.
void main() {
  test('fromRow parses every field, including invited_at', () {
    final g = EventGuest.fromRow({
      'id': 'g1',
      'name': 'Anna',
      'phone': '+34600111222',
      'email': 'anna@example.test',
      'state': 'confirmat',
      'invited_at': '2026-06-20T10:00:00Z',
    });
    expect(g.id, 'g1');
    expect(g.name, 'Anna');
    expect(g.phone, '+34600111222');
    expect(g.email, 'anna@example.test');
    expect(g.state, GuestState.confirmat);
    expect(g.isInvited, isTrue);
    expect(g.canInvite, isTrue);
  });

  test('blank/absent contact fields become null; not invited; not invitable', () {
    final g = EventGuest.fromRow({
      'id': 'g2',
      'name': 'Bru',
      'phone': '   ',
      'email': null,
      'state': 'pendent',
      'invited_at': null,
    });
    expect(g.phone, isNull);
    expect(g.email, isNull);
    expect(g.hasPhone, isFalse);
    expect(g.hasEmail, isFalse);
    expect(g.canInvite, isFalse);
    expect(g.isInvited, isFalse);
  });

  test('GuestState wire round-trips; unknown/null defaults to pendent', () {
    for (final s in GuestState.values) {
      expect(GuestStateWire.parse(s.wire), s);
    }
    expect(GuestStateWire.parse('confirmat'), GuestState.confirmat);
    expect(GuestStateWire.parse('excusat'), GuestState.excusat);
    expect(GuestStateWire.parse(null), GuestState.pendent);
    expect(GuestStateWire.parse('garbage'), GuestState.pendent);
  });
}
