/// Display helper for a shopping line's unit (Spec 014, refined by Spec 016).
///
/// Ingredient lines show their unit's name (or nothing when the unit is flagged
/// `omit_in_display`, e.g. "3 ous"). A prepared-dish purchase line shows a bare
/// count with no unit ("3 × Canelons"). A drink line shows its denomination
/// noun, agreeing with the count ("2 ampolles").
library;

import '../../l10n/app_localizations.dart';
import '../catalog/data/denomination.dart';
import '../catalog/data/reference_data.dart';
import 'data/shopping_models.dart';

/// The unit name to render next to [count] for a line, or null to omit it (the
/// caller renders "{qty} {unit}", or just "{qty}" when this is null).
///
/// [count] is the line quantity, needed for the drink denomination's
/// singular/plural agreement. [omitGenericUnit] keeps the panel's existing
/// behaviour where the row always shows a real unit name (unlike the message,
/// which suppresses the generic "unitat"): pass false for the panel row, true
/// for message/list text.
String? shoppingUnitName({
  required ShoppingLineKind kind,
  required String? unitId,
  required String? denomination,
  required int count,
  required Map<String, Unit> unitsById,
  required AppLocalizations l10n,
  bool omitGenericUnit = true,
}) {
  switch (kind) {
    case ShoppingLineKind.preparedDish:
      // Spec 016 §2.3: a bought dish is a bare count with the dish name, no unit.
      return null;
    case ShoppingLineKind.drink:
      // Spec 016 §3.4: the denomination noun, agreeing with the count.
      return denominationUnitNoun(l10n, denomination ?? 'bottle', count);
    case ShoppingLineKind.ingredient:
      final unit = unitsById[unitId];
      if (unit == null) return null;
      if (omitGenericUnit && unit.omitInDisplay) return null;
      return unit.name;
  }
}
