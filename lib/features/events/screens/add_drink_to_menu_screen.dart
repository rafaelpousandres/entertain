import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/data/drink.dart';
import '../../shopping/data/shopping_providers.dart' show eventShoppingProvider;
import '../data/events_providers.dart';

/// Add a catalog drink to an event's menu (Spec 014 §2.3), mirroring the
/// add-dish flow. Lists the group's drinks; tapping one copies it into the
/// event (scaled to the guest count) and pops back.
class AddDrinkToMenuScreen extends ConsumerStatefulWidget {
  const AddDrinkToMenuScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<AddDrinkToMenuScreen> createState() =>
      _AddDrinkToMenuScreenState();
}

class _AddDrinkToMenuScreenState extends ConsumerState<AddDrinkToMenuScreen> {
  bool _busy = false;

  Future<void> _add(Drink drink) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(eventsRepositoryProvider)
          .addDrinkToEvent(eventId: widget.eventId, drinkId: drink.id);
      ref.invalidate(eventDrinksProvider(widget.eventId));
      ref.invalidate(eventShoppingProvider(widget.eventId));
      ref.invalidate(eventReadinessProvider);
      ref.invalidate(eventsListProvider);
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.drinkSaveError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final drinksAsync = ref.watch(drinksListProvider);
    final inMenuAsync = ref.watch(eventDrinksProvider(widget.eventId));
    final inMenu = {
      for (final d in inMenuAsync.value ?? const []) d.sourceDrinkId,
    };

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(l10n.addDrinkScreenTitle, style: AppTypography.sectionTitle),
      ),
      body: SafeArea(
        top: false,
        child: drinksAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.drinksLoadError,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (drinks) {
            if (drinks.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.drinksEmptyBody,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                for (final drink in drinks) ...[
                  _DrinkPickRow(
                    drink: drink,
                    alreadyInMenu: inMenu.contains(drink.id),
                    onTap: () => _add(drink),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DrinkPickRow extends StatelessWidget {
  const _DrinkPickRow({
    required this.drink,
    required this.alreadyInMenu,
    required this.onTap,
  });

  final Drink drink;
  final bool alreadyInMenu;
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
                child: Text(
                  drink.name,
                  style: AppTypography.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (alreadyInMenu) ...[
                Text(
                  l10n.drinkInMenuBadge,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.add, color: AppColors.accentSecondary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
