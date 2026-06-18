/// Drink denominations (Spec 016 §3.3).
///
/// A drink is bought in whole units of a named denomination (bottle, can,
/// jug…). The drink stores a stable **code**; the app renders the correct
/// singular/plural per locale and count via ICU plurals in the ARB files (not
/// free text — this avoids Catalan plural edge cases). The picker offers the
/// denominations by their localised singular.
library;

import '../../../l10n/app_localizations.dart';

/// The predefined, system list of denomination codes. Extendable: add a value
/// here and the matching ARB messages (denomination<Code> + <Code>Name).
enum Denomination { bottle, can, jug, unit, pack, litre }

extension DenominationWire on Denomination {
  /// Stable code persisted in `drinks.denomination` / `event_drinks`.
  String get wire => switch (this) {
    Denomination.bottle => 'bottle',
    Denomination.can => 'can',
    Denomination.jug => 'jug',
    Denomination.unit => 'unit',
    Denomination.pack => 'pack',
    Denomination.litre => 'litre',
  };
}

/// Parses a stored code, defaulting to [Denomination.bottle] for unknown /
/// null values so a stray code never crashes rendering.
Denomination parseDenomination(String? code) => switch (code) {
  'can' => Denomination.can,
  'jug' => Denomination.jug,
  'unit' => Denomination.unit,
  'pack' => Denomination.pack,
  'litre' => Denomination.litre,
  _ => Denomination.bottle,
};

/// The default denomination for a new drink (matches the DB column default).
const Denomination defaultDenomination = Denomination.bottle;

/// Localised singular noun for the picker, e.g. "ampolla" (ca), "botella" (es),
/// "bottle" (en). No count.
String denominationName(AppLocalizations l10n, String code) =>
    switch (parseDenomination(code)) {
      Denomination.bottle => l10n.denominationBottleName,
      Denomination.can => l10n.denominationCanName,
      Denomination.jug => l10n.denominationJugName,
      Denomination.unit => l10n.denominationUnitName,
      Denomination.pack => l10n.denominationPackName,
      Denomination.litre => l10n.denominationLitreName,
    };

/// Localised count + denomination via ICU plural, e.g. "2 ampolles",
/// "1 ampolla". Used by the event Begudes row.
String denominationCount(AppLocalizations l10n, String code, int count) =>
    switch (parseDenomination(code)) {
      Denomination.bottle => l10n.denominationBottle(count),
      Denomination.can => l10n.denominationCan(count),
      Denomination.jug => l10n.denominationJug(count),
      Denomination.unit => l10n.denominationUnit(count),
      Denomination.pack => l10n.denominationPack(count),
      Denomination.litre => l10n.denominationLitre(count),
    };

/// The bare denomination noun agreeing with [count] (singular for 1, the
/// locale's plural otherwise), e.g. "ampolla" / "ampolles". Derived from the
/// ICU plural message ([denominationCount]) so the singular/plural forms have a
/// single source of truth; the leading count token is stripped. Used by the
/// shopping pipeline, which renders the count separately ("{qty} {noun}").
String denominationUnitNoun(AppLocalizations l10n, String code, int count) {
  final full = denominationCount(l10n, code, count);
  final space = full.indexOf(' ');
  return space < 0 ? full : full.substring(space + 1);
}
