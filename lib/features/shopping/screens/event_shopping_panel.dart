import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/secondary_button.dart';
import '../../../ui/section_header.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/data/dish.dart' show formatQuantity;
import '../../catalog/data/reference_data.dart';
import '../data/shopping_delta.dart';
import '../data/shopping_models.dart';
import '../data/shopping_providers.dart';
import '../supplier_category_format.dart';
import 'supplier_message_screen.dart' show SentOrderCard;

/// Event shopping panel (Specification 005 §2.3): the event's ingredient
/// lines grouped by effective supplier category, each section collapsible.
/// The pantry section is consultive only; every other section offers "Send
/// message" (when there are unsent lines) and a visual "use as a shopping
/// list" mode toggle.
class EventShoppingPanel extends ConsumerStatefulWidget {
  const EventShoppingPanel({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventShoppingPanel> createState() =>
      _EventShoppingPanelState();
}

class _EventShoppingPanelState extends ConsumerState<EventShoppingPanel> {
  final _expanded = <String, bool>{};
  final _inShopMode = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final localeCode = locale.languageCode;

    final shoppingAsync = ref.watch(eventShoppingProvider(widget.eventId));
    final categoriesAsync = ref.watch(supplierCategoriesProvider(localeCode));
    final unitsAsync = ref.watch(unitsProvider(localeCode));

    if (shoppingAsync.hasError ||
        categoriesAsync.hasError ||
        unitsAsync.hasError) {
      return _PanelMessage(
        text: l10n.eventsLoadError,
        onRetry: () =>
            ref.invalidate(eventShoppingProvider(widget.eventId)),
      );
    }
    if (shoppingAsync.isLoading ||
        categoriesAsync.isLoading ||
        unitsAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    final shopping = shoppingAsync.value!;
    final categoriesById = {for (final c in categoriesAsync.value!) c.id: c};
    final unitsById = {for (final u in unitsAsync.value!) u.id: u};

    final linesByCat = linesByCategory(shopping.lines);
    final ordersByCat = ordersByCategory(shopping.orders);

    // Fixes §2.4: lines whose effective supplier category is null are not part
    // of any sendable section, but they must not vanish — the user needs to
    // know they exist and assign them a category. They get a consultive
    // section of their own, shown only when there is at least one.
    final uncategorised = [
      for (final line in shopping.lines)
        if (line.supplierCategoryId == null) line,
    ];

    // A category shows if it has current lines or any past order.
    final categoryIds = <String>{...linesByCat.keys, ...ordersByCat.keys};
    if (categoryIds.isEmpty && uncategorised.isEmpty) {
      return _PanelEmpty(text: l10n.shoppingEmptyBody);
    }

    final ordered = _orderedCategoryIds(categoryIds, categoriesById);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        for (final categoryId in ordered)
          _CategorySection(
            category: categoriesById[categoryId],
            categoryId: categoryId,
            lines: linesByCat[categoryId] ?? const [],
            orders: ordersByCat[categoryId] ?? const [],
            unitsById: unitsById,
            locale: locale,
            expanded: _expanded[categoryId] ?? true,
            inShopMode: _inShopMode.contains(categoryId),
            onToggleExpanded: () => setState(
              () => _expanded[categoryId] =
                  !(_expanded[categoryId] ?? true),
            ),
            onToggleShopMode: () => setState(() {
              if (!_inShopMode.remove(categoryId)) {
                _inShopMode.add(categoryId);
              }
            }),
            onSend: () => context.push(
              '/events/${widget.eventId}/orders/$categoryId',
            ),
          ),
        if (uncategorised.isNotEmpty)
          _UncategorisedSection(
            lines: uncategorised,
            unitsById: unitsById,
            expanded: _expanded[_uncategorisedKey] ?? true,
            onToggleExpanded: () => setState(
              () => _expanded[_uncategorisedKey] =
                  !(_expanded[_uncategorisedKey] ?? true),
            ),
          ),
      ],
    );
  }

  /// Reserved key for the consultive "no category" section's expand state in
  /// [_expanded]; it cannot collide with a real category id (a uuid).
  static const String _uncategorisedKey = '__uncategorised__';

