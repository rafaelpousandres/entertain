import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_restart.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../data/account_repository.dart';

/// Spec 035 §D — the "Delete my account and data" action in Settings ›
/// Privacy & data.
///
/// The stores require that deletion can be *initiated and completed in the
/// app*, without emailing anyone. The flow: one clear confirmation that lists
/// what goes and says it cannot be undone → the server deletes everything →
/// a confirmation that it is done → the app restarts as on first launch (a
/// new, empty anonymous account).
class DeleteAccountSection extends ConsumerStatefulWidget {
  const DeleteAccountSection({super.key});

  @override
  ConsumerState<DeleteAccountSection> createState() =>
      _DeleteAccountSectionState();
}

class _DeleteAccountSectionState extends ConsumerState<DeleteAccountSection> {
  bool _deleting = false;

  Future<void> _onPressed() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDeleteAccountDialog(context);
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final repo = ref.read(accountRepositoryProvider);
    try {
      await repo.deleteAccount();
    } catch (e) {
      debugPrint('account: deletion failed — $e');
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.deleteAccountError)));
      return;
    }
    await repo.forgetLocalAccount();
    if (!mounted) return;

    // Tell the user it is done (the stores ask for a confirmation), then start
    // over. Not dismissible by tapping outside: there is nothing to go back to.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(l10n.deleteAccountDone, style: AppTypography.body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                l10n.deleteAccountDoneButton,
                style: AppTypography.button.copyWith(
                  color: AppColors.accentSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    // Start over: back to the first screen, under a brand-new ProviderScope
    // whose bootstrap creates a fresh anonymous account.
    final restart = AppRestart.maybeOf(context);
    if (restart == null) return;
    appRouter.go('/events');
    // Let the navigation settle before the tree is swapped, so the new app
    // starts from the first screen rather than from this (now stale) one.
    await WidgetsBinding.instance.endOfFrame;
    restart.restart();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settingsDeleteAccountHelp,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _deleting ? null : _onPressed,
            child: _deleting
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          l10n.deleteAccountInProgress,
                          style: AppTypography.button,
                        ),
                      ),
                    ],
                  )
                : Text(
                    l10n.settingsDeleteAccountAction,
                    style: AppTypography.button.copyWith(
                      color: AppColors.danger,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
        ),
      ],
    );
  }
}

/// The single confirmation before deleting the account (director decision,
/// Spec 035 plan §1): what is deleted, that it is irreversible, a red
/// "Delete everything" and a Cancel. Resolves to true only on the red button.
Future<bool?> showDeleteAccountDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        l10n.deleteAccountDialogTitle,
        style: AppTypography.sectionTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.deleteAccountDialogIntro,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in [
              l10n.deleteAccountItemEvents,
              l10n.deleteAccountItemCatalog,
              l10n.deleteAccountItemSuppliers,
              l10n.deleteAccountItemPhotos,
              l10n.deleteAccountItemAccount,
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $item', style: AppTypography.body),
              ),
            const SizedBox(height: 10),
            Text(
              l10n.deleteAccountDialogWarning,
              style: AppTypography.body.copyWith(color: AppColors.danger),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            l10n.cancelAction,
            style: AppTypography.button.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.deleteAccountConfirmButton),
        ),
      ],
    ),
  );
}
