/// Supplier selection at purchase (Specification 013 §2.3).
///
/// The single, shared place that turns a category + the group's configured
/// suppliers into "which supplier (if any) does this order go to". Kept out of
/// the shopping panel and the message screen on purpose: Spec 014 (prepared
/// dishes / drinks) reuses it verbatim — those are categories with several
/// suppliers, exactly like butcher / fishmonger.
library;

import 'group_supplier_setting.dart';

/// The suppliers configured for one category, with the resolution rules the
/// purchase flow needs.
class SupplierResolution {
  const SupplierResolution(this.suppliers, this.defaultSupplier);

  /// Suppliers for the category, ordered for display: the default first, then
  /// by name (case-insensitive, unnamed last), then by id for stability.
  final List<GroupSupplierSetting> suppliers;

  /// The flagged default for the category, or null when none is configured
  /// (no suppliers at all, or several with none marked default).
  final GroupSupplierSetting? defaultSupplier;

  bool get isEmpty => suppliers.isEmpty;
  bool get isSingle => suppliers.length == 1;
  bool get isMultiple => suppliers.length > 1;

  /// The supplier to use without asking (Spec §2.3): the sole supplier when
  /// there is exactly one; otherwise the default — which may be null when
  /// several exist and none is flagged, in which case the caller prompts.
  GroupSupplierSetting? get preselected =>
      isSingle ? suppliers.first : defaultSupplier;

  /// Whether order generation must prompt for a choice: only when more than one
  /// supplier exists (one → silent; none → works without a supplier).
  bool get requiresChoice => isMultiple;
}

/// Resolves the suppliers configured for [categoryId] out of [all] (the
/// group's full supplier list, e.g. from `groupSuppliersByCategoryProvider`
/// flattened, or a repository result).
SupplierResolution resolveSuppliersForCategory(
  Iterable<GroupSupplierSetting> all,
  String categoryId,
) {
  final suppliers = [
    for (final s in all)
      if (s.supplierCategoryId == categoryId) s,
  ]..sort(_byDefaultThenName);

  GroupSupplierSetting? defaultSupplier;
  for (final s in suppliers) {
    if (s.isDefault) {
      defaultSupplier = s;
      break;
    }
  }
  return SupplierResolution(suppliers, defaultSupplier);
}

int _byDefaultThenName(GroupSupplierSetting a, GroupSupplierSetting b) {
  if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
  final na = a.supplierName?.trim();
  final nb = b.supplierName?.trim();
  if ((na == null || na.isEmpty) != (nb == null || nb.isEmpty)) {
    // Unnamed suppliers sort after named ones.
    return (na == null || na.isEmpty) ? 1 : -1;
  }
  if (na != null && na.isNotEmpty && nb != null && nb.isNotEmpty) {
    final byName = na.toLowerCase().compareTo(nb.toLowerCase());
    if (byName != 0) return byName;
  }
  return a.id.compareTo(b.id);
}
