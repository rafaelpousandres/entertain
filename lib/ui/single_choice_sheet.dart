import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// One option in a [showSingleChoiceSheet].
class SingleChoiceOption<T> {
  const SingleChoiceOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Modal single-choice picker for medium-length option lists (units,
/// supplier categories) — the case the inline `SegmentedChoice` chips don't
/// cover well. Design system §5: `surface` sheet, rounded top, each row
/// uses the selection control (empty `disabled`-bordered circle, or a
/// filled `accent-secondary` circle with a white check when selected).
///
/// Tapping an option invokes [onSelected] and closes the sheet. When
/// [onCleared] is provided an extra "clear" row is shown at the top
/// (selected when [selectedValue] is null) for optional fields.
Future<void> showSingleChoiceSheet<T>({
  required BuildContext context,
  required String title,
  required List<SingleChoiceOption<T>> options,
  required T? selectedValue,
  required ValueChanged<T> onSelected,
  VoidCallback? onCleared,
  String? clearLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(title, style: AppTypography.sectionTitle),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  children: [
                    if (onCleared != null)
                      _ChoiceRow(
                        label: clearLabel ?? '—',
                        selected: selectedValue == null,
                        muted: true,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          onCleared();
                        },
                      ),
                    for (final option in options)
                      _ChoiceRow(
                        label: option.label,
                        selected: option.value == selectedValue,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          onSelected(option.value);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.muted = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.body.copyWith(
                    color: muted
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              _SelectionCircle(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selection control from the design system: an empty circle with a
/// `disabled` border when unselected, or a filled `accent-secondary` circle
/// with a white check when selected.
class _SelectionCircle extends StatelessWidget {
  const _SelectionCircle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.accentSecondary : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.accentSecondary : AppColors.disabled,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 14, color: AppColors.onAccent)
          : null,
    );
  }
}
