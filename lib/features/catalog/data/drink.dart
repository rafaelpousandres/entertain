/// Domain model and draft for a catalog `drinks` row (Spec 014 §2.2, refined by
/// Spec 016 §3).
///
/// A drink is bought in whole units of a named denomination (bottle, can,
/// jug…). Unlike a prepared dish it has **no servings and does not scale** by
/// guests: a drink = name + supplier category + denomination + photo. The unit
/// quantity is set manually per event (see [EventDrink]).
library;

import 'denomination.dart';

class Drink {
  const Drink({
    required this.id,
    required this.groupId,
    required this.name,
    this.supplierCategoryId,
    this.denomination = 'bottle',
    this.nameEn,
  });

  final String id;
  final String groupId;

  /// Display name resolved to the app locale by the repository (Spec 025 A.4).
  final String name;

  /// Supplier category the drink is ordered from (resolved to a concrete
  /// supplier at order time, Spec 013). Nullable.
  final String? supplierCategoryId;

  /// Denomination code (see [Denomination]); rendered singular/plural per locale.
  final String denomination;

  /// English name (Spec 025 D2). Attached by the repository; null when unfilled.
  final String? nameEn;

  factory Drink.fromRow(
    Map<String, dynamic> row, {
    String? displayName,
    String? nameEn,
  }) {
    return Drink(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      name: displayName ?? row['name'] as String,
      supplierCategoryId: row['supplier_category_id'] as String?,
      denomination: parseDenomination(row['denomination'] as String?).wire,
      nameEn: nameEn,
    );
  }

  static const String selectColumns =
      'id, group_id, name, supplier_category_id, denomination';
}

/// Mutable editor view of a drink.
class DrinkDraft {
  DrinkDraft({
    required this.name,
    this.supplierCategoryId,
    this.denomination = 'bottle',
  });

  factory DrinkDraft.empty() => DrinkDraft(name: '');

  factory DrinkDraft.fromDrink(Drink drink) => DrinkDraft(
    name: drink.name,
    supplierCategoryId: drink.supplierCategoryId,
    denomination: drink.denomination,
  );

  String name;
  String? supplierCategoryId;
  String denomination;

  /// Row payload for the `drinks` table. `group_id` is added by the repository.
  Map<String, dynamic> toRow() {
    return {
      'name': name.trim(),
      'supplier_category_id': supplierCategoryId,
      'denomination': denomination,
    };
  }
}
