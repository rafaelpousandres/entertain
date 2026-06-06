import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../data/ingredient_state.dart';
import '../data/message_composer.dart';
import '../data/shopping_delta.dart';
import '../data/shopping_models.dart';
import '../data/shopping_providers.dart';
import '../ingredient_state_format.dart';
import '../supplier_category_format.dart';

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
  ConsumerState<EventShoppingPanel> createState() =>
      _EventShoppingPanelState();
}

class _EventShoppingPanelState extends ConsumerState<EventShoppingPanel> {
  final _expanded = <String, bool>{};

  /// Reserved key for the consultive "no category" section's expand state in
  /// [_expanded]; it cannot collide with a real category id (a uuid).
  static const String _uncategorisedKey = '__uncategorised__';

  /// "Usa com a llista de la compra" (Fixes round 3 §2.3): turns the section's
  /// `to_order` lines into a plain text shopping list — the same per-line format
  /// as the supplier message (quantity, unit suppression, Catalan elision,
  /// prep note) but without greeting / needed-by / signature — copies it to the
  /// clipboard, confirms with a toast, and moves those lines to `ordered` so the
  /// state machine reflects that the user has taken on the purchase themselves.
  Future<void> _useAsShoppingList(
    List<ShoppingLine> toOrderLines,
    Map<String, Unit> unitsById,
  ) async {
    if (toOrderLines.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final messenger = ScaffoldMessenger.of(context);

    final text = [
      for (final line in toOrderLines)
        composeItemLine(
          quantity: formatQuantity(line.quantity),
          // A unit flagged omit_in_display drops out with its connector → "3 ous".
          unit: (unitsById[line.unitId]?.omitInDisplay ?? true)
              ? null
              : unitsById[line.unitId]?.name,
          connector: l10n.messageItemConnector,
          ingredientName: line.ingredientName,
          prepNote: line.prepNote,
          // Catalan-only "de" → "d'" elision before vowels / h.
          elideConnector: locale.languageCode == 'ca',
        ),
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: text));
    await ref.read(shoppingRepositoryProvider).updateLineStates(
          [for (final line in toOrderLines) line.id],
          IngredientState.ordered,
        );
    ref.invalidate(eventShoppingProvider(widget.eventId));
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.shoppingListCopiedToast)),
    );
  }

  Future<void> _changeState(ShoppingLine line, {required bool isPantry}) async {
    final options = allowedTransitions(line.state, isPantry: isPantry);
    if (options.isEmpty) return;
    final picked = await showModalBottomSheet<IngredientState>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheetContext) =>
          _StateSheet(line: line, options: options),
    );
    if (picked == null || picked == line.state) return;
    await ref.read(shoppingRepositoryProvider).updateLineState(line.id, picked);
    ref.invalidate(eventShoppingProvider(widget.eventId));
  }

  Future<void> _markAllReceived(List<String> orderedLineIds) async {
    if (orderedLineIds.isEmpty) return;
    await ref
        .read(shoppingRepositoryProvider)
        .updateLineStates(orderedLineIds, IngredientState.received);
    ref.invalidate(eventShoppingProvider(widget.eventId));
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
        child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    final shopping = shoppingAsync.value!;
    final categoriesById = {for (final c in categoriesAsync.value!) c.id: c};
    final unitsById = {for (final u in unitsAsync.value!) u.id: u};

    // Fixes round 2 §2.2: derive the "Retrassat" overlay per line — an `ordered`
    // line whose most recent order is past its needed-by date. Computed once
    // here at render time (no persistence) and looked up by line id downstream.
    final neededBy = neededByByItem(shopping.orders);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final displayStates = <String, DisplayState>{
      for (final line in shopping.lines)
        line.id: DisplayState.of(
          line.state,
          delayed: lineIsDelayed(line, neededBy, today),
        ),
    };

    final linesByCat = linesByCategory(shopping.lines);

    final uncategorised = [
      for (final line in shopping.lines)
        if (line.supplierCategoryId == null) line,
    ];

    if (linesByCat.isEmpty && uncategorised.isEmpty) {
      return _PanelEmpty(text: l10n.shoppingEmptyBody);
    }

    final ordered = _orderedCategoryIds(linesByCat.keys.toSet(), categoriesById);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        _SummaryHeader(lines: shopping.lines, displayStates: displayStates),
        const SizedBox(height: 16),
        for (final categoryId in ordered)
          _CategorySection(
            category: categoriesById[categoryId],
            lines: linesByCat[categoryId] ?? const [],
            displayStates: displayStates,
            unitsById: unitsById,
            expanded: _expanded[categoryId] ?? true,
            onToggleExpanded: () => setState(
              () => _expanded[categoryId] = !(_expanded[categoryId] ?? true),
            ),
            onSend: () =>
                context.push('/events/${widget.eventId}/orders/$categoryId'),
            onChangeState: _changeState,
            onMarkAllReceived: _markAllReceived,
            onUseAsShoppingList: _useAsShoppingList,
          ),
        if (uncategorised.isNotEmpty)
          _UncategorisedSection(
            lines: uncategorised,
            displayStates: displayStates,
            unitsById: unitsById,
            expanded: _expanded[_uncategorisedKey] ?? true,
            onToggleExpanded: () => setState(
              () => _expanded[_uncategorisedKey] =
                  !(_expanded[_uncategorisedKey] ?? true),
            ),
            onChangeState: _changeState,
            onMarkAllReceived: _markAllReceived,
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
/// `to_order`; mark-all-received = `ordered`), not the display overlay.
Map<IngredientState, int> _countStates(List<ShoppingLine> lines) {
  final counts = {for (final s in IngredientState.values) s: 0};
  for (final line in lines) {
    counts[line.state] = (counts[line.state] ?? 0) + 1;
  }
  return counts;
}

/// Counts each [DisplayState] across [lines] (zeros included), resolving each
/// line through [displayStates] so the derived "Retrassat" overlay is counted
/// as its own group (Fixes round 2 §2.2).
Map<DisplayState, int> _countDisplay(
  List<ShoppingLine> lines,
  Map<String, DisplayState> displayStates,
) {
  final counts = {for (final s in DisplayState.values) s: 0};
  for (final line in lines) {
    final s = displayStates[line.id] ?? DisplayState.of(line.state, delayed: false);
    counts[s] = (counts[s] ?? 0) + 1;
  }
  return counts;
}

/// Global summary at the top of the panel (Spec 007 §3.4): the total ingredient
/// count and a coloured-dot legend with the count of each state, including the
/// derived "Retrassat" count (Fixes round 2 §2.2).
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.lines, required this.displayStates});

  final List<ShoppingLine> lines;
  final Map<String, DisplayState> displayStates;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final counts = _countDisplay(lines, displayStates);
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

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.lines,
    required this.displayStates,
    required this.unitsById,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onSend,
    required this.onChangeState,
    required this.onMarkAllReceived,
    required this.onUseAsShoppingList,
  });

  final SupplierCategory? category;
  final List<ShoppingLine> lines;
  final Map<String, DisplayState> displayStates;
  final Map<String, Unit> unitsById;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onSend;
  final void Function(ShoppingLine line, {required bool isPantry}) onChangeState;
  final void Function(List<String> orderedLineIds) onMarkAllReceived;
  final void Function(
    List<ShoppingLine> toOrderLines,
    Map<String, Unit> unitsById,
  ) onUseAsShoppingList;

  @override
  Widget build(BuildContext context) {
    final code = category?.code ?? '';
    final isPantry = isPantryCategory(code);
    final counts = _countStates(lines);
    final toOrder = counts[IngredientState.toOrder] ?? 0;
    final orderedCount = counts[IngredientState.ordered] ?? 0;
    final orderedIds = [
      for (final line in lines)
        if (line.state == IngredientState.ordered) line.id,
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
            displayStates: displayStates,
            unitsById: unitsById,
            isPantry: isPantry,
            onChangeState: onChangeState,
          ),
          const SizedBox(height: 4),
          _SectionFooter(
            // Pantry / Rebost is consultive: no send, no shop-list action, and
            // no bulk "mark all as received" — its binary model has no
            // `ordered` state (Fixes §2.4).
            showSend: !isPantry && toOrder > 0,
            // Fixes round 3 §2.3: the shop-list action consumes the `to_order`
            // lines, so it is offered only when there are some.
            showUseAsList: !isPantry && toOrder > 0,
            showMarkReceived: !isPantry && orderedCount > 0,
            onSend: onSend,
            onMarkAllReceived: () => onMarkAllReceived(orderedIds),
            onUseAsList: () => onUseAsShoppingList(toOrderLines, unitsById),
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
    required this.displayStates,
    required this.unitsById,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onChangeState,
    required this.onMarkAllReceived,
  });

  final List<ShoppingLine> lines;
  final Map<String, DisplayState> displayStates;
  final Map<String, Unit> unitsById;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final void Function(ShoppingLine line, {required bool isPantry}) onChangeState;
  final void Function(List<String> orderedLineIds) onMarkAllReceived;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final counts = _countStates(lines);
    final orderedCount = counts[IngredientState.ordered] ?? 0;
    final orderedIds = [
      for (final line in lines)
        if (line.state == IngredientState.ordered) line.id,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fixes §2.2: supplier name only; counts live in the sub-group headers.
        SectionHeader(
          icon: Icons.label_off_outlined,
          label: l10n.shoppingUncategorisedLabel,
          expanded: expanded,
          onToggle: onToggleExpanded,
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
            displayStates: displayStates,
            unitsById: unitsById,
            isPantry: false,
            onChangeState: onChangeState,
          ),
          if (orderedCount > 0) ...[
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
    required this.displayStates,
    required this.unitsById,
    required this.isPantry,
    required this.onChangeState,
  });

  final List<ShoppingLine> lines;
  final Map<String, DisplayState> displayStates;
  final Map<String, Unit> unitsById;
  final bool isPantry;
  final void Function(ShoppingLine line, {required bool isPantry}) onChangeState;

  DisplayState _displayOf(ShoppingLine line) =>
      displayStates[line.id] ?? DisplayState.of(line.state, delayed: false);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final byState = {
      for (final state in DisplayState.values)
        state: [for (final l in lines) if (_displayOf(l) == state) l],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final state in kDisplayStateOrder)
          if ((byState[state] ?? const []).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Row(
                children: [
                  _Dot(color: displayStateColor(state), size: 8),
                  const SizedBox(width: 6),
                  Text(
                    '${displayStateLabel(l10n, state)} · ${byState[state]!.length}',
                    style: AppTypography.label
                        .copyWith(color: AppColors.textSecondary),
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
                  onTap: () => onChangeState(line, isPantry: isPantry),
                ),
              ),
          ],
      ],
    );
  }
}

class _SectionFooter extends StatelessWidget {
  const _SectionFooter({
    required this.showSend,
    required this.showUseAsList,
    required this.showMarkReceived,
    required this.onSend,
    required this.onMarkAllReceived,
    required this.onUseAsList,
  });

  final bool showSend;
  final bool showUseAsList;
  final bool showMarkReceived;
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
    required this.onTap,
  });

  final ShoppingLine line;
  final DisplayState displayState;
  final Unit? unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final qty = formatQuantity(line.quantity);
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
                style:
                    AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(width: 10),
              _Dot(color: displayStateColor(displayState)),
              const SizedBox(width: 6),
              Text(
                displayStateLabel(l10n, displayState).toLowerCase(),
                style: AppTypography.caption.copyWith(
                  color: displayStateColor(displayState),
                ),
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

  final ShoppingLine line;
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
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
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
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
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
