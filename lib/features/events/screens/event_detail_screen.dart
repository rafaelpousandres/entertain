import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/icon_circle.dart';
import '../../../ui/primary_button.dart';
import '../../../ui/section_header.dart';
import '../../../ui/segmented_choice.dart';
import '../../catalog/data/dish_category.dart';
import '../../shopping/screens/event_shopping_panel.dart';
import '../data/event.dart';
import '../data/event_dish.dart';
import '../data/events_providers.dart';
import '../widgets/event_formatters.dart';

/// Event detail screen (spec 003 §2.4, extended in spec 005 §2.3).
///
/// A shared event header sits above a segmented control that switches between
/// two equal-rank views of the same event: the **menu** (dishes grouped by
/// category) and the **shopping** panel (ingredients grouped by supplier
/// category, with per-category send actions). The "add dish" action belongs
/// to the menu view only.
class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

enum _EventView { menu, shopping }

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  _EventView _view = _EventView.menu;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final eventAsync = ref.watch(eventByIdProvider(widget.eventId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.backAction,
          onPressed: () => context.pop(),
        ),
        title: const SizedBox.shrink(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: eventAsync.maybeWhen(
              data: (event) => IconCircle(
                icon: Icons.edit_outlined,
                onTap: () =>
                    context.push('/events/${event.id}/edit', extra: event),
              ),
              orElse: () => const SizedBox(width: 34, height: 34),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: eventAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (_, _) => _LoadError(
            message: l10n.eventsLoadError,
            onRetry: () => ref.invalidate(eventByIdProvider(widget.eventId)),
          ),
          data: (event) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _EventHeader(event: event, locale: locale),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: SegmentedChoice<_EventView>(
                  value: _view,
                  onChanged: (v) => setState(() => _view = v),
                  options: [
                    SegmentedChoiceOption(_EventView.menu, l10n.eventTabMenu),
                    SegmentedChoiceOption(
                      _EventView.shopping,
                      l10n.eventTabShopping,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _view == _EventView.menu
                    ? _MenuView(event: event)
                    : EventShoppingPanel(eventId: event.id),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: (_view == _EventView.menu)
          ? eventAsync.maybeWhen(
              data: (event) => SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  decoration: const BoxDecoration(
                    color: AppColors.bg,
                    border: Border(
                      top: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: PrimaryButton(
                    label: l10n.addDishToMenuAction,
                    icon: Icons.add,
                    onPressed: () =>
                        context.push('/events/${event.id}/add-dish'),
                  ),
                ),
              ),
              orElse: () => null,
            )
          : null,
    );
  }
}

class _EventHeader extends StatelessWidget {
  const _EventHeader({required this.event, required this.locale});

  final Event event;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(event.title, style: AppTypography.display),
        const SizedBox(height: 6),
        Text(
          eventDetailMetadata(l10n, event, locale),
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        if (event.locationName != null && event.locationName!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 16,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  event.locationName!,
                  style: AppTypography.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MenuView extends ConsumerWidget {
  const _MenuView({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dishesAsync = ref.watch(eventDishesProvider(event.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (event.notes != null && event.notes!.isNotEmpty) ...[
          Text(
            event.notes!,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
        ],
        dishesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              l10n.eventsLoadError,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          data: (dishes) => dishes.isEmpty
              ? const _MenuEmpty()
              : _MenuByCategory(dishes: dishes, eventId: event.id),
        ),
      ],
    );
  }
}

class _MenuEmpty extends StatelessWidget {
  const _MenuEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        l10n.menuEmptyBody,
        textAlign: TextAlign.center,
        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _MenuByCategory extends StatefulWidget {
  const _MenuByCategory({required this.dishes, required this.eventId});

  final List<EventDish> dishes;
  final String eventId;

  @override
  State<_MenuByCategory> createState() => _MenuByCategoryState();
}

class _MenuByCategoryState extends State<_MenuByCategory> {
  late final Map<DishCategory, bool> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = {for (final c in DishCategory.values) c: true};
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final byCategory = <DishCategory, List<EventDish>>{};
    for (final dish in widget.dishes) {
      byCategory.putIfAbsent(dish.category, () => []).add(dish);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final category in dishCategoryOrder)
          if (byCategory[category] != null) ...[
            SectionHeader(
              icon: dishCategoryIcon(category),
              label: dishCategoryLabel(l10n, category),
              count: byCategory[category]!.length,
              expanded: _expanded[category]!,
              onToggle: () =>
                  setState(() => _expanded[category] = !_expanded[category]!),
            ),
            if (_expanded[category]!)
              Column(
                children: [
                  for (final dish in byCategory[category]!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _DishRow(
                        dish: dish,
                        onTap: () => context.push(
                          '/events/${widget.eventId}/dishes/${dish.id}',
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                ],
              ),
          ],
      ],
    );
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow({required this.dish, required this.onTap});

  final EventDish dish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dish.name,
                      style: AppTypography.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.eventDishServings(dish.servings),
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: AppColors.disabled,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
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
