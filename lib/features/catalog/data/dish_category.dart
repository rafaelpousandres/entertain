/// Shared `dish_category` domain enum and presentation helpers.
///
/// Lives in the catalog feature because dishes own the category, but it is
/// reused by the events feature (an `event_dish` snapshots a category too).
/// Keeping the enum, its wire mapping, the canonical render order and the
/// icon / label helpers in one place avoids the duplication that would
/// otherwise creep between the dish catalog and the event menu.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

enum DishCategory { aperitif, starter, main, dessert, drink, other }

/// Source of truth for serialising the enum to / from the Postgres
/// `dish_category` enum type.
extension DishCategoryWire on DishCategory {
  String get wire => switch (this) {
    DishCategory.aperitif => 'aperitif',
    DishCategory.starter => 'starter',
    DishCategory.main => 'main',
    DishCategory.dessert => 'dessert',
    DishCategory.drink => 'drink',
    DishCategory.other => 'other',
  };

  static DishCategory parse(String value) => switch (value) {
    'aperitif' => DishCategory.aperitif,
    'starter' => DishCategory.starter,
    'main' => DishCategory.main,
    'dessert' => DishCategory.dessert,
    'drink' => DishCategory.drink,
    _ => DishCategory.other,
  };
}

/// Canonical order used to render section headers. Mirrors a typical menu
/// flow rather than the enum's declaration order — both happen to agree
/// today, but the explicit list keeps the UI from drifting if the enum is
/// reordered for storage reasons later.
const List<DishCategory> dishCategoryOrder = [
  DishCategory.aperitif,
  DishCategory.starter,
  DishCategory.main,
  DishCategory.dessert,
  DishCategory.drink,
  DishCategory.other,
];

/// The categories a user may actively pick or see grouped — the single source
/// of truth for "what the app offers". Excludes `drink`, deprecated in Spec 024:
/// beverages live in the `drinks` entity, so `dish_category.drink` is an inert
/// vestige kept only for historical `event_dishes` snapshots (the enum still
/// carries it; `wire`/`parse` still handle it so old data loads). UI pickers and
/// menu grouping iterate this list, never `dishCategoryOrder`, so no `drink`
/// section is offered or rendered. See `DishCategoryWire` / the data model.
const List<DishCategory> dishCategoryActive = [
  DishCategory.aperitif,
  DishCategory.starter,
  DishCategory.main,
  DishCategory.dessert,
  DishCategory.other,
];

/// Outline icon for a category (design system §6). Used by the section
/// header badge in both the dish catalog and the event menu.
IconData dishCategoryIcon(DishCategory category) => switch (category) {
  DishCategory.aperitif => Icons.cookie_outlined,
  DishCategory.starter => Icons.eco_outlined,
  DishCategory.main => Icons.restaurant_outlined,
  DishCategory.dessert => Icons.cake_outlined,
  DishCategory.drink => Icons.local_bar_outlined,
  DishCategory.other => Icons.restaurant_menu_outlined,
};

/// Localised label for a category.
String dishCategoryLabel(AppLocalizations l10n, DishCategory category) =>
    switch (category) {
      DishCategory.aperitif => l10n.dishCategoryAperitif,
      DishCategory.starter => l10n.dishCategoryStarter,
      DishCategory.main => l10n.dishCategoryMain,
      DishCategory.dessert => l10n.dishCategoryDessert,
      DishCategory.drink => l10n.dishCategoryDrink,
      DishCategory.other => l10n.dishCategoryOther,
    };
