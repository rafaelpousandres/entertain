import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/supabase_bootstrap.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Placeholder screen — same role as in spec 001 (proving the theme,
/// fonts and l10n are wired) plus the spec 002 backend-connectivity
/// indicator beneath the body copy.
class PlaceholderScreen extends ConsumerWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bootstrap = ref.watch(backendBootstrapProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.placeholderTitle,
                  style: AppTypography.display,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.placeholderBody,
                  style: AppTypography.body
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _BackendStatusRow(
                  bootstrap: bootstrap,
                  l10n: l10n,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Single-line backend connectivity readout. Kept minimal on purpose —
/// spec 002 only asks for a temporary check that proves Supabase is wired.
class _BackendStatusRow extends StatelessWidget {
  const _BackendStatusRow({required this.bootstrap, required this.l10n});

  final AsyncValue<BackendBootstrap> bootstrap;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (label, color) = bootstrap.when(
      loading: () => (l10n.backendConnecting, AppColors.textSecondary),
      error: (_, _) => (l10n.backendConnectionFailed, AppColors.accent),
      data: (b) => switch (b.status) {
        BackendStatus.notConfigured => (
          l10n.backendNotConfigured,
          AppColors.textSecondary,
        ),
        BackendStatus.connecting => (
          l10n.backendConnecting,
          AppColors.textSecondary,
        ),
        BackendStatus.connected => (
          l10n.backendConnected,
          AppColors.accent,
        ),
        BackendStatus.failed => (
          l10n.backendConnectionFailed,
          AppColors.accent,
        ),
      },
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.body
              .copyWith(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }
}
