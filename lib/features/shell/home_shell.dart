import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../catalog/data/catalog_providers.dart' show localeCodeProvider;
import '../hints/data/hint.dart';
import '../hints/data/hint_selection.dart';
import '../hints/data/hints_prefs.dart';
import '../hints/data/hints_providers.dart';
import '../hints/screens/hints_on_entry.dart';

final _random = Random();

/// App shell hosting the top-level sections behind a bottom navigation bar
/// (Specification 004 §3.9, navigation decision: bottom nav). Three co-equal
/// catalog sections (events, dishes, ingredients) plus the global settings
/// screen added as a fourth tab in Specification 005 §2.5. The branch screens
/// scroll inside the shell; detail and editor screens are pushed on the root
/// navigator so they cover the bar and own their action bars.
///
/// Spec 026 A.2: this is also where the once-per-open hints surface is
/// triggered — the shell mounts after the startup bootstrap, over the home.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowHints());
  }

  /// Spec 026 A.2 — show one hint over the home, once per app open: the welcome
  /// hint the first ever time, otherwise a random tip. Suppressed when the user
  /// has turned hints off. Best-effort: any failure (offline, empty set) is
  /// silently skipped so it never blocks the home.
  Future<void> _maybeShowHints() async {
    if (ref.read(hintsSessionShownProvider)) return;
    try {
      final enabled = await ref.read(hintsEnabledProvider.future);
      if (!enabled || !mounted) return;
      if (ref.read(hintsSessionShownProvider)) return; // re-check after await

      final localeCode = ref.read(localeCodeProvider);
      final hints = await ref.read(hintsProvider(localeCode).future);
      if (hints.isEmpty || !mounted) return;

      final welcomeSeen = await HintsPrefs.readWelcomeSeen();
      if (!mounted || ref.read(hintsSessionShownProvider)) return;

      final first = entryHint(
        hints,
        welcomeSeen: welcomeSeen,
        randomIndex: _random.nextInt,
      );
      if (first == null) return;

      ref.read(hintsSessionShownProvider.notifier).markShown();
      if (first.kind == HintKind.welcome) await HintsPrefs.markWelcomeSeen();
      if (!mounted) return;
      await showHintsOnEntry(context, hints, first);
    } catch (_) {
      // Discoverability is non-critical; never surface an error here.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final navigationShell = widget.navigationShell;

    // Spec 014: the catalogs (Plats · Ingredients · Begudes) are grouped under
    // one "Catàleg" destination, so the bottom nav stays at three icons.
    final destinations = <_Destination>[
      _Destination(icon: Icons.event_outlined, label: l10n.navEvents),
      _Destination(
        icon: Icons.restaurant_menu_outlined,
        label: l10n.navCatalog,
      ),
      _Destination(icon: Icons.settings_outlined, label: l10n.navSettings),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: navigationShell,
      bottomNavigationBar: _HomeNavBar(
        destinations: destinations,
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          // Re-tapping the active tab pops it back to its root.
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _HomeNavBar extends StatelessWidget {
  const _HomeNavBar({
    required this.destinations,
    required this.currentIndex,
    required this.onTap,
  });

  final List<_Destination> destinations;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? AppColors.accentSecondary : AppColors.textTertiary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(destination.icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              destination.label,
              style: AppTypography.caption.copyWith(
                color: color,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
