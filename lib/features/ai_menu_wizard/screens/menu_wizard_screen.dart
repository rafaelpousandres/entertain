import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/primary_button.dart';
import '../../../ui/segmented_choice.dart';
import '../../ai_dish_assistant/data/dish_assistant_repository.dart'
    show QuotaExceededException;
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/data/dish_category.dart';
import '../../events/data/events_providers.dart';
import '../../photos/data/media.dart';
import '../../photos/data/media_providers.dart';
import '../data/menu_proposal.dart';
import '../data/menu_wizard_providers.dart';

/// Spec 022 §5 — "Crea / Completa el menú amb IA". A few quick questions →
/// Claude proposes a menu (catalog dishes + new AI dishes + catalog drinks) →
/// the user reviews and deselects any → confirm adds the selected items to the
/// event menu. Quota is charged at propose; a header shows the remaining quota.
class MenuWizardScreen extends ConsumerStatefulWidget {
  const MenuWizardScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<MenuWizardScreen> createState() => _MenuWizardScreenState();
}

/// The three quick questions (2–4 multiple-choice + one free text, §3). Tokens
/// are sent to the Edge Function as-is and interpreted by the prompt; defaults
/// for what the event already knows (# people, format) are not asked again.
enum _MealType { aperitif, lunch, dinner }

enum _Formality { informal, festive, formal }

enum _Dietary { vegetarian, vegan, glutenFree }

String _mealTypeToken(_MealType v) => switch (v) {
  _MealType.aperitif => 'aperitif',
  _MealType.lunch => 'lunch',
  _MealType.dinner => 'dinner',
};

String _formalityToken(_Formality v) => switch (v) {
  _Formality.informal => 'informal',
  _Formality.festive => 'festive',
  _Formality.formal => 'formal',
};

String _dietaryToken(_Dietary v) => switch (v) {
  _Dietary.vegetarian => 'vegetarian',
  _Dietary.vegan => 'vegan',
  _Dietary.glutenFree => 'gluten_free',
};

class _MenuWizardScreenState extends ConsumerState<MenuWizardScreen> {
  final _freeText = TextEditingController();

  _MealType _meal = _MealType.lunch;
  _Formality _formality = _Formality.informal;
  final Set<_Dietary> _dietary = {};
  bool _mealSeeded = false;

  bool _generating = false;
  bool _accepting = false;
  MenuProposal? _proposal;
  Set<int> _selected = {};

  @override
  void dispose() {
    _freeText.dispose();
    super.dispose();
  }

  String get _locale => Localizations.localeOf(context).languageCode;

  /// Default the meal type from the event's own type the first time we know it,
  /// so the most common answer is pre-filled (§3 — don't ask what's known).
  void _seedMeal() {
    if (_mealSeeded) return;
    final event = ref.read(eventByIdProvider(widget.eventId)).value;
    if (event == null) return;
    _mealSeeded = true;
    _meal = switch (event.type.name) {
      'dinner' => _MealType.dinner,
      _ => _MealType.lunch,
    };
  }

