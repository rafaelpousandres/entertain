import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/secondary_button.dart';
import '../../../ui/section_header.dart';
import '../../../ui/segmented_choice.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../photos/data/media.dart';
import '../../photos/data/media_providers.dart';
import '../../photos/widgets/photo_image.dart';
import '../data/shopping_mode.dart';
import '../../catalog/data/dish.dart'
    show formatQuantity, quantityDecimalSeparator;
import '../../catalog/data/reference_data.dart';
import '../../events/data/event_dish_line.dart';
import '../../events/data/events_providers.dart'
    show eventReadinessProvider, eventsListProvider, eventsRepositoryProvider;
import '../../events/screens/event_dish_line_editor_screen.dart'
    show EventDishLineEditorArgs;
import '../data/ingredient_state.dart';
import '../data/message_composer.dart';
import '../data/shopping_aggregation.dart';
import '../data/shopping_delta.dart';
import '../data/shopping_models.dart';
import '../data/shopping_providers.dart';
import '../ingredient_state_format.dart';
import '../shopping_line_format.dart';
import '../../../util/text_case.dart';
import '../supplier_category_format.dart';

/// Spec 028 §C — the three cover maps (entity id → object path) the shopping
/// rows need: ingredient lines resolve by `ingredientId`, while purchase lines
/// (bought dishes / drinks) resolve by their catalog `sourceCatalogId`.
typedef _CoverMaps = ({
  Map<String, String> ingredient,
  Map<String, String> dish,
  Map<String, String> drink,
});

/// The cover photo for a shopping line, as a (bucket, path) ref — or null when
/// the item has no photo (no thumbnail, no placeholder). Routes by line kind.
({String bucket, String path})? _lineCoverRef(
  AggregatedShoppingLine line,
  _CoverMaps covers,
) {
  final (Map<String, String> map, MediaEntityType type, String? id) =
      switch (line.kind) {
    ShoppingLineKind.ingredient => (
        covers.ingredient,
        MediaEntityType.ingredient,
        line.ingredientId,
      ),
    ShoppingLineKind.preparedDish => (
        covers.dish,
        MediaEntityType.dish,
        line.sourceCatalogId,
      ),
    ShoppingLineKind.drink => (
        covers.drink,
        MediaEntityType.drink,
        line.sourceCatalogId,
      ),
  };
  if (id == null) return null;
  final path = map[id];
  return path == null ? null : (bucket: type.bucket, path: path);
}

