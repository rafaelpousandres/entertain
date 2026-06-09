import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';

/// What the user chose in the photo options sheet (Spec 009 §2.2.4).
enum PhotoSheetChoice { camera, gallery, remove }

/// Bottom sheet offering "Take a photo" / "Pick from gallery", and "Remove
/// photo" when [canRemove] is true. Returns the chosen [PhotoSheetChoice], or
/// null if dismissed. Styled like the rest of the app's sheets (design system
/// §5: `surface`, rounded top, a drag handle).
Future<PhotoSheetChoice?> showPhotoSourceSheet(
  BuildContext context, {
  required bool canRemove,
}) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<PhotoSheetChoice>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _SheetTile(
            icon: Icons.photo_camera_outlined,
            label: l10n.photoTakePhoto,
            onTap: () =>
                Navigator.of(sheetContext).pop(PhotoSheetChoice.camera),
          ),
          _SheetTile(
            icon: Icons.photo_library_outlined,
            label: l10n.photoPickGallery,
            onTap: () =>
                Navigator.of(sheetContext).pop(PhotoSheetChoice.gallery),
          ),
          if (canRemove)
            _SheetTile(
              icon: Icons.delete_outline,
              label: l10n.photoRemovePhoto,
              danger: true,
              onTap: () =>
                  Navigator.of(sheetContext).pop(PhotoSheetChoice.remove),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: danger ? AppColors.danger : AppColors.accentSecondary),
      title: Text(label, style: AppTypography.body.copyWith(color: color)),
      onTap: onTap,
    );
  }
}
