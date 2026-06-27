import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/primary_button.dart';
import '../data/hint.dart';
import '../data/hint_selection.dart';
import '../data/hints_providers.dart';

final _random = Random();
int _randomIndex(int n) => _random.nextInt(n);

/// Spec 026 A.2 — shows the once-per-open hints surface as a dismissable bottom
/// sheet over the home. [first] is the hint to open on (the welcome hint the
/// first ever time, otherwise a random tip). "Més…" browses more; the close
/// button / "Entesos" dismisses; the checkbox turns hints off for good.
Future<void> showHintsOnEntry(
  BuildContext context,
  List<Hint> hints,
  Hint first,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _HintsSheet(hints: hints, first: first),
  );
}

class _HintsSheet extends ConsumerStatefulWidget {
  const _HintsSheet({required this.hints, required this.first});

  final List<Hint> hints;
  final Hint first;

  @override
  ConsumerState<_HintsSheet> createState() => _HintsSheetState();
}

class _HintsSheetState extends ConsumerState<_HintsSheet> {
  late Hint _current = widget.first;

  /// Advance to another random tip (never an immediate repeat). Works from the
  /// welcome hint too, so it is not a dead end.
  void _more() {
    final next = randomTip(
      widget.hints,
      randomIndex: _randomIndex,
      excludeKey: _current.key,
    );
    if (next != null) setState(() => _current = next);
  }

  /// The checkbox is "No mostrar més pistes": checked → hints disabled.
  Future<void> _setDisabled(bool? checked) async {
    await ref.read(hintsEnabledProvider.notifier).set(!(checked ?? false));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(hintsEnabledProvider).value ?? true;
    final hasMoreTips = widget.hints.where((h) => h.kind == HintKind.tip).length > 1;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.accentSecondary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(l10n.hintsTitle, style: AppTypography.sectionTitle),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.textTertiary),
                  tooltip: l10n.hintsDismissAction,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _current.text,
              style: AppTypography.body.copyWith(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: () => _setDisabled(enabled),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: !enabled,
                        onChanged: _setDisabled,
                        activeColor: AppColors.accent,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.hintsDisableCheckbox,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (hasMoreTips)
                  TextButton.icon(
                    onPressed: _more,
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: Text(l10n.hintsMoreAction),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accentSecondary,
                    ),
                  ),
                const Spacer(),
                SizedBox(
                  width: 140,
                  child: PrimaryButton(
                    label: l10n.hintsDismissAction,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