/// Event shopping panel (Specification 005 §2.3 + 007 §3.4): the event's
/// ingredient lines grouped by effective supplier category, each line carrying
/// a state (Spec 007 §3.1). A summary header at the top shows the global state
/// of the event. Within each supplier section the lines are sub-grouped by
/// state in concern-decreasing order (Per demanar / Falta / Retrassat / Demanat
/// / Rebut / A casa); each line has a colour indicator and a tap-to-change
/// action with only its legal transitions.
///
/// The pantry ("Rebost") and "Sense categoria" sections are consultive — no
/// message-sending actions — but show the full state machine and the bulk
/// "mark all as received" action where applicable. Every other section keeps
/// the Spec 005 send flow: the delta to send is the lines in `to_order`.
class EventShoppingPanel extends ConsumerStatefulWidget {
  const EventShoppingPanel({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventShoppingPanel> createState() => _EventShoppingPanelState();
}

class _EventShoppingPanelState extends ConsumerState<EventShoppingPanel> {
  /// §2.8 accordion: the single open section's key, or null when all are
  /// collapsed. The panel opens all-collapsed and the state is not persisted —
  /// re-entering the Shopping tab starts collapsed again.
  String? _openSection;

  /// Reserved key for the consultive "no category" section's expand state; it
  /// cannot collide with a real category id (a uuid).
  static const String _uncategorisedKey = '__uncategorised__';

  /// Spec 028: the sub-mode selected for this session (bottom tabs). Null until
  /// the user toggles — the initial mode follows the persisted default
  /// (Configuració), so opening the tab honours the setting.
  ShoppingMode? _mode;

  /// §2.8: opens [key]'s section and closes every other one (only one open at a
  /// time); tapping the already-open section collapses it.
  void _toggleSection(String key) {
    setState(() => _openSection = _openSection == key ? null : key);
  }

  /// Refreshes the event's derived status (Spec 008 §2.4) wherever it is shown
  /// (the detail header chip, the list dots and grouping) after a state change.
  void _refreshEventStatus() {
    ref.invalidate(eventReadinessProvider);
    ref.invalidate(eventsListProvider);
  }

  /// "Usa com a llista de la compra" (Fixes round 3 §2.3): turns the section's
  /// `to_order` lines into a plain text shopping list — the same per-line format
  /// as the supplier message (quantity, unit suppression, Catalan elision,
  /// prep note) but without greeting / needed-by / signature — copies it to the
  /// clipboard, confirms with a toast, and moves those lines to `ordered` so the
  /// state machine reflects that the user has taken on the purchase themselves.
  ///
  /// Spec 010 §2.1: the lines are already aggregated, so the text carries the
  /// summed quantity ("3 bunches"), and moving them to `ordered` writes every
  /// underlying row id of each aggregate atomically.
  Future<void> _useAsShoppingList(
    List<AggregatedShoppingLine> toOrderLines,
    List<ShoppingLine> extras,
    Map<String, Unit> unitsById,
  ) async {
    // §A: a section with only extras (managed items all received) can still be
    // copied; the managed-state transition below simply has nothing to move.
    if (toOrderLines.isEmpty && extras.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final messenger = ScaffoldMessenger.of(context);

    String itemLine(
      double quantity,
      String? unitName,
      String ingredientName,
      String? prepNote,
    ) => composeItemLine(
      quantity: formatQuantity(
        quantity,
        decimalSeparator: quantityDecimalSeparator(locale.languageCode),
      ),
      unit: unitName,
      connector: l10n.messageItemConnector,
      ingredientName: ingredientName,
      prepNote: prepNote,
      // Catalan-only "de" → "d'" elision before vowels / h.
      elideConnector: locale.languageCode == 'ca',
    );

    final text = [
      for (final line in toOrderLines)
        itemLine(
          line.quantity,
          shoppingUnitName(
            kind: line.kind,
            unitId: line.unitId,
            denomination: line.denomination,
            count: line.quantity.round(),
            unitsById: unitsById,
            l10n: l10n,
          ),
          line.ingredientName,
          line.prepNote,
        ),
      // §2.11: the supplier's extras follow the managed items in the same list,
      // so the one message covers everything to order. Their state is untouched.
      for (final extra in extras)
        itemLine(
          extra.quantity,
          shoppingUnitName(
            kind: extra.kind,
            unitId: extra.unitId,
            denomination: extra.denomination,
            count: extra.quantity.round(),
            unitsById: unitsById,
            l10n: l10n,
          ),
          extra.ingredientName,
          extra.prepNote,
        ),
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: text));
    await ref.read(shoppingRepositoryProvider).updateLineStates([
      for (final line in toOrderLines) ...line.refs,
    ], IngredientState.ordered);
    ref.invalidate(eventShoppingProvider(widget.eventId));
    _refreshEventStatus();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.shoppingListCopiedToast)),
    );
  }

  /// Changes the state of an aggregated line (Spec 010 §2.1): a single
  /// `IN (...)` update over **all** the folded rows' ids, so they transition
  /// together or not at all.
  Future<void> _changeState(
    AggregatedShoppingLine line, {
    required bool isPantry,
  }) async {
    final options = allowedTransitions(line.state, isPantry: isPantry);
    if (options.isEmpty) return;
    final picked = await showModalBottomSheet<IngredientState>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheetContext) => _StateSheet(line: line, options: options),
    );
    if (picked == null || picked == line.state) return;
    await ref
        .read(shoppingRepositoryProvider)
        .updateLineStates(line.refs, picked);
    ref.invalidate(eventShoppingProvider(widget.eventId));
    _refreshEventStatus();
  }

  /// Spec 028 — In-person checklist toggle. Checked ⇔ received/at-home; tapping
  /// to check sets `received` (`at_home` for the pantry's binary model), tapping
  /// to uncheck sets `to_order` (`missing` for the pantry). Reuses the exact
  /// same state-update path as the ordering screen (no new persistence).
  Future<void> _toggleChecked(
    AggregatedShoppingLine line, {
    required bool isPantry,
  }) async {
    final next = toggledShoppingState(line.state, isPantry: isPantry);
    await ref.read(shoppingRepositoryProvider).updateLineStates(line.refs, next);
    ref.invalidate(eventShoppingProvider(widget.eventId));
    _refreshEventStatus();
  }

  Future<void> _markAllReceived(List<ShoppingLineRef> orderedRefs) async {
    if (orderedRefs.isEmpty) return;
    await ref
        .read(shoppingRepositoryProvider)
        .updateLineStates(orderedRefs, IngredientState.received);
    ref.invalidate(eventShoppingProvider(widget.eventId));
    _refreshEventStatus();
  }

  /// §2.11: "+ Add extra" for a supplier section. Lazily materialises the
  /// event's phantom extras dish, then opens the per-event line editor with the
  /// section's supplier pre-selected. The editor persists and invalidates the
  /// shopping provider, so the new extra appears on return.
  Future<void> _addExtra(String supplierCategoryId) async {
    final dishId = await ref
        .read(eventsRepositoryProvider)
        .ensureExtrasDish(widget.eventId);
    if (!mounted) return;
    await context.push(
      '/event-dish-line-editor',
      extra: EventDishLineEditorArgs(
        eventId: widget.eventId,
        eventDishId: dishId,
        initialSupplierCategoryId: supplierCategoryId,
        // §2.11.b: an extra's supplier is fixed to its section; the picker is
        // strictly filtered to that supplier's catalog ingredients.
        lockSupplierCategory: true,
      ),
    );
  }

  /// §2.11: edit an existing extra in the same per-event line editor used for
  /// dish ingredients. The extra's quantity is unscaled (phantom servings = 1),
  /// so it maps straight onto an [EventDishLine] with a reference of 1.
  Future<void> _editExtra(ShoppingLine extra) async {
    final dishId = await ref
        .read(eventsRepositoryProvider)
        .ensureExtrasDish(widget.eventId);
    if (!mounted) return;
    await context.push(
      '/event-dish-line-editor',
      extra: EventDishLineEditorArgs(
        eventId: widget.eventId,
        eventDishId: dishId,
        line: EventDishLine(
          id: extra.id,
          ingredientId: extra.ingredientId,
          ingredientName: extra.ingredientName,
          quantity: extra.quantity,
          // Extras are ingredient lines, so they always carry a real unit id.
          unitId: extra.unitId!,
          prepNote: extra.prepNote,
          supplierCategoryId: extra.supplierCategoryId,
          sortOrder: 0,
          referenceServings: 1,
        ),
        // §2.11.b: editing an extra keeps its supplier fixed and the picker
        // strictly filtered to that supplier's catalog ingredients.
        lockSupplierCategory: true,
      ),
    );
  }

  /// §2.11: delete an extra straight from the shopping panel (the phantom dish
  /// is kept for reuse). Confirms first, reusing the line-removal dialog text.
  Future<void> _deleteExtra(ShoppingLine extra) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        // §2.11.e: extras live on the invisible phantom dish, so the generic
        // "removes the line from this dish" wording would confuse — the user
        // only sees an extra on the shopping list.
        title: Text(
          l10n.removeExtraConfirmTitle,
          style: AppTypography.sectionTitle,
        ),
        content: Text(
          l10n.removeExtraConfirmBody,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.cancelAction,
              style: AppTypography.button.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.removeExtraConfirmButton,
              style: AppTypography.button.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(eventsRepositoryProvider).deleteEventDishLine(extra.id);
    ref.invalidate(eventShoppingProvider(widget.eventId));
    _refreshEventStatus();
  }

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
        onRetry: () => ref.invalidate(eventShoppingProvider(widget.eventId)),
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

    // Spec 028: the active sub-mode — the user's session pick, else the
    // persisted default (Configuració), else Comandes. The bottom tabs toggle it.
    final mode =
        _mode ?? ref.watch(shoppingModeProvider).value ?? ShoppingMode.comandes;
    final inPerson = mode == ShoppingMode.enPersona;
    // Spec 028 §C: cover thumbnails on rows (both modes) — ingredients by their
    // id, bought dishes / drinks by their catalog source id; photoless items
    // show none.
    const emptyCovers = <String, String>{};
    final _CoverMaps covers = (
      ingredient:
          ref.watch(entityCoverPathsProvider(MediaEntityType.ingredient)).value ??
              emptyCovers,
      dish: ref.watch(entityCoverPathsProvider(MediaEntityType.dish)).value ??
          emptyCovers,
      drink: ref.watch(entityCoverPathsProvider(MediaEntityType.drink)).value ??
          emptyCovers,
    );

    // Spec 011 §2.11: split the event's lines into managed (dish-derived) and
    // extras (the phantom-dish piggyback items). Only managed lines aggregate,
    // feed the summary, the status counters and the state machine; extras render
    // separately within their supplier section with an "Extra" badge.
    final extrasByCat = extrasByCategory(shopping.lines);

    // Spec 010 §2.1: aggregate repeated ingredients (same ingredient, unit,
    // state, supplier and prep_note) into a single line whose quantity is the
    // sum of the effective scaled quantities. Everything below renders these
    // aggregated lines; the underlying rows stay individual in the database.
    // Extras never aggregate (Spec 011 §2.11), so only managed lines fold here.
    final aggregated = aggregateShoppingLines(
      managedShoppingLines(shopping.lines),
    );

    // Fixes round 2 §2.2: derive the "Retrassat" overlay per line — an `ordered`
    // line whose most recent order is past its needed-by date. Computed once
    // here at render time (no persistence). Uniform across an aggregate, which
    // shares the key fields the overlay derives from.
    final neededBy = neededByByItem(shopping.orders);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DisplayState displayOf(AggregatedShoppingLine line) => DisplayState.of(
      line.state,
      delayed: aggregatedLineIsDelayed(line, neededBy, today),
    );

    final linesByCat = aggregatedLinesByCategory(aggregated);

    final uncategorised = [
      for (final line in aggregated)
        if (line.supplierCategoryId == null) line,
    ];

    final bool empty =
        linesByCat.isEmpty && uncategorised.isEmpty && extrasByCat.isEmpty;

    // §2.11: a supplier section appears if it has managed lines OR only extras.
    final ordered = _orderedCategoryIds({
      ...linesByCat.keys,
      ...extrasByCat.keys,
    }, categoriesById);

    final Widget content = empty
        ? _PanelEmpty(text: l10n.shoppingEmptyBody)
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _SummaryHeader(lines: aggregated, displayOf: displayOf),
              const SizedBox(height: 16),
              for (final categoryId in ordered)
                _CategorySection(
                  category: categoriesById[categoryId],
                  lines: linesByCat[categoryId] ?? const [],
                  extras: extrasByCat[categoryId] ?? const [],
                  displayOf: displayOf,
                  unitsById: unitsById,
                  covers: covers,
                  inPerson: inPerson,
                  expanded: _openSection == categoryId,
                  onToggleExpanded: () => _toggleSection(categoryId),
                  onSend: () => context.push(
                    '/events/${widget.eventId}/orders/$categoryId',
                  ),
                  onChangeState: _changeState,
                  onToggleChecked: _toggleChecked,
                  onMarkAllReceived: _markAllReceived,
                  onUseAsShoppingList: _useAsShoppingList,
                  onAddExtra: () => _addExtra(categoryId),
                  onEditExtra: _editExtra,
                  onDeleteExtra: _deleteExtra,
                ),
              if (uncategorised.isNotEmpty)
                _UncategorisedSection(
                  lines: uncategorised,
                  displayOf: displayOf,
                  unitsById: unitsById,
                  covers: covers,
                  inPerson: inPerson,
                  expanded: _openSection == _uncategorisedKey,
                  onToggleExpanded: () => _toggleSection(_uncategorisedKey),
                  onChangeState: _changeState,
                  onToggleChecked: _toggleChecked,
                  onMarkAllReceived: _markAllReceived,
                ),
            ],
          );

    // Spec 028 §A: bottom tabs toggle the sub-mode for the session.
    return Column(
      children: [
        Expanded(child: content),
        _ModeToggleBar(
          mode: mode,
          onChanged: (m) => setState(() => _mode = m),
        ),
      ],
    );
  }

  /// Render order (Spec 007 §3.4 + Fixes round 2 §2.5): dispatching categories
  /// first, sorted by display name, then the consultive Rebost (pantry). The
  /// "Sense categoria" catch-all is appended after both by the caller, so the
  /// final order is dispatching → Rebost → Sense categoria.
  List<String> _orderedCategoryIds(
    Set<String> ids,
    Map<String, SupplierCategory> categoriesById,
  ) {
    // 0 = dispatching, 1 = Rebost; the consultive pantry sinks below the rest.
    int rank(String id) =>
        isPantryCategory(categoriesById[id]?.code ?? '') ? 1 : 0;
    final list = ids.toList();
    list.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      final aName = categoriesById[a]?.name ?? '';
      final bName = categoriesById[b]?.name ?? '';
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });
    return list;
  }
}

