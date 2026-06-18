import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/edit_scaffold.dart';
import '../../../ui/stepper_field.dart';
import '../../../util/text_case.dart';
import '../../catalog/data/denomination.dart';
import '../../shopping/data/shopping_providers.dart' show eventShoppingProvider;
import '../data/event_drink.dart';
import '../data/events_providers.dart';

/// Edit a drink's per-event unit quantity (Spec 017 §A.3).
///
/// Replaces the on-the-fly bottom sheet: editing is now an explicit-save screen
/// like every other editor — the quantity is held in a local draft, the AppBar
/// ✓ persists it, and the back arrow discards (confirming if there are unsaved
/// changes) via the shared [EditScaffold]. The denomination is shown read-only
/// for context (it is set on the catalog drink, not per event).
class EditEventDrinkScreen extends ConsumerStatefulWidget {
  const EditEventDrinkScreen({
    super.key,
    required this.eventId,
    required this.drink,
  });

  final String eventId;
  final EventDrink drink;

  @override
  ConsumerState<EditEventDrinkScreen> createState() =>
      _EditEventDrinkScreenState();
}

class _EditEventDrinkScreenState extends ConsumerState<EditEventDrinkScreen> {
  late int _quantity = widget.drink.quantity;
  bool _saving = false;

  bool get _dirty => _quantity != widget.drink.quantity;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(eventsRepositoryProvider)
          .updateEventDrinkQuantity(widget.drink.id, _quantity);
      ref.invalidate(eventDrinksProvider(widget.eventId));
      ref.invalidate(eventShoppingProvider(widget.eventId));
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.eventsLoadError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EditScaffold(
      title: capitalizeFirst(widget.drink.name),
      hasUnsavedChanges: _dirty,
      busy: _saving,
      onSave: _saving ? null : _save,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          // The denomination is fixed on the catalog drink; shown here read-only
          // so the quantity reads in context ("3 ampolles").
          FieldLabel(
            label: l10n.drinkDenominationLabel,
            child: Text(
              denominationName(l10n, widget.drink.denomination),
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          FieldLabel(
            label: l10n.drinkQuantityLabel,
            child: StepperField(
              value: _quantity,
              onChanged: (v) => setState(() => _quantity = v),
            ),
          ),
        ],
      ),
    );
  }
}
