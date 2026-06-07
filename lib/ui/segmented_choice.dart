import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Inline single-choice control for short enum-like options (event type,
/// event format). Selected option uses the secondary accent so it stays
/// consistent with the design system's selected-state rule (§5).
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<SegmentedChoiceOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _Chip<T>(
            option: option,
            selected: option.value == value,
            onTap: () => onChanged(option.value),
          ),
      ],
    );
  }
}

class SegmentedChoiceOption<T> {
  const SegmentedChoiceOption(this.value, this.label, {this.icon});

  final T value;
  final String label;

  /// When set, the chip renders this icon instead of the [label] text, and the
  /// [label] becomes the long-press tooltip (Fixes round 3 §2.2: icon chips for
  /// the channel selector, which truncated as text on narrow widths).
  final IconData? icon;
}

class _Chip<T> extends StatelessWidget {
  const _Chip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final SegmentedChoiceOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.accentSecondarySoft : AppColors.surface;
    final fg = selected ? AppColors.accentSecondary : AppColors.textPrimary;
    final borderColor = selected ? AppColors.accentSecondary : AppColors.border;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: option.icon != null
              ? Tooltip(
                  message: option.label,
                  child: Icon(option.icon, size: 20, color: fg),
                )
              : Text(
                  option.label,
                  style: AppTypography.label.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
        ),
      ),
    );
  }
}