/// Counts each persisted state across [lines] (zeros included). Used for the
/// section footer gating, which keys off the operational states (send delta =
/// `to_order`; mark-all-received = `ordered`), not the display overlay. Counts
/// aggregated lines (Spec 010 §2.1), so a folded ingredient counts once.
Map<IngredientState, int> _countStates(List<AggregatedShoppingLine> lines) {
  final counts = {for (final s in IngredientState.values) s: 0};
  for (final line in lines) {
    counts[line.state] = (counts[line.state] ?? 0) + 1;
  }
  return counts;
}

/// Counts each [DisplayState] across [lines] (zeros included), resolving each
/// line through [displayOf] so the derived "Retrassat" overlay is counted as
/// its own group (Fixes round 2 §2.2).
Map<DisplayState, int> _countDisplay(
  List<AggregatedShoppingLine> lines,
  DisplayState Function(AggregatedShoppingLine) displayOf,
) {
  final counts = {for (final s in DisplayState.values) s: 0};
  for (final line in lines) {
    final s = displayOf(line);
    counts[s] = (counts[s] ?? 0) + 1;
  }
  return counts;
}

/// Global summary at the top of the panel (Spec 007 §3.4): the total ingredient
/// count and a coloured-dot legend with the count of each state, including the
/// derived "Retrassat" count (Fixes round 2 §2.2).
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.lines, required this.displayOf});

  final List<AggregatedShoppingLine> lines;
  final DisplayState Function(AggregatedShoppingLine) displayOf;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final counts = _countDisplay(lines, displayOf);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.shoppingSummaryTotal(lines.length),
            style: AppTypography.sectionTitle,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final state in kDisplayStateOrder)
                if ((counts[state] ?? 0) > 0)
                  _StateCount(state: state, count: counts[state]!),
            ],
          ),
        ],
      ),
    );
  }
}

