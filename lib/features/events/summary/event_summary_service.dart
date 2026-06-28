/// Spec 027 §A/§D — gathers the event's already-resolved data, downscales every
/// photo, builds the summary PDF and hands it to the system share/save sheet.
///
/// This is the only impure layer: it reads providers (the SAME ones the event
/// screens read, so the sheet never diverges from what the user sees), fetches
/// and downscales images, then calls the pure [buildEventSummaryPdf]. The UI
/// shows a spinner around the call (§C) — the image work is async and the
/// compressor runs off the UI isolate, so the app stays responsive.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../l10n/app_localizations.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/data/denomination.dart' show denominationUnitNoun;
import '../../catalog/data/diet.dart';
import '../../catalog/data/reference_data.dart' show UnitMagnitude;
import '../../catalog/data/dish.dart' show formatQuantity, quantityDecimalSeparator;
import '../../photos/data/media.dart';
import '../../photos/data/media_providers.dart';
import '../../photos/data/photo_storage.dart';
import '../../shopping/data/shopping_aggregation.dart';
import '../../shopping/data/shopping_delta.dart';
import '../../shopping/data/shopping_models.dart';
import '../../shopping/data/shopping_providers.dart';
import '../../shopping/shopping_line_format.dart';
import '../../../util/text_case.dart';
import '../data/event_guest.dart' show guestStateOrder, GuestState;
import '../data/events_providers.dart';
import '../data/guest_state.dart' show guestStateLabel;
import '../data/menu_totals.dart';
import '../data/serving_scale.dart';
import '../widgets/event_formatters.dart';
import 'event_summary_data.dart';
import 'event_summary_pdf_builder.dart';
import 'image_downscale.dart';

