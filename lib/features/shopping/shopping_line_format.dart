/// Display helper for a shopping line's unit (Spec 014).
///
/// Ingredient lines show their unit's name (or nothing when the unit is flagged
/// `omit_in_display`, e.g. "3 ous"). A prepared-dish / drink purchase line shows
/// its free-text purchase unit ("3 safates"), or a localised "racions" when it
/// is expressed in scaled servings ("12 racions").
library;

import '../../l10n/app_localizations.dart';
import '../catalog/data/reference_data.dart';
import 'data/shopping_models.dart';

/// The unit name to render next to [quantity] for a line, or null to omit it.
/// [omitGenericUnit] keeps the panel's existing behaviour where the row always
/// shows a real unit name (unlike the message, which suppresses the generic
/// "unitat"): pass false for the panel row, true for message/list text.
String? shoppingUnitName({
  required ShoppingLineKind kind,
  required String? unitId,
  required String? purchaseUnitLabel,
  required Map<String, Unit> unitsById,
  required AppLocalizations l10n,
  bool omitGenericUnit = true,
}) {
  if (kind != ShoppingLineKind.ingredient) {
    return purchaseUnitLabel ?? l10n.shoppingServingsUnit;
  }
  final unit = unitsById[unitId];
  if (unit == null) return null;
  if (omitGenericUnit && unit.omitInDisplay) return null;
  return unit.name;
}