/// A coloured dot followed by `count label`, used in the summary header.
class _StateCount extends StatelessWidget {
  const _StateCount({required this.state, required this.count});

  final DisplayState state;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dot(color: displayStateColor(state)),
        const SizedBox(width: 6),
        Text(
          '$count ${displayStateLabel(l10n, state).toLowerCase()}',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.size = 9});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Spec 011 §2.9 — the red/yellow/green status trio for a supplier section,
/// derived from its **managed** lines' persisted states (extras never reach a
/// section's `lines`, so they are excluded by construction). Red = still to act
/// (`to_order` + `missing`); yellow = waiting on the supplier (`ordered`);
/// green = resolved (`received` + `at_home`). The three sum to the section's
/// managed-ingredient count.
class _StatusCounts {
  const _StatusCounts({
    required this.red,
    required this.yellow,
    required this.green,
  });

  final int red;
  final int yellow;
  final int green;

  factory _StatusCounts.fromLines(List<AggregatedShoppingLine> lines) {
    final trio = supplierStatusCounts(lines);
    return _StatusCounts(red: trio.red, yellow: trio.yellow, green: trio.green);
  }

  bool get isEmpty => red == 0 && yellow == 0 && green == 0;

  /// §2.10 — the highest-priority colour (red over yellow over green) used to
  /// tint the supplier icon. Falls back to green for a section with no managed
  /// ingredients (the safe default).
  Color get priorityColor {
    if (red > 0) return AppColors.danger;
    if (yellow > 0) return AppColors.warning;
    return AppColors.success;
  }
}

