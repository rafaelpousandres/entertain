import '../data/reference_data.dart';

const List<UnitMagnitude> _magnitudeOrder = [
  UnitMagnitude.mass,
  UnitMagnitude.volume,
  UnitMagnitude.count,
  UnitMagnitude.package,
];

int _compareUnits(Unit a, Unit b) {
  final ma = _magnitudeOrder.indexOf(a.magnitude);
  final mb = _magnitudeOrder.indexOf(b.magnitude);
  if (ma != mb) return ma.compareTo(mb);
  return a.code.compareTo(b.code);
}

/// Units ordered for a picker: grouped by magnitude (mass, volume, count,
/// package) and then by code, so the ingredient editor's default-unit list
/// reads in a stable, sensible order.
List<Unit> orderUnitsForDisplay(List<Unit> units) {
  final sorted = [...units]..sort(_compareUnits);
  return sorted;
}

/// Units selectable for a dish/event line given the ingredient's default
/// unit (Specification 004 §3.6). Mass (g/kg) and volume (ml/l) convert
/// within their family, so every unit of that magnitude is offered; count
/// and package units are isolated, so only the ingredient's own unit is
/// allowed.
List<Unit> unitsForFamily(List<Unit> all, Unit defaultUnit) {
  if (defaultUnit.magnitude.isConvertibleFamily) {
    final family = all
        .where((u) => u.magnitude == defaultUnit.magnitude)
        .toList()
      ..sort(_compareUnits);
    return family;
  }
  return [defaultUnit];
}
