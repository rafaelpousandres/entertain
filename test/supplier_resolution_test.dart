import 'package:entertain/features/shopping/data/group_supplier_setting.dart';
import 'package:entertain/features/shopping/data/message_channel.dart';
import 'package:entertain/features/shopping/data/supplier_resolution.dart';
import 'package:flutter_test/flutter_test.dart';

/// Specification 013 §2.3 — the shared supplier-resolution rule used at order
/// time (and reused by Spec 014): one supplier → use it silently; several →
/// preselect the default; none → no supplier (the order still works).

GroupSupplierSetting supplier(
  String id, {
  String category = 'cat-butcher',
  String? name,
  bool isDefault = false,
  MessageChannel? channel,
  String? phone,
}) {
  return GroupSupplierSetting(
    id: id,
    supplierCategoryId: category,
    supplierName: name,
    isDefault: isDefault,
    channel: channel,
    phoneAddress: phone,
  );
}

void main() {
  group('resolveSuppliersForCategory', () {
    test('no suppliers → empty, no preselection, no prompt', () {
      final r = resolveSuppliersForCategory(const [], 'cat-butcher');
      expect(r.isEmpty, isTrue);
      expect(r.isSingle, isFalse);
      expect(r.isMultiple, isFalse);
      expect(r.requiresChoice, isFalse);
      expect(r.preselected, isNull);
      expect(r.defaultSupplier, isNull);
    });

    test('one supplier → used silently (preselected, no prompt)', () {
      final only = supplier('s1', name: 'Cal Manel');
      final r = resolveSuppliersForCategory([only], 'cat-butcher');
      expect(r.isSingle, isTrue);
      expect(r.requiresChoice, isFalse);
      expect(r.preselected, same(only));
    });

    test('a lone supplier is used even when its is_default flag is false', () {
      // Backfill may leave a sole supplier unflagged; it is still the one used.
      final only = supplier('s1', isDefault: false);
      final r = resolveSuppliersForCategory([only], 'cat-butcher');
      expect(r.preselected, same(only));
    });

    test('several suppliers → default is preselected and prompt is required', () {
      final a = supplier('s1', name: 'A');
      final b = supplier('s2', name: 'B', isDefault: true);
      final c = supplier('s3', name: 'C');
      final r = resolveSuppliersForCategory([a, b, c], 'cat-butcher');
      expect(r.isMultiple, isTrue);
      expect(r.requiresChoice, isTrue);
      expect(r.defaultSupplier, same(b));
      expect(r.preselected, same(b));
    });

    test('several suppliers, none flagged → no preselection (user must pick)', () {
      final a = supplier('s1', name: 'A');
      final b = supplier('s2', name: 'B');
      final r = resolveSuppliersForCategory([a, b], 'cat-butcher');
      expect(r.isMultiple, isTrue);
      expect(r.requiresChoice, isTrue);
      expect(r.preselected, isNull);
    });

    test('only the requested category is considered', () {
      final mine = supplier('s1', category: 'cat-butcher', isDefault: true);
      final other = supplier('s2', category: 'cat-fishmonger', isDefault: true);
      final r = resolveSuppliersForCategory([mine, other], 'cat-butcher');
      expect(r.suppliers, [mine]);
      expect(r.preselected, same(mine));
    });

    test('ordering: default first, then by name, unnamed last', () {
      final unnamed = supplier('s0');
      final zeta = supplier('s1', name: 'Zeta');
      final alpha = supplier('s2', name: 'Alpha');
      final def = supplier('s3', name: 'Mid', isDefault: true);
      final r = resolveSuppliersForCategory(
        [unnamed, zeta, alpha, def],
        'cat-butcher',
      );
      expect(r.suppliers.map((s) => s.id).toList(), ['s3', 's2', 's1', 's0']);
    });
  });
}
