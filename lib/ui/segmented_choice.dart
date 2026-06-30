import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'input_pill.dart';

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
  const SegmentedChoiceOption(
    this.value,
    this.label, {
    this.icon,
    this.selectedColor,
  });

  final T value;
  final String label;

  /// When set, the chip renders this icon instead of the [label] text, and the
  /// [label] becomes the long-press tooltip (Fixes round 3 §2.2: icon chips for
  /// the channel selector, which truncated as text on narrow widths).
  final IconData? icon;

  /// Spec 032 §B — the fill colour for this option's pressed state. Null falls
  /// back to the app's selected accent. Lets a domain pass a per-option palette
  /// (e.g. the guest-status traffic-light).
  final Color? selectedColor;
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
    // Spec 032 §B: every segmented choice is now the shared [InputPill]
    // (neutral → coloured fill + checkmark). The per-option [selectedColor]
    // tints the pressed fill; the default is the app's selected accent.
    return InputPill(
      label: option.label,
      icon: option.icon,
      selected: selected,
      onTap: onTap,
      pressed: (
        bg: option.selectedColor ?? AppColors.accentSecondary,
        fg: AppColors.onAccent,
      ),
    );
  }
}
