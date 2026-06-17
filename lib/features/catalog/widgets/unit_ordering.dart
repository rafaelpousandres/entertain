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
/// package) and then by code, so a unit list reads in a stable, sensible
/// order. This is the full catalog — a dish/event line may use any unit
/// regardless of the ingredient's default, since the line is where the recipe
/// decides how to express the amount ("100 g de tomàquet" vs "3 tomàquets",
/// "750 ml de vi" vs "1 ampolla"). The app can't know whether a countable
/// ingredient is solid or liquid, so it offers every unit and lets the user
/// pick the right one.
List<Unit> orderUnitsForDisplay(List<Unit> units) {
  final sorted = [...units]..sort(_compareUnits);
  return sorted;
}
