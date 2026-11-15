import 'package:entertain/features/events/data/events_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 034 §D1 — pins what a duplicated event carries over per row. The
/// repository inserts exactly these maps, so they are the contract.
void main() {
  group('duplicatedEventDishRow', () {
    test('a bought dish keeps its acquisition snapshot', () {
      final row = duplicatedEventDishRow({
        'id': 'old-dish',
        'source_dish_id': 'dish-1',
        'dish_name': 'Truita',
        'category': 'starter',
        'servings': 12,
        'sort_order': 2,
        'acquisition_mode': 'bought',
        'supplier_category_id': 'cat-1',
        'servings_per_unit': 4,
      }, newEventId: 'new-event');

      expect(row['event_id'], 'new-event');
      expect(row['acquisition_mode'], 'bought');
      expect(row['supplier_category_id'], 'cat-1');
      expect(row['servings_per_unit'], 4);
      expect(row['servings'], 12);
      expect(row['sort_order'], 2);
      // The source row id must never leak into the copy.
      expect(row.containsKey('id'), isFalse);
    });

    test('a cooked dish stays cooked with no per-unit value', () {
      final row = duplicatedEventDishRow({
        'source_dish_id': 'dish-2',
        'dish_name': 'Arròs',
        'category': 'main',
        'servings': 8,
        'sort_order': 0,
        'acquisition_mode': 'cooked',
        'supplier_category_id': null,
        'servings_per_unit': null,
      }, newEventId: 'new-event');

      expect(row['acquisition_mode'], 'cooked');
      expect(row['servings_per_unit'], isNull);
    });
  });

  test('duplicatedEventDrinkRow copies the snapshot and leaves state to the '
      'column default', () {
    final row = duplicatedEventDrinkRow({
      'source_drink_id': 'drink-1',
      'drink_name': 'Cava',
      'supplier_category_id': 'cat-2',
      'quantity': 6,
      'denomination': 'bottle',
      'sort_order': 1,
      'state': 'received',
    }, newEventId: 'new-event');

    expect(row['event_id'], 'new-event');
    expect(row['drink_name'], 'Cava');
    expect(row['quantity'], 6);
    expect(row['denomination'], 'bottle');
    expect(row.containsKey('state'), isFalse);
  });

  group('duplicatedGuestRow', () {
    final source = {
      'id': 'guest-old',
      'name': 'Marta',
      'phone': '+34600000000',
      'email': 'marta@example.com',
      'state': 'confirmat',
      'invited_at': '2026-10-01T10:00:00Z',
      'rsvp_token': 'token-old',
      'diet_vegetarian': true,
      'diet_vegan': false,
      'diet_gluten_free': true,
    };

    test('carries identity, contact and dietary fields', () {
      final row = duplicatedGuestRow(
        source,
        newEventId: 'new-event',
        groupId: 'group-1',
      );

      expect(row['event_id'], 'new-event');
      expect(row['group_id'], 'group-1');
      expect(row['name'], 'Marta');
      expect(row['phone'], '+34600000000');
      expect(row['email'], 'marta@example.com');
      expect(row['diet_vegetarian'], isTrue);
      expect(row['diet_vegan'], isFalse);
      expect(row['diet_gluten_free'], isTrue);
    });

    test('restarts the RSVP: pending, not invited, fresh token', () {
      final row = duplicatedGuestRow(
        source,
        newEventId: 'new-event',
        groupId: 'group-1',
      );

      expect(row['state'], 'pendent');
      expect(row.containsKey('invited_at'), isFalse);
      // Omitted so the column default mints a new unique token.
      expect(row.containsKey('rsvp_token'), isFalse);
      expect(row.containsKey('id'), isFalse);
    });
  });
}
