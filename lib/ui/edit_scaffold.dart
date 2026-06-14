import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Shared scaffold for edit screens (Spec 008 Fixes §2.3).
///
/// Adopts a single, consistent pattern across every edit screen so the same
/// behaviour is guaranteed everywhere and future screens inherit it for free:
///
///   * The primary **save** action lives in the AppBar as a trailing check
///     icon, so it is always visible regardless of the on-screen keyboard
///     (the old bottom "Desa" button was hidden by the keyboard).
///   * An **unsaved-changes guard**: trying to leave the screen — the system
///     back gesture or the AppBar back arrow — while [hasUnsavedChanges] is
///     true prompts a confirmation dialog before the work is discarded.
///
/// Persisting and popping on save stay the caller's responsibility ([onSave]);
/// this widget only surfaces the action and guards the exit. Both the gesture
/// and the arrow funnel through [PopScope], so the guard can never be bypassed.
class EditScaffold extends StatelessWidget {
  const EditScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.hasUnsavedChanges,
    required this.onSave,
    this.busy = false,
    this.showSave = true,
    this.trailingActions = const [],
    this.bottomBar,
    this.onDiscard,
  });

  /// AppBar title text, styled as a section title.
  final String title;

  /// Screen content. Wrapped in a `SafeArea(top: false)` by this widget.
  final Widget body;

  /// Drives the guard: when true, leaving prompts the discard dialog.
  final bool hasUnsavedChanges;

  /// Invoked by the AppBar check. Null disables the check (e.g. while an
  /// operation is in flight); validation that keeps the action enabled but
  /// surfaces inline errors stays inside the caller's handler.
  final VoidCallback? onSave;

  /// Mid-operation flag: locks navigation and disables the back arrow.
  final bool busy;

  /// Whether to render the save check at all (false for, e.g., a tab with no
  /// save semantics — though tab hosts manage their own AppBar).
  final bool showSave;

  /// Extra AppBar actions placed to the right of the save check — typically an
  /// overflow menu (delete / remove), which by convention sits rightmost.
  final List<Widget> trailingActions;

  /// Optional bottom area for secondary actions (none of the editors need one
  /// once the bottom "Desa" is gone; kept for completeness).
  final Widget? bottomBar;

  /// Spec 011 §2.6 — run when the user confirms Discard, before the screen pops
  /// (e.g. to roll back photo changes persisted during the session). Returns
  /// whether to proceed with leaving: false keeps the user on the screen (used
  /// when a photo rollback failed partway and the user must resolve it).
  final Future<bool> Function()? onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !hasUnsavedChanges && !busy,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || busy) return;
        final navigator = Navigator.of(context);
        final discard = await showUnsavedChangesDialog(context);
        if (!discard) return;
        // §2.6: let the caller undo side effects (photo changes) before leaving;
        // it may veto the pop if it couldn't fully roll back.
        final proceed = await onDiscard?.call() ?? true;
        if (proceed && navigator.mounted) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: Text(title, style: AppTypography.sectionTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.backAction,
            // maybePop runs the PopScope guard above instead of popping blindly.
            onPressed: busy ? null : () => Navigator.of(context).maybePop(),
          ),
          actions: [
            if (showSave)
              IconButton(
                icon: const Icon(Icons.check),
                color: AppColors.accentSecondary,
                tooltip: l10n.saveAction,
                onPressed: onSave,
              ),
            ...trailingActions,
          ],
        ),
        body: SafeArea(top: false, child: body),
        bottomNavigationBar: bottomBar,
      ),
    );
  }
}

/// The §2.3 unsaved-changes confirmation dialog. Returns true when the user
/// chooses to discard and leave, false (or on dismiss) to stay. Shared so the
/// tabbed hosts (event detail, settings) can guard with the same dialog without
/// reaching for [EditScaffold].
Future<bool> showUnsavedChangesDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(l10n.unsavedChangesTitle, style: AppTypography.sectionTitle),
      content: Text(
        l10n.unsavedChangesBody,
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
            l10n.discardChangesAction,
            style: AppTypography.button.copyWith(color: AppColors.danger),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
