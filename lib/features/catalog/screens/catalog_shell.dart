import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/help_icon_button.dart';
import 'begudes_catalog_screen.dart';
import 'dish_catalog_screen.dart';
import 'ingredient_catalog_screen.dart';

/// Spec 014 §2.2 — the grouped "Catàleg" destination. The owner chose to
/// collapse the catalogs into one bottom-nav destination (Esdeveniments ·
/// Catàleg · Configuració) rather than add a 5th icon, with the three catalogs
/// as tabs. This shell owns the single AppBar (title + the active tab's help)
/// and the TabBar; each tab body is an app-bar-less catalog screen that keeps
/// its own "New …" bottom action.
class CatalogShell extends StatefulWidget {
  const CatalogShell({super.key, this.initialIndex = 0});

  /// Which tab to open on first build (Plats · Ingredients · Begudes). Lets the
  /// legacy `/dishes` and `/ingredients` deep links land on the right tab.
  final int initialIndex;

  @override
  State<CatalogShell> createState() => _CatalogShellState();
}

class _CatalogShellState extends State<CatalogShell>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex.clamp(0, 2),
    );
    // Rebuild so the AppBar's help button tracks the active tab.
    _controller.addListener(() {
      if (!_controller.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final help = switch (_controller.index) {
      1 => (title: l10n.ingredientsScreenTitle, body: l10n.helpIngredientsBody),
      2 => (title: l10n.drinksScreenTitle, body: l10n.helpDrinksBody),
      _ => (title: l10n.dishesScreenTitle, body: l10n.helpDishesBody),
    };

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(l10n.catalogScreenTitle, style: AppTypography.display),
        actions: [HelpIconButton(title: help.title, body: help.body)],
        bottom: TabBar(
          controller: _controller,
          labelColor: AppColors.accentSecondary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accentSecondary,
          tabs: [
            Tab(text: l10n.navDishes),
            Tab(text: l10n.navIngredients),
            Tab(text: l10n.navDrinks),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: const [
          DishCatalogScreen(),
          IngredientCatalogScreen(),
          BegudesCatalogScreen(),
        ],
      ),
    );
  }
}