/// §2.9 — up to three compact `● n` counters (red/yellow/green) shown on a
/// supplier header whether collapsed or expanded. A colour with zero
/// ingredients shows neither its dot nor its number.
class _StatusCounters extends StatelessWidget {
  const _StatusCounters({required this.counts});

  final _StatusCounts counts;

  @override
  Widget build(BuildContext context) {
    final pills = <Widget>[];
    void add(int value, Color color) {
      if (value == 0) return;
      if (pills.isNotEmpty) pills.add(const SizedBox(width: 10));
      pills.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(color: color, size: 8),
            const SizedBox(width: 4),
            Text(
              '$value',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    add(counts.red, AppColors.danger);
    add(counts.yellow, AppColors.warning);
    add(counts.green, AppColors.success);
    return Row(mainAxisSize: MainAxisSize.min, children: pills);
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.lines,
    required this.extras,
    required this.displayOf,
    required this.unitsById,
    required this.covers,
    required this.inPerson,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onSend,
    required this.onChangeState,
    required this.onToggleChecked,
    required this.onMarkAllReceived,
    required this.onUseAsShoppingList,
    required this.onAddExtra,
    required this.onEditExtra,
    required this.onDeleteExtra,
  });

  final SupplierCategory? category;
  final List<AggregatedShoppingLine> lines;

  /// §2.11 — the supplier's extras (raw, never aggregated), rendered after the
  /// managed lines with an "Extra" badge.
  final List<ShoppingLine> extras;
  final DisplayState Function(AggregatedShoppingLine) displayOf;
  final Map<String, Unit> unitsById;

  /// Spec 028 §C — the cover maps for the row thumbnails (ingredient/dish/drink).
  final _CoverMaps covers;

  /// Spec 028 — In-person checklist variant: hides the ordering controls and
  /// renders each row as a checkbox.
  final bool inPerson;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onSend;
  final void Function(AggregatedShoppingLine line, {required bool isPantry})
  onChangeState;
  final void Function(AggregatedShoppingLine line, {required bool isPantry})
  onToggleChecked;
  final void Function(List<ShoppingLineRef> orderedRefs) onMarkAllReceived;
  final void Function(
    List<AggregatedShoppingLine> toOrderLines,
    List<ShoppingLine> extras,
    Map<String, Unit> unitsById,
  )
  onUseAsShoppingList;
  final VoidCallback onAddExtra;
  final void Function(ShoppingLine extra) onEditExtra;
  final void Function(ShoppingLine extra) onDeleteExtra;

  @override
  Widget build(BuildContext context) {
    final code = category?.code ?? '';
    final isPantry = isPantryCategory(code);
    final counts = _countStates(lines);
    final status = _StatusCounts.fromLines(lines);
    final toOrder = counts[IngredientState.toOrder] ?? 0;
    final orderedCount = counts[IngredientState.ordered] ?? 0;
    // Aggregated lines expand to their underlying row ids so a bulk action
    // touches every folded row (Spec 010 §2.1).
    final orderedIds = [
      for (final line in lines)
        if (line.state == IngredientState.ordered) ...line.refs,
    ];
    final toOrderLines = [
      for (final line in lines)
        if (line.state == IngredientState.toOrder) line,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fixes §2.2: the section header carries only the supplier name; all
        // quantitative info lives in the per-state sub-group headers below, so
        // the previously-shown aggregate count/summary is dropped here.
        SectionHeader(
          icon: supplierCategoryIcon(code),
          label: category?.name ?? code,
          expanded: expanded,
          onToggle: onToggleExpanded,
          // §2.9 counters + §2.10 icon tint, both keyed off the managed-line
          // status. Pale background + saturated ring/glyph in the priority
          // colour; counters hidden entirely when there are no managed lines.
          trailing: status.isEmpty ? null : _StatusCounters(counts: status),
          iconBackgroundColor: status.priorityColor.withValues(alpha: 0.15),
          iconColor: status.priorityColor,
          iconRingColor: status.priorityColor,
        ),
        if (expanded) ...[
          const SizedBox(height: 4),
          if (isPantry)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                AppLocalizations.of(context).pantryConsultiveHint,
                style: AppTypography.caption,
              ),
            ),
          _StateGroups(
            lines: lines,
            displayOf: displayOf,
            unitsById: unitsById,
            covers: covers,
            isPantry: isPantry,
            inPerson: inPerson,
            onChangeState: onChangeState,
            onToggleChecked: onToggleChecked,
          ),
          // §2.11.c: the extras render as their own group — placed after the
          // managed ingredients and before the action buttons. Spec 028: extras
          // (no state, managed from Comandes) are omitted in the checklist.
          if (!inPerson && !isPantry && extras.isNotEmpty)
            _ExtraGroup(
              extras: extras,
              unitsById: unitsById,
              ingredientCovers: covers.ingredient,
              onEditExtra: onEditExtra,
              onDeleteExtra: onDeleteExtra,
            ),
          const SizedBox(height: 4),
          // Spec 028 §B: In-person mode strips the ordering controls — no
          // add-extra, send, mark-all, or use-as-list. Just walk and tick.
          if (!inPerson)
            _SectionFooter(
              // §2.11.a/c: "+ Add extra" is the first action button (right under
              // the Extra group), equispaced with the rest. Not on the
              // consultive pantry section.
              showAddExtra: !isPantry,
              // Pantry / Rebost is consultive: no send, no shop-list action, and
              // no bulk "mark all as received" — its binary model has no
              // `ordered` state (Fixes §2.4).
              //
              // §A: send / use-as-list stay active while there is anything to
              // order — managed `to_order` lines OR extras — so a section whose
              // managed items are all received can still send its extras.
              showSend: !isPantry && (toOrder > 0 || extras.isNotEmpty),
              showUseAsList: !isPantry && (toOrder > 0 || extras.isNotEmpty),
              showMarkReceived: !isPantry && orderedCount > 0,
              onAddExtra: onAddExtra,
              onSend: onSend,
              onMarkAllReceived: () => onMarkAllReceived(orderedIds),
              onUseAsList: () =>
                  onUseAsShoppingList(toOrderLines, extras, unitsById),
            ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Consultive section for ingredient lines without an effective supplier
/// category (Fixes §2.4 + Spec 007 §3.4). Like the pantry section: the full
/// state machine and the bulk "mark all as received" action, but no
/// message-sending actions. Keeps the hint to assign a category.
class _UncategorisedSection extends StatelessWidget {
  const _UncategorisedSection({
    required this.lines,
    required this.displayOf,
    required this.unitsById,
    required this.covers,
    required this.inPerson,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onChangeState,
    required this.onToggleChecked,
    required this.onMarkAllReceived,
  });

  final List<AggregatedShoppingLine> lines;
  final DisplayState Function(AggregatedShoppingLine) displayOf;
  final Map<String, Unit> unitsById;
  final _CoverMaps covers;
  final bool inPerson;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final void Function(AggregatedShoppingLine line, {required bool isPantry})
  onChangeState;
  final void Function(AggregatedShoppingLine line, {required bool isPantry})
  onToggleChecked;
  final void Function(List<ShoppingLineRef> orderedRefs) onMarkAllReceived;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final counts = _countStates(lines);
    final status = _StatusCounts.fromLines(lines);
    final orderedCount = counts[IngredientState.ordered] ?? 0;
    final orderedIds = [
      for (final line in lines)
        if (line.state == IngredientState.ordered) ...line.refs,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fixes §2.2: supplier name only; counts live in the sub-group headers.
        // §2.9/§2.10: the same compact counters and icon tint as a supplier.
        SectionHeader(
          icon: Icons.label_off_outlined,
          label: l10n.shoppingUncategorisedLabel,
          expanded: expanded,
          onToggle: onToggleExpanded,
          trailing: status.isEmpty ? null : _StatusCounters(counts: status),
          iconBackgroundColor: status.priorityColor.withValues(alpha: 0.15),
          iconColor: status.priorityColor,
          iconRingColor: status.priorityColor,
        ),
        if (expanded) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.shoppingUncategorisedHint,
              style: AppTypography.caption.copyWith(color: AppColors.warning),
            ),
          ),
          _StateGroups(
            lines: lines,
            displayOf: displayOf,
            unitsById: unitsById,
            covers: covers,
            isPantry: false,
            inPerson: inPerson,
            onChangeState: onChangeState,
            onToggleChecked: onToggleChecked,
          ),
          if (!inPerson && orderedCount > 0) ...[
            const SizedBox(height: 4),
            SecondaryButton(
              label: l10n.shoppingMarkAllReceivedAction,
              icon: Icons.done_all,
              onPressed: () => onMarkAllReceived(orderedIds),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// The ingredient lines of one section, sub-grouped by display state with a
/// mini-header per non-empty group, in the concern-decreasing order Per demanar
/// / Falta / Retrassat / Demanat / Rebut / A casa (Fixes round 3 §2.1).
class _StateGroups extends StatelessWidget {
  const _StateGroups({
    required this.lines,
    required this.displayOf,
    required this.unitsById,
    required this.covers,
    required this.isPantry,
    required this.inPerson,
    required this.onChangeState,
    required this.onToggleChecked,
  });

  final List<AggregatedShoppingLine> lines;
  final DisplayState Function(AggregatedShoppingLine) displayOf;
  final Map<String, Unit> unitsById;
  final _CoverMaps covers;
  final bool isPantry;
  final bool inPerson;
  final void Function(AggregatedShoppingLine line, {required bool isPantry})
  onChangeState;
  final void Function(AggregatedShoppingLine line, {required bool isPantry})
  onToggleChecked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final byState = {
      for (final state in DisplayState.values)
        state: [
          for (final l in lines)
            if (displayOf(l) == state) l,
        ],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // §B: within a supplier section the groups run settled → urgent, so
        // "Per demanar" ends up closest to the action buttons below.
        for (final state in kSectionStateOrder)
          if ((byState[state] ?? const []).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Row(
                children: [
                  _Dot(color: displayStateColor(state), size: 8),
                  const SizedBox(width: 6),
                  Text(
                    '${displayStateLabel(l10n, state)} · ${byState[state]!.length}',
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            for (final line in byState[state]!)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LineRow(
                  line: line,
                  displayState: state,
                  unit: unitsById[line.unitId],
                  coverRef: _lineCoverRef(line, covers),
                  inPerson: inPerson,
                  onTap: () => onChangeState(line, isPantry: isPantry),
                  onToggleChecked: () =>
                      onToggleChecked(line, isPantry: isPantry),
                ),
              ),
          ],
      ],
    );
  }
}

class _SectionFooter extends StatelessWidget {
  const _SectionFooter({
    required this.showAddExtra,
    required this.showSend,
    required this.showUseAsList,
    required this.showMarkReceived,
    required this.onAddExtra,
    required this.onSend,
    required this.onMarkAllReceived,
    required this.onUseAsList,
  });

  final bool showAddExtra;
  final bool showSend;
  final bool showUseAsList;
  final bool showMarkReceived;
  final VoidCallback onAddExtra;
  final VoidCallback onSend;
  final VoidCallback onMarkAllReceived;
  final VoidCallback onUseAsList;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final children = <Widget>[];

    void addButton(SecondaryButton button) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(button);
    }

    // §2.11.c: "+ Add extra" leads the action group, equispaced with the rest.
    if (showAddExtra) {
      addButton(
        SecondaryButton(
          label: l10n.addExtraAction,
          icon: Icons.add,
          onPressed: onAddExtra,
        ),
      );
    }
    if (showSend) {
      addButton(
        SecondaryButton(
          label: l10n.shoppingSendMessageAction,
          icon: Icons.send_outlined,
          onPressed: onSend,
        ),
      );
    }
    if (showMarkReceived) {
      addButton(
        SecondaryButton(
          label: l10n.shoppingMarkAllReceivedAction,
          icon: Icons.done_all,
          onPressed: onMarkAllReceived,
        ),
      );
    }
    if (showUseAsList) {
      // Fixes round 3 §2.3: one-shot action — copy the list to the clipboard
      // and move the lines to `ordered`; the toast is the confirmation.
      addButton(
        SecondaryButton(
          label: l10n.shoppingUseAsListAction,
          icon: Icons.shopping_basket_outlined,
          onPressed: onUseAsList,
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.displayState,
    required this.unit,
    required this.coverRef,
    required this.inPerson,
    required this.onTap,
    required this.onToggleChecked,
  });

  final AggregatedShoppingLine line;
  final DisplayState displayState;
  final Unit? unit;

  /// Spec 028 §C — the cover photo (bucket + path), or null (no thumbnail).
  final ({String bucket, String path})? coverRef;

  /// Spec 028 — checklist variant: a checkbox replaces the state indicator.
  final bool inPerson;
  final VoidCallback onTap;
  final VoidCallback onToggleChecked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final qty = formatQuantity(
      line.quantity,
      decimalSeparator: quantityDecimalSeparator(
        Localizations.localeOf(context).languageCode,
      ),
    );
    // Spec 016: a bought-dish line shows a bare count ("3"); a drink shows its
    // denomination noun ("2 ampolles"); an ingredient shows its unit name.
    final unitName = shoppingUnitName(
      kind: line.kind,
      unitId: line.unitId,
      denomination: line.denomination,
      count: line.quantity.round(),
      unitsById: unit == null ? const {} : {unit!.id: unit!},
      l10n: l10n,
      omitGenericUnit: false,
    );
    final measure = unitName == null ? qty : '$qty $unitName';
    final checked = isCheckedShoppingState(line.state);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: inPerson ? onToggleChecked : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Spec 028 §C: the cover thumbnail (both modes) — ingredient,
              // bought dish or drink; absent when the item has no photo.
              if (coverRef != null) ...[
                RowPhotoThumb(photoRef: coverRef!, size: 34),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  // Spec 016 §5.2: purchase-line names (drinks / prepared dishes)
                  // display capitalised, like ingredient names.
                  line.isPurchaseItem
                      ? capitalizeFirst(line.ingredientName)
                      : line.ingredientName,
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
              const SizedBox(width: 10),
              // Spec 028 §B: a checkbox in person mode; the state dot+label in
              // ordering mode.
              if (inPerson)
                Icon(
                  checked ? Icons.check_box : Icons.check_box_outline_blank,
                  color: checked ? AppColors.success : AppColors.textTertiary,
                  size: 24,
                )
              else ...[
                _Dot(color: displayStateColor(displayState)),
                const SizedBox(width: 6),
                Text(
                  displayStateLabel(l10n, displayState).toLowerCase(),
                  style: AppTypography.caption.copyWith(
                    color: displayStateColor(displayState),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// §2.11.c — the extras of one supplier section as their own group: an "Extra"
/// header in the same style as the per-state sub-group headers (a neutral dot +
/// "Extra · N"), followed by the extra rows.
class _ExtraGroup extends StatelessWidget {
  const _ExtraGroup({
    required this.extras,
    required this.unitsById,
    required this.ingredientCovers,
    required this.onEditExtra,
    required this.onDeleteExtra,
  });

  final List<ShoppingLine> extras;
  final Map<String, Unit> unitsById;
  final Map<String, String> ingredientCovers;
  final void Function(ShoppingLine extra) onEditExtra;
  final void Function(ShoppingLine extra) onDeleteExtra;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Row(
            children: [
              // Neutral grey dot — extras carry no state colour.
              _Dot(color: AppColors.textTertiary, size: 8),
              const SizedBox(width: 6),
              Text(
                '${l10n.extraBadge} · ${extras.length}',
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        for (final extra in extras)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ExtraRow(
              extra: extra,
              unit: unitsById[extra.unitId],
              coverPath: extra.ingredientId == null
                  ? null
                  : ingredientCovers[extra.ingredientId],
              onTap: () => onEditExtra(extra),
              onDelete: () => onDeleteExtra(extra),
            ),
          ),
      ],
    );
  }
}

/// §2.11 — one extra ingredient row: the name and measure like a managed line,
/// but with a neutral-gray "Extra" badge in place of a state indicator and a
/// trailing delete affordance. Tapping the row opens the line editor.
class _ExtraRow extends StatelessWidget {
  const _ExtraRow({
    required this.extra,
    required this.unit,
    required this.coverPath,
    required this.onTap,
    required this.onDelete,
  });

  final ShoppingLine extra;
  final Unit? unit;
  final String? coverPath;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final qty = formatQuantity(
      extra.quantity,
      decimalSeparator: quantityDecimalSeparator(
        Localizations.localeOf(context).languageCode,
      ),
    );
    final measure = unit == null ? qty : '$qty ${unit!.name}';
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Spec 028 §C: cover thumbnail for extras too, when present.
              if (coverPath != null) ...[
                RowPhotoThumb(
                  photoRef: (
                    bucket: MediaEntityType.ingredient.bucket,
                    path: coverPath!,
                  ),
                  size: 34,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  extra.ingredientName,
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
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.extraBadge,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.textTertiary,
                tooltip: l10n.removeLineAction,
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing only the legal state transitions for a line (Spec 007
/// §3.3 / §5: never show all five states).
class _StateSheet extends StatelessWidget {
  const _StateSheet({required this.line, required this.options});

  final AggregatedShoppingLine line;
  final List<IngredientState> options;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(line.ingredientName, style: AppTypography.sectionTitle),
            const SizedBox(height: 4),
            Text(
              l10n.shoppingStateChangeSubtitle(
                ingredientStateLabel(l10n, line.state).toLowerCase(),
              ),
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            for (final state in options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _Dot(color: ingredientStateColor(state), size: 12),
                title: Text(
                  ingredientStateLabel(l10n, state),
                  style: AppTypography.body,
                ),
                onTap: () => Navigator.of(context).pop(state),
              ),
          ],
        ),
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

/// Spec 028 §A — the bottom tabs that toggle the Compra sub-mode (Comandes / En
/// persona) for the session. The persisted default (Configuració) decides which
/// one is shown first; this just flips the in-session flag.
class _ModeToggleBar extends StatelessWidget {
  const _ModeToggleBar({required this.mode, required this.onChanged});

  final ShoppingMode mode;
  final ValueChanged<ShoppingMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SegmentedChoice<ShoppingMode>(
        value: mode,
        onChanged: onChanged,
        options: [
          SegmentedChoiceOption(
            ShoppingMode.comandes,
            l10n.shoppingModeComandes,
          ),
          SegmentedChoiceOption(
            ShoppingMode.enPersona,
            l10n.shoppingModeEnPersona,
          ),
        ],
      ),
    );
  }
}
