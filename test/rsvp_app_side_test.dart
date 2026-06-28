import 'package:entertain/features/events/data/event_guest.dart';
import 'package:entertain/features/events/data/guest_invitation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 029 (app side) — the RSVP link composition and the guest row's new
/// token + dietary fields.
void main() {
  group('rsvpUrl', () {
    test('composes base + token + lang', () {
      expect(
        rsvpUrl(
          baseUrl: 'https://abc.supabase.co',
          token: 'tok-123',
          langCode: 'ca',
        ),
        'https://abc.supabase.co/functions/v1/rsvp?token=tok-123&lang=ca',
      );
    });

    test('null when no base URL or no token (link omitted)', () {
      expect(rsvpUrl(baseUrl: '', token: 'tok', langCode: 'ca'), isNull);
      expect(rsvpUrl(baseUrl: 'https://x', token: null, langCode: 'ca'), isNull);
      expect(rsvpUrl(baseUrl: 'https://x', token: '', langCode: 'ca'), isNull);
    });
  });

  group('EventGuest.fromRow — token + dietary flags', () {
    test('parses rsvp_token and the 3 diet booleans', () {
      final g = EventGuest.fromRow({
        'id': 'g1',
        'name': 'Anna',
        'state': 'confirmat',
        'invited_at': null,
        'rsvp_token': 'tok-xyz',
        'diet_vegetarian': false,
        'diet_vegan': true,
        'diet_gluten_free': true,
      });
      expect(g.rsvpToken, 'tok-xyz');
      expect(g.dietVegan, isTrue);
      expect(g.dietGlutenFree, isTrue);
      expect(g.dietVegetarian, isFalse);
      expect(g.hasDietaryFlags, isTrue);
    });

    test('defaults to no flags when columns absent/false', () {
      final g = EventGuest.fromRow({
        'id': 'g2',
        'name': 'Pau',
        'state': 'pendent',
        'invited_at': null,
      });
      expect(g.rsvpToken, isNull);
      expect(g.hasDietaryFlags, isFalse);
    });
  });
}