  Future<void> _generate() async {
    if (_generating) return;
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _generating = true);
    try {
      final result = await ref.read(menuWizardRepositoryProvider).propose(
        eventId: widget.eventId,
        answers: {
          'meal_type': _mealTypeToken(_meal),
          'formality': _formalityToken(_formality),
          'dietary': _dietary.map(_dietaryToken).toList(),
        },
        freeText: _freeText.text.trim(),
        locale: _locale,
      );
      if (!mounted) return;
      // Quota was charged at propose — refresh the header.
      ref.invalidate(menuWizardQuotaProvider);
      setState(() {
        _generating = false;
        _proposal = result.proposal;
        // Everything selected by default; the user deselects to drop items.
        _selected = {
          for (var i = 0; i < result.proposal.items.length; i++) i,
        };
      });
    } on QuotaExceededException catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      _showLimitReached(e.limit);
    } catch (_) {
      if (!mounted) return;
      setState(() => _generating = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.menuWizardError)));
    }
  }

  Future<void> _confirm() async {
    final proposal = _proposal;
    if (proposal == null || _accepting) return;
    final selectedItems = [
      for (var i = 0; i < proposal.items.length; i++)
        if (_selected.contains(i)) proposal.items[i],
    ];
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (selectedItems.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.menuWizardNoneSelected)),
      );
      return;
    }
    setState(() => _accepting = true);
    try {
      final result = await ref.read(menuWizardRepositoryProvider).accept(
        eventId: widget.eventId,
        items: selectedItems,
      );
      if (!mounted) return;
      // Refresh the Menú tab + any catalog views the new dishes touch.
      ref.invalidate(eventDishesProvider(widget.eventId));
      ref.invalidate(eventDrinksProvider(widget.eventId));
      ref.invalidate(dishesListProvider);
      ref.invalidate(ingredientsListProvider);
      ref.invalidate(entityCoverPathsProvider(MediaEntityType.dish));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.failed == 0
                ? l10n.menuWizardAddedSnack(result.added)
                : l10n.menuWizardAddedPartialSnack(result.added, result.failed),
          ),
        ),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _accepting = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.menuWizardAcceptError)));
    }
  }

  void _back() => setState(() => _proposal = null);

  void _toggle(int index) {
    setState(() {
      if (!_selected.remove(index)) _selected.add(index);
    });
  }

  void _showLimitReached(int limit) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          l10n.menuWizardLimitReachedTitle,
          style: AppTypography.sectionTitle,
        ),
        content: Text(
          l10n.menuWizardLimitReachedBody(limit),
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              l10n.okAction,
              style: AppTypography.button.copyWith(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Keep the meal-type default in sync once the event resolves.
    ref.watch(eventByIdProvider(widget.eventId));
    _seedMeal();
    final proposal = _proposal;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(l10n.menuWizardTitle, style: AppTypography.sectionTitle),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            proposal == null
                ? _buildQuestions(l10n)
                : _buildReview(l10n, proposal),
            if (_generating || _accepting)
              ColoredBox(
                color: const Color(0x33000000),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.accent),
                      const SizedBox(height: 12),
                      Text(
                        _accepting
                            ? l10n.menuWizardAdding
                            : l10n.menuWizardGenerating,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.surface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestions(AppLocalizations l10n) {
    final quota = ref.watch(menuWizardQuotaProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text(
          quota.when(
            data: (q) => l10n.menuWizardRemainingLabel(q.remaining, q.limit),
            loading: () => '',
            error: (_, _) => '',
          ),
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        _QuestionLabel(l10n.menuWizardMealTypeQuestion),
        SegmentedChoice<_MealType>(
          value: _meal,
          onChanged: (v) => setState(() => _meal = v),
          options: [
            SegmentedChoiceOption(_MealType.aperitif, l10n.menuWizardMealAperitif),
            SegmentedChoiceOption(_MealType.lunch, l10n.menuWizardMealLunch),
            SegmentedChoiceOption(_MealType.dinner, l10n.menuWizardMealDinner),
          ],
        ),
        const SizedBox(height: 20),
        _QuestionLabel(l10n.menuWizardFormalityQuestion),
        SegmentedChoice<_Formality>(
          value: _formality,
          onChanged: (v) => setState(() => _formality = v),
          options: [
            SegmentedChoiceOption(_Formality.informal, l10n.menuWizardFormalityInformal),
            SegmentedChoiceOption(_Formality.festive, l10n.menuWizardFormalityFestive),
            SegmentedChoiceOption(_Formality.formal, l10n.menuWizardFormalityFormal),
          ],
        ),
        const SizedBox(height: 20),
        _QuestionLabel(l10n.menuWizardDietaryQuestion),
        _MultiChips<_Dietary>(
          selected: _dietary,
          onToggle: (v) => setState(() {
            if (!_dietary.remove(v)) _dietary.add(v);
          }),
          options: [
            (_Dietary.vegetarian, l10n.menuWizardDietaryVegetarian),
            (_Dietary.vegan, l10n.menuWizardDietaryVegan),
            (_Dietary.glutenFree, l10n.menuWizardDietaryGlutenFree),
          ],
        ),
        const SizedBox(height: 20),
        _QuestionLabel(l10n.menuWizardFreeTextQuestion),
        TextField(
          controller: _freeText,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(hintText: l10n.menuWizardFreeTextHint),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: l10n.menuWizardGenerateAction,
          icon: Icons.auto_awesome,
          onPressed: _generate,
        ),
      ],
    );
  }

  Widget _buildReview(AppLocalizations l10n, MenuProposal proposal) {
    if (proposal.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.menuWizardEmptyProposal,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              Text(l10n.menuWizardReviewIntro, style: AppTypography.body),
              const SizedBox(height: 12),
              for (var i = 0; i < proposal.items.length; i++)
                _ProposedRow(
                  item: proposal.items[i],
                  selected: _selected.contains(i),
                  onToggle: () => _toggle(i),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: AppColors.bg,
            border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _back,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      l10n.menuWizardBackAction,
                      style: AppTypography.button.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: l10n.menuWizardConfirmAction(_selected.length),
                  onPressed: _confirm,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuestionLabel extends StatelessWidget {
  const _QuestionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: AppTypography.label),
    );
  }
}

/// Minimal multi-select chip row (SegmentedChoice is single-select). Mirrors its
/// selected-state styling so the dietary question reads consistently.
class _MultiChips<T> extends StatelessWidget {
  const _MultiChips({
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final List<(T, String)> options;
  final Set<T> selected;
  final ValueChanged<T> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in options)
          _ToggleChip(
            label: label,
            selected: selected.contains(value),
            onTap: () => onToggle(value),
          ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
          child: Text(
            label,
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

/// One reviewable proposed item with a leading checkbox. Catalog vs new vs drink
/// is marked so the user sees what will be created before confirming (§2).
class _ProposedRow extends StatelessWidget {
  const _ProposedRow({
    required this.item,
    required this.selected,
    required this.onToggle,
  });

  final ProposedItem item;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (subtitle, badgeLabel, badgeColor) = switch (item) {
      NewDishItem(:final card) => (
        dishCategoryLabel(l10n, card.category),
        l10n.menuWizardNewDishMarker,
        AppColors.accentSecondary,
      ),
      CatalogDishItem(:final category) => (
        dishCategoryLabel(l10n, category),
        l10n.menuWizardCatalogMarker,
        AppColors.textTertiary,
      ),
      CatalogDrinkItem() => (
        l10n.menuWizardDrinkLabel,
        l10n.menuWizardCatalogMarker,
        AppColors.textTertiary,
      ),
    };
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: selected,
              onChanged: (_) => onToggle(),
              activeColor: AppColors.accent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(item.title, style: AppTypography.body),
                      ),
                      const SizedBox(width: 8),
                      _Badge(label: badgeLabel, color: badgeColor),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: color),
      ),
    );
  }
}