  /// Render order: known supplier categories in a sensible shopping order,
  /// then any unknown ones, with the consultive pantry section last.
  List<String> _orderedCategoryIds(
    Set<String> ids,
    Map<String, SupplierCategory> categoriesById,
  ) {
    const codeRank = {
      'fishmonger': 0,
      'butcher': 1,
      'greengrocer': 2,
      'supermarket': 3,
    };
    final list = ids.toList();
    int rank(String id) {
      final code = categoriesById[id]?.code;
      if (code == pantryCategoryCode) return 100;
      return codeRank[code] ?? 50;
    }

    list.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      final aName = categoriesById[a]?.name ?? '';
      final bName = categoriesById[b]?.name ?? '';
      return aName.compareTo(bName);
    });
    return list;
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.categoryId,
    required this.lines,
    required this.orders,
    required this.unitsById,
    required this.locale,
    required this.expanded,
    required this.inShopMode,
    required this.onToggleExpanded,
    required this.onToggleShopMode,
    required this.onSend,
  });

  final SupplierCategory? category;
  final String categoryId;
  final List<ShoppingLine> lines;
  final List<SupplierOrder> orders;
  final Map<String, Unit> unitsById;
  final Locale locale;
  final bool expanded;
  final bool inShopMode;
  final VoidCallback onToggleExpanded;
  final VoidCallback onToggleShopMode;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final code = category?.code ?? '';
    final isPantry = isPantryCategory(code);
    final delta = deltaForCategory(lines, orders);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: supplierCategoryIcon(code),
          label: category?.name ?? code,
          count: lines.length,
          expanded: expanded,
          onToggle: onToggleExpanded,
        ),
        if (expanded) ...[
          if (isPantry)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.pantryConsultiveHint,
                style: AppTypography.caption,
              ),
            ),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _LineRow(line: line, unit: unitsById[line.unitId]),
            ),
          // Send history for this category.
          if (orders.isNotEmpty)
            for (final order in orders)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SentOrderCard(
                  order: order,
                  unitsById: unitsById,
                  locale: locale,
                ),
              ),
          if (!isPantry) ...[
            const SizedBox(height: 4),
            _SectionFooter(
              hasDelta: delta.isNotEmpty,
              deltaCount: delta.length,
              hasOrders: orders.isNotEmpty,
              inShopMode: inShopMode,
              onSend: onSend,
              onToggleShopMode: onToggleShopMode,
            ),
          ],
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Consultive section for ingredient lines without an effective supplier
/// category (Fixes §2.4). No send action — like the pantry section in spirit —
/// but with an explicit hint that the user should assign a category so these
/// ingredients can be managed and ordered.
class _UncategorisedSection extends StatelessWidget {
  const _UncategorisedSection({
    required this.lines,
    required this.unitsById,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final List<ShoppingLine> lines;
  final Map<String, Unit> unitsById;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.label_off_outlined,
          label: l10n.shoppingUncategorisedLabel,
          count: lines.length,
          expanded: expanded,
          onToggle: onToggleExpanded,
        ),
        if (expanded) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.shoppingUncategorisedHint,
              style: AppTypography.caption.copyWith(color: AppColors.warning),
            ),
          ),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _LineRow(line: line, unit: unitsById[line.unitId]),
            ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SectionFooter extends StatelessWidget {
  const _SectionFooter({
    required this.hasDelta,
    required this.deltaCount,
    required this.hasOrders,
    required this.inShopMode,
    required this.onSend,
    required this.onToggleShopMode,
  });

  final bool hasDelta;
  final int deltaCount;
  final bool hasOrders;
  final bool inShopMode;
  final VoidCallback onSend;
  final VoidCallback onToggleShopMode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status line: pending delta, or "everything sent" once a category
        // has orders and no unsent lines remain.
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            hasDelta
                ? l10n.shoppingUnsentCount(deltaCount)
                : (hasOrders ? l10n.shoppingAllSentLabel : ''),
            style: AppTypography.caption.copyWith(
              color: hasDelta ? AppColors.warning : AppColors.textSecondary,
            ),
          ),
        ),
        if (inShopMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 16,
                  color: AppColors.accentSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.shoppingInShopModeLabel,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.accentSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (hasDelta) ...[
          SecondaryButton(
            label: l10n.shoppingSendMessageAction,
            icon: Icons.send_outlined,
            onPressed: onSend,
          ),
          const SizedBox(height: 8),
        ],
        SecondaryButton(
          label: l10n.shoppingUseAsListAction,
          icon: inShopMode
              ? Icons.check_circle_outline
              : Icons.shopping_basket_outlined,
          onPressed: onToggleShopMode,
        ),
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.unit});

  final ShoppingLine line;
  final Unit? unit;

  @override
  Widget build(BuildContext context) {
    final qty = formatQuantity(line.quantity);
    final measure = unit == null ? qty : '$qty ${unit!.name}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              line.ingredientName,
              style: AppTypography.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            measure,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelEmpty extends StatelessWidget {
  const _PanelEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _PanelMessage extends StatelessWidget {
  const _PanelMessage({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: Text(
                l10n.retryAction,
                style: AppTypography.button.copyWith(color: AppColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
