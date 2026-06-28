/// Spec 027 — the fully-resolved view model the PDF builder renders.
///
/// Everything here is already computed against the SAME data the screens show
/// (scaled quantities, grouped shopping, derived dietary status, downscaled
/// image bytes): the builder does no provider access, no network, no
/// recomputation. Keeping the model pure (plain data + pre-resolved strings)
/// lets [EventSummaryPdfBuilder] be unit-tested from fixtures without a
/// `BuildContext` or a live Supabase.
library;

import 'dart:typed_data';

import '../../catalog/data/diet.dart' show DietBadge;

/// Spec 030 §D.5 — the summary file is named after the event, **preserving its
/// spaces and capitals** (e.g. "Dinar Maduixer 260614"). Only filesystem-
/// forbidden chars (and control chars) become a space; whitespace runs collapse.
/// Falls back to a generic name when nothing usable remains. Pure, so it's
/// unit-tested without the share sheet.
String eventSummaryFileBase(String title) {
  final cleaned = title
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.isEmpty ? 'resum' : cleaned;
}

/// One label/value row in the cover's key-data block (e.g. "Data" / "diumenge,
/// 14 de juny"). Only present fields are added, so the cover never shows an
/// empty line (Spec 027 §E common sense).
class SummaryField {
  const SummaryField(this.label, this.value);
  final String label;
  final String value;
}

/// Guests of one RSVP state, with the state's localized label and the members'
/// names. Empty states are dropped before this is built.
class SummaryGuestGroup {
  const SummaryGuestGroup({required this.label, required this.names});
  final String label;
  final List<String> names;
  int get count => names.length;
}

/// One recipe ingredient line: its measure ("2,4 kg", "3 ous") with an optional
/// prep note appended, plus the ingredient's dietary badges.
class SummaryIngredient {
  const SummaryIngredient({required this.text, required this.badges, this.photo});
  final String text;
  final List<DietBadge> badges;

  /// Downscaled JPEG thumbnail of the catalog ingredient (Spec 027 §B: every
  /// ingredient photo is included), or null when it has none.
  final Uint8List? photo;
}

/// A menu dish. A cooked dish carries its ingredients + preparation; a bought
/// dish carries just its supplier (no ingredient/recipe blocks — Spec 027 §E).
class SummaryDish {
  const SummaryDish({
    required this.name,
    required this.servingsLine,
    required this.badges,
    required this.ingredients,
    this.photo,
    this.supplierLine,
    this.preparation,
  });

  final String name;

  /// Pre-formatted servings line (e.g. "4 racions").
  final String servingsLine;
  final List<DietBadge> badges;

  /// Empty for a bought dish.
  final List<SummaryIngredient> ingredients;

  /// Downscaled JPEG bytes, or null when the dish has no photo (omit, no
  /// placeholder).
  final Uint8List? photo;

  /// "Plat preparat · supplier" line for a bought dish; null for cooked.
  final String? supplierLine;

  /// Multi-line recipe, read live from the catalog dish; null/empty when none.
  final String? preparation;
}

/// A menu drink: name, a "quantity denomination" line and optional supplier.
class SummaryDrink {
  const SummaryDrink({
    required this.name,
    required this.quantityLine,
    this.photo,
    this.supplierLine,
  });

  final String name;
  final String quantityLine;
  final Uint8List? photo;
  final String? supplierLine;
}

/// One shopping line under a supplier: item name + its "quantity unit" measure.
class SummaryShoppingItem {
  const SummaryShoppingItem({required this.name, required this.measure});
  final String name;
  final String measure;
}

/// Shopping lines grouped under one supplier (Spec 027 §B.4). The uncategorised
/// bucket reuses the same shape with a localized "no supplier" heading.
class SummarySupplierGroup {
  const SummarySupplierGroup({required this.supplierName, required this.items});
  final String supplierName;
  final List<SummaryShoppingItem> items;
}

/// The whole resolved summary. Sections already reflect omission decisions:
/// [guestGroups] is empty when there are no guests, [suppliers] empty when
/// there's nothing to buy.
class EventSummaryData {
  const EventSummaryData({
    required this.eventTitle,
    required this.headerFields,
    required this.guestGroups,
    required this.guestsTotal,
    required this.overCapacityNote,
    required this.dishes,
    required this.drinks,
    required this.totalsLines,
    required this.suppliers,
    this.eventPhoto,
  });

  final String eventTitle;
  final Uint8List? eventPhoto;
  final List<SummaryField> headerFields;

  final List<SummaryGuestGroup> guestGroups;
  final int guestsTotal;

  /// The over-capacity sentence (confirmats > comensals), or null when it
  /// doesn't apply.
  final String? overCapacityNote;

  final List<SummaryDish> dishes;
  final List<SummaryDrink> drinks;

  /// Pre-formatted menu-totals lines (dishes, servings, servings/guest).
  final List<String> totalsLines;

  final List<SummarySupplierGroup> suppliers;

  bool get hasGuests => guestGroups.isNotEmpty;
  bool get hasShopping => suppliers.isNotEmpty;
  bool get hasMenu => dishes.isNotEmpty || drinks.isNotEmpty;
}

/// Static, pre-localized labels for the document chrome (section titles,
/// headings, footer). Resolved from `AppLocalizations` by the service so the
/// builder needs no `BuildContext`.
class EventSummaryLabels {
  const EventSummaryLabels({
    required this.slogan,
    required this.sectionGuests,
    required this.sectionMenu,
    required this.sectionPurchase,
    required this.ingredientsHeading,
    required this.preparationHeading,
    required this.drinksHeading,
    required this.totalLabel,
    required this.footer,
    required this.badgeVegan,
    required this.badgeVegetarian,
    required this.badgeGlutenFree,
  });

  final String slogan;
  final String sectionGuests;
  final String sectionMenu;
  final String sectionPurchase;
  final String ingredientsHeading;
  final String preparationHeading;
  final String drinksHeading;

  /// Prefix for a guest group's total line, e.g. "Total".
  final String totalLabel;

  /// Footer line: Pexels credit + generated-on date (already composed).
  final String footer;

  final String badgeVegan;
  final String badgeVegetarian;
  final String badgeGlutenFree;

  String badgeAbbrev(DietBadge b) => switch (b) {
    DietBadge.vegan => badgeVegan,
    DietBadge.vegetarian || DietBadge.dietNegative => badgeVegetarian,
    DietBadge.glutenFree || DietBadge.glutenNegative => badgeGlutenFree,
    DietBadge.unknown => '?',
  };
}
