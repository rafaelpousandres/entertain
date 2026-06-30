import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Spec 032 §B — the one shared base for every "input pill" (a selection chip
/// the user taps to choose): dietary axes, event type / format, guest status,
/// shopping mode, message channel, etc. Every family shares the same shape,
/// size, typography, spacing and the same **neutral → pressed** grammar; only
/// the pressed [pressed] palette differs per domain.
///
/// - **Not selected** → neutral: transparent fill, [AppColors.border] outline,
///   secondary text.
/// - **Selected** → fills with [pressed.bg], a leading checkmark, [pressed.fg]
///   text.
///
/// Sized to ~72% of the pre-Spec-031 dietary pill (Spec 032 §B4): padding 14/9,
/// checkmark 16, gap 6, radius 20, font 15 → the constants below.
class InputPill extends StatelessWidget {
  const InputPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.pressed,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// The fill + text colours used in the selected (pressed) state.
  final ({Color bg, Color fg}) pressed;

  /// Optional icon shown instead of the checkmark + label (the [label] becomes a
  /// long-press tooltip). For compact icon selectors.
  final IconData? icon;

  // Spec 032 §B4 — ~72% of the pre-031 original.
  static const double _padH = 10; // 14 → 10
  static const double _padV = 7; //   9 → 7 (rounded up from 6.5)
  static const double _radius = 14; // 20 → 14
  static const double _check = 12; //  16 → 12 (rounded up from 11.5)
  static const double _gap = 4; //     6 → 4
  static const double _font = 11; //  15 → 11

  @override
  Widget build(BuildContext context) {
    final fg = selected ? pressed.fg : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: _padH, vertical: _padV),
        decoration: BoxDecoration(
          color: selected ? pressed.bg : Colors.transparent,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: selected ? pressed.bg : AppColors.border),
        ),
        child: icon != null
            ? Tooltip(
                message: label,
                child: Icon(icon, size: _check + 2, color: fg),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Icon(Icons.check, size: _check, color: fg),
                    const SizedBox(width: _gap),
                  ],
                  Text(
                    label,
                    style: AppTypography.button.copyWith(
                      fontSize: _font,
                      color: fg,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
