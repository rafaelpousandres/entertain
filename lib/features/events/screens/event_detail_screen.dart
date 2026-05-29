import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/icon_circle.dart';
import '../../../ui/section_header.dart';
import '../data/event.dart';
import '../data/event_dish.dart';
import '../data/events_providers.dart';
import '../widgets/event_formatters.dart';

/// Event detail / menu screen (spec 003 §2.4).
///
/// Header with title + a date/guest metadata line + an edit affordance,
/// followed by the menu grouped by dish category. Adding dishes belongs
/// to screen group 2, so the menu shows a clear empty state for now.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final eventAsync = ref.watch(eventByIdProvider(eventId));

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
            onRetry: () => ref.invalidate(eventByIdProvider(eventId)),
          ),
          data: (event) => _DetailBody(event: event),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final dishesAsync = ref.watch(eventDishesProvider(event.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
        if (event.notes != null && event.notes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            event.notes!,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 24),
        Text(l10n.menuSectionTitle, style: AppTypography.sectionTitle),
        const SizedBox(height: 8),
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
              : _MenuByCategory(dishes: dishes),
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
  const _MenuByCategory({required this.dishes});

  final List<EventDish> dishes;

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
              icon: _iconFor(category),
              label: _labelFor(l10n, category),
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
                      child: _DishRow(name: dish.name),
                    ),
                  const SizedBox(height: 4),
                ],
              ),
          ],
      ],
    );
  }

  IconData _iconFor(DishCategory category) => switch (category) {
    DishCategory.aperitif => Icons.cookie_outlined,
    DishCategory.starter => Icons.eco_outlined,
    DishCategory.main => Icons.restaurant_outlined,
    DishCategory.dessert => Icons.cake_outlined,
    DishCategory.drink => Icons.local_bar_outlined,
    DishCategory.other => Icons.restaurant_menu_outlined,
  };

  String _labelFor(AppLocalizations l10n, DishCategory category) =>
      switch (category) {
        DishCategory.aperitif => l10n.dishCategoryAperitif,
        DishCategory.starter => l10n.dishCategoryStarter,
        DishCategory.main => l10n.dishCategoryMain,
        DishCategory.dessert => l10n.dishCategoryDessert,
        DishCategory.drink => l10n.dishCategoryDrink,
        DishCategory.other => l10n.dishCategoryOther,
      };
}

class _DishRow extends StatelessWidget {
  const _DishRow({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: AppTypography.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.disabled, size: 22),
        ],
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