/// Builds the summary PDF for [eventId] and presents the share/save sheet.
/// Throws on failure so the caller can surface [AppLocalizations.summaryError];
/// a single photo that fails to load is swallowed (the PDF just omits it).
Future<void> generateAndShareEventSummary(
  WidgetRef ref, {
  required AppLocalizations l10n,
  required Locale locale,
  required String eventId,
}) async {
  final localeCode = locale.languageCode;
  final sep = quantityDecimalSeparator(localeCode);

  // ── Read the same resolved data the screens show ──────────────────────────
  final event = await ref.read(eventByIdProvider(eventId).future);
  final guests = await ref.read(eventGuestsProvider(eventId).future);
  final dishes = await ref.read(eventDishesProvider(eventId).future);
  final drinks = await ref.read(eventDrinksProvider(eventId).future);
  final shopping = await ref.read(eventShoppingProvider(eventId).future);
  final units = await ref.read(unitsProvider(localeCode).future);
  final categories = await ref.read(supplierCategoriesProvider(localeCode).future);
  final catalogIngredients = await ref.read(ingredientsListProvider.future);
  final catalogDishes = await ref.read(dishesListProvider.future);
  final eventCovers =
      await ref.read(entityCoverPathsProvider(MediaEntityType.event).future);
  final dishCovers =
      await ref.read(entityCoverPathsProvider(MediaEntityType.dish).future);
  final drinkCovers =
      await ref.read(entityCoverPathsProvider(MediaEntityType.drink).future);
  final ingredientCovers =
      await ref.read(entityCoverPathsProvider(MediaEntityType.ingredient).future);

  final unitsById = {for (final u in units) u.id: u};
  final categoriesById = {for (final c in categories) c.id: c};
  final ingredientsById = {for (final i in catalogIngredients) i.id: i};
  final catalogDishesById = {for (final d in catalogDishes) d.id: d};

  // Fetch-once + downscale-once cache, keyed by bucket|path: an ingredient photo
  // reused across dishes is compressed a single time (Spec 027 §C).
  final photoCache = <String, Uint8List?>{};
  Future<Uint8List?> resolvePhoto(
    MediaEntityType type,
    String? entityId,
    Map<String, String> covers,
  ) async {
    if (entityId == null) return null;
    final path = covers[entityId];
    if (path == null) return null;
    final key = '${type.bucket}|$path';
    if (photoCache.containsKey(key)) return photoCache[key];
    Uint8List? result;
    try {
      final bytes = await ref.read(
        photoBytesProvider((bucket: type.bucket, path: path)).future,
      );
      result = await downscaleForSummaryPdf(bytes);
    } catch (e) {
      // §E: a photo that fails to load is omitted, not fatal. Log loudly so a
      // systemic failure (e.g. a missing grant) surfaces rather than hides.
      debugPrint('summary: skipped photo $key — $e');
      result = null;
    }
    photoCache[key] = result;
    return result;
  }

  // ── Cover header fields (only present values — §E) ────────────────────────
  final fields = <SummaryField>[];
  if (event.eventDate != null) {
    fields.add(SummaryField(l10n.fieldDateLabel, formatLongDate(event.eventDate!, locale)));
  }
  if (event.eventTime != null) {
    final t = event.eventTime!;
    final dt = DateTime(2000, 1, 1, t.hour, t.minute);
    fields.add(
      SummaryField(l10n.fieldTimeLabel, DateFormat.Hm(locale.toLanguageTag()).format(dt)),
    );
  }
  if ((event.locationName?.trim().isNotEmpty) ?? false) {
    fields.add(SummaryField(l10n.fieldLocationLabel, event.locationName!.trim()));
  }
  fields.add(SummaryField(l10n.fieldGuestCountLabel, '${event.guestCount}'));
  fields.add(SummaryField(l10n.fieldFormatLabel, eventFormatLabel(l10n, event.format)));
  fields.add(SummaryField(l10n.fieldTypeLabel, eventTypeLabel(l10n, event.type)));
  if ((event.notes?.trim().isNotEmpty) ?? false) {
    fields.add(SummaryField(l10n.fieldNotesLabel, event.notes!.trim()));
  }

  // ── Guests grouped by state ───────────────────────────────────────────────
  final guestGroups = <SummaryGuestGroup>[];
  for (final state in guestStateOrder) {
    final names = [for (final g in guests) if (g.state == state) g.name];
    if (names.isEmpty) continue;
    guestGroups.add(SummaryGuestGroup(label: guestStateLabel(l10n, state), names: names));
  }
  final confirmed = guests.where((g) => g.state == GuestState.confirmat).length;
  final overNote = confirmed > event.guestCount
      ? l10n.guestOverCapacityNotice(confirmed, event.guestCount)
      : null;

  // ── Menu: dishes (with recipe + badges) then drinks ───────────────────────
  final sortedDishes = [...dishes]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final summaryDishes = <SummaryDish>[];
  for (final d in sortedDishes) {
    final lines = [...await ref.read(eventDishLinesProvider(d.id).future)]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Effective dietary, resolved from the catalog (event copies store no diet):
    // derive from the dish's own ingredient lines when it has them, else fall
    // back to the catalog dish's manual value (bought dishes). Same pure
    // functions the catalog uses, so badges match Spec 026.
    final DietLevel diet;
    final TriState gf;
    if (lines.isNotEmpty) {
      diet = deriveDishDiet([
        for (final l in lines) ingredientsById[l.ingredientId]?.diet ?? DietLevel.unknown,
      ]);
      gf = deriveDishGlutenFree([
        for (final l in lines)
          ingredientsById[l.ingredientId]?.glutenFree ?? TriState.unknown,
      ]);
    } else {
      final cat = d.sourceDishId == null ? null : catalogDishesById[d.sourceDishId];
      diet = cat?.diet ?? DietLevel.unknown;
      gf = cat?.glutenFree ?? TriState.unknown;
    }

    final ingredients = <SummaryIngredient>[];
    for (final l in lines) {
      final unit = unitsById[l.unitId];
      final scaled = scaleServingQuantity(
        base: l.quantity,
        referenceServings: l.referenceServings,
        targetServings: d.servings,
        countable: unit?.magnitude == UnitMagnitude.count,
      );
      final qty = formatQuantity(scaled, decimalSeparator: sep);
      final measure = unit == null ? qty : '$qty ${unit.name}';
      final hasNote = (l.prepNote?.trim().isNotEmpty) ?? false;
      final text = [l.ingredientName, measure, if (hasNote) l.prepNote!.trim()].join(' · ');
      final ing = ingredientsById[l.ingredientId];
      ingredients.add(
        SummaryIngredient(
          text: text,
          badges: ing == null
              ? const <DietBadge>[]
              : dietaryBadgesFor(ing.diet, ing.glutenFree),
          photo: await resolvePhoto(MediaEntityType.ingredient, l.ingredientId, ingredientCovers),
        ),
      );
    }

    String? supplierLine;
    if (d.isBought) {
      final name =
          d.supplierCategoryId == null ? null : categoriesById[d.supplierCategoryId]?.name;
      supplierLine = name == null
          ? l10n.preparedDishSectionTitle
          : '${l10n.preparedDishSectionTitle} · $name';
    }

    final prep = d.isBought || d.sourceDishId == null
        ? null
        : catalogDishesById[d.sourceDishId]?.preparation;

    summaryDishes.add(
      SummaryDish(
        name: d.name,
        servingsLine: l10n.eventDishServings(d.servings),
        badges: dietaryBadgesFor(diet, gf),
        ingredients: ingredients,
        photo: await resolvePhoto(MediaEntityType.dish, d.sourceDishId, dishCovers),
        supplierLine: supplierLine,
        preparation: prep,
      ),
    );
  }

  final sortedDrinks = [...drinks]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final summaryDrinks = <SummaryDrink>[];
  for (final dr in sortedDrinks) {
    final supplierName =
        dr.supplierCategoryId == null ? null : categoriesById[dr.supplierCategoryId]?.name;
    summaryDrinks.add(
      SummaryDrink(
        name: capitalizeFirst(dr.name),
        quantityLine: '${dr.quantity} ${denominationUnitNoun(l10n, dr.denomination, dr.quantity)}',
        photo: await resolvePhoto(MediaEntityType.drink, dr.sourceDrinkId, drinkCovers),
        supplierLine: supplierName,
      ),
    );
  }

  final totals = MenuTotals.from(sortedDishes, guestCount: event.guestCount);
  final totalsLines = sortedDishes.isEmpty
      ? const <String>[]
      : [
          [
            l10n.dishCountLabel(totals.dishCount),
            l10n.eventDishServings(totals.servingsTotal),
            if (totals.servingsPerGuest != null)
              l10n.menuServingsPerPerson(formatRatioOneDecimal(totals.servingsPerGuest!, sep)),
          ].join(l10n.metadataSeparator),
        ];

  // ── Shopping grouped by supplier (mirrors the panel) ──────────────────────
  final aggregated = aggregateShoppingLines(managedShoppingLines(shopping.lines));
  final byCat = aggregatedLinesByCategory(aggregated);
  final extras = extrasByCategory(shopping.lines);
  final uncategorised = [for (final a in aggregated) if (a.supplierCategoryId == null) a];

  SummaryShoppingItem aggItem(AggregatedShoppingLine line) {
    final qty = formatQuantity(line.quantity, decimalSeparator: sep);
    final unitName = shoppingUnitName(
      kind: line.kind,
      unitId: line.unitId,
      denomination: line.denomination,
      count: line.quantity.round(),
      unitsById: unitsById,
      l10n: l10n,
      omitGenericUnit: false,
    );
    return SummaryShoppingItem(
      name: line.isPurchaseItem ? capitalizeFirst(line.ingredientName) : line.ingredientName,
      measure: unitName == null ? qty : '$qty $unitName',
    );
  }

  SummaryShoppingItem extraItem(ShoppingLine ex) {
    final qty = formatQuantity(ex.quantity, decimalSeparator: sep);
    final unit = unitsById[ex.unitId];
    return SummaryShoppingItem(
      name: ex.ingredientName,
      measure: unit == null ? qty : '$qty ${unit.name}',
    );
  }

  final catIds = <String>{...byCat.keys, ...extras.keys}.toList()
    ..sort((a, b) => (categoriesById[a]?.name ?? '').compareTo(categoriesById[b]?.name ?? ''));

  final supplierGroups = <SummarySupplierGroup>[];
  for (final catId in catIds) {
    final items = <SummaryShoppingItem>[
      for (final line in byCat[catId] ?? const []) aggItem(line),
      for (final ex in extras[catId] ?? const []) extraItem(ex),
    ];
    if (items.isEmpty) continue;
    supplierGroups.add(
      SummarySupplierGroup(
        supplierName: categoriesById[catId]?.name ?? l10n.summaryNoSupplier,
        items: items,
      ),
    );
  }
  if (uncategorised.isNotEmpty) {
    supplierGroups.add(
      SummarySupplierGroup(
        supplierName: l10n.summaryNoSupplier,
        items: [for (final a in uncategorised) aggItem(a)],
      ),
    );
  }

  // ── Assemble + build + share ──────────────────────────────────────────────
  final data = EventSummaryData(
    eventTitle: event.title,
    eventPhoto: await resolvePhoto(MediaEntityType.event, event.id, eventCovers),
    headerFields: fields,
    guestGroups: guestGroups,
    guestsTotal: guests.length,
    overCapacityNote: overNote,
    dishes: summaryDishes,
    drinks: summaryDrinks,
    totalsLines: totalsLines,
    suppliers: supplierGroups,
  );

  final labels = EventSummaryLabels(
    slogan: l10n.splashSlogan,
    sectionGuests: l10n.summarySectionGuests,
    sectionMenu: l10n.summarySectionMenu,
    sectionPurchase: l10n.summarySectionPurchase,
    ingredientsHeading: l10n.dishIngredientsSectionTitle,
    preparationHeading: l10n.dishPreparationSectionTitle,
    drinksHeading: l10n.summaryDrinksHeading,
    totalLabel: l10n.summaryTotalLabel,
    footer: l10n.summaryFooter(formatLongDate(DateTime.now(), locale)),
    badgeVegan: l10n.dietBadgeVegan,
    badgeVegetarian: l10n.dietBadgeVegetarian,
    badgeGlutenFree: l10n.dietBadgeGlutenFree,
  );

  final fonts = EventSummaryFonts(
    base: pw.Font.ttf(await rootBundle.load('assets/fonts/NunitoSans-Regular.ttf')),
    bold: pw.Font.ttf(await rootBundle.load('assets/fonts/NunitoSans-Medium.ttf')),
    title: pw.Font.ttf(await rootBundle.load('assets/fonts/Fraunces-Regular.ttf')),
  );
  final logo = (await rootBundle.load('assets/icon/entertain - icon foreground.png'))
      .buffer
      .asUint8List();

  final bytes = await buildEventSummaryPdf(
    data: data,
    labels: labels,
    logo: logo,
    fonts: fonts,
  );

  await Printing.sharePdf(
    bytes: bytes,
    filename: '${eventSummaryFileBase(event.title)}.pdf',
  );
}
