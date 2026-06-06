/// System reference catalogs read by the catalog screens: `units` and
/// `supplier_categories`. Both are app-provided content — their display
/// names come from the `translations` table in the current locale (Catalan
/// in the MVP), not from a column on the row. Editing these catalogs is out
/// of scope for this screen group (data model §4), so they are read-only.
library;

/// Magnitude of a unit. Drives the convertible-family rule in the line
/// editor: `mass` (g/kg) and `volume` (ml/l) convert within themselves;
/// `count` and `package` units stand alone.
enum UnitMagnitude { mass, volume, count, package }

extension UnitMagnitudeWire on UnitMagnitude {
  static UnitMagnitude parse(String value) => switch (value) {
    'mass' => UnitMagnitude.mass,
    'volume' => UnitMagnitude.volume,
    'count' => UnitMagnitude.count,
    _ => UnitMagnitude.package,
  };

  /// Whether units of this magnitude form a convertible family (so the line
  /// editor may offer every unit of the magnitude). `count` / `package`
  /// units are isolated, so only the ingredient's own unit is allowed.
  bool get isConvertibleFamily =>
      this == UnitMagnitude.mass || this == UnitMagnitude.volume;
}

class Unit {
  const Unit({
    required this.id,
    required this.code,
    required this.magnitude,
    required this.name,
    this.omitInDisplay = false,
  });

  final String id;
  final String code;
  final UnitMagnitude magnitude;

  /// Translated display name in the current locale (falls back to [code]).
  final String name;

  /// Fixes §2.3: when true, the supplier-message composer omits this unit (and
  /// the "de" connector) so a countable line reads "3 ous", not "3 unitats de
  /// ous". Set for the generic "unitat" unit; a model flag so other units can
  /// be suppressed the same way without code changes.
  final bool omitInDisplay;

  static const String selectColumns = 'id, code, magnitude, omit_in_display';
}

class SupplierCategory {
  const SupplierCategory({
    required this.id,
    required this.code,
    required this.name,
  });

  final String id;
  final String code;

  /// Translated display name in the current locale (falls back to [code]).
  final String name;

  static const String selectColumns = 'id, code';
}
