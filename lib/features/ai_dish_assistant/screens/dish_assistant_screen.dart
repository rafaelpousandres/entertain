import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/primary_button.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/data/dish_category.dart';
import '../../photos/data/media.dart';
import '../../photos/data/media_providers.dart';
import '../data/dish_assistant_providers.dart';
import '../data/dish_assistant_repository.dart';
import '../data/dish_card.dart';

/// Spec 020 §6 (v4) — "Crea un plat amb IA". One free-text field → Claude
/// generates a dish card from its own knowledge → the user reviews it (new
/// ingredients visibly marked) → Desa (save + open) or Descarta. Quota is
/// charged at generate; a header shows the remaining quota.
class DishAssistantScreen extends ConsumerStatefulWidget {
  const DishAssistantScreen({super.key});

  @override
  ConsumerState<DishAssistantScreen> createState() =>
      _DishAssistantScreenState();
}

class _DishAssistantScreenState extends ConsumerState<DishAssistantScreen> {
  final _controller = TextEditingController();
  bool _generating = false;
  bool _saving = false;
  DishCard? _card;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _locale => Localizations.localeOf(context).languageCode;

  Future<void> _generate() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _generating) return;
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _generating = true);
    try {
      final result = await ref
          .read(dishAssistantRepositoryProvider)
          .generate(text: text, locale: _locale);
      if (!mounted) return;
      // Quota was charged at generate — refresh the header.
      ref.invalidate(dishAssistantQuotaProvider);
      setState(() {
        _generating = false;
        _card = result.card;
      });
    } on QuotaExceededException catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      _showLimitReached(e.limit);
    } catch (_) {
      if (!mounted) return;
      setState(() => _generating = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.dishAssistantError)));
    }
  }

  Future<void> _save() async {
    final card = _card;
    if (card == null || _saving) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final dishId = await ref
          .read(dishAssistantRepositoryProvider)
          .save(card: card);
      if (!mounted) return;
      ref.invalidate(dishesListProvider);
      ref.invalidate(ingredientsListProvider);
      // Spec 021 §B1: parity with the manual stock-photo save — refresh the
      // cover caches so the auto photo shows without leaving and re-entering.
      ref.invalidate(entityCoverPathsProvider(MediaEntityType.dish));
      ref.invalidate(
        entityMediaProvider((type: MediaEntityType.dish, entityId: dishId)),
      );
      context.pushReplacement('/dishes/$dishId');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.dishAssistantSaveError)),
      );
    }
  }

  void _discard() => setState(() => _card = null);

  void _showLimitReached(int limit) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          l10n.dishAssistantLimitReachedTitle,
          style: AppTypography.sectionTitle,
        ),
        content: Text(
          l10n.dishAssistantLimitReachedBody(limit),
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
    final card = _card;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(l10n.dishAssistantTitle, style: AppTypography.sectionTitle),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            card == null ? _buildInput(l10n) : _buildReview(l10n, card),
            if (_generating || _saving)
              ColoredBox(
                color: const Color(0x33000000),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.accent),
                      const SizedBox(height: 12),
                      Text(
                        _saving
                            ? l10n.dishAssistantSaving
                            : l10n.dishAssistantGenerating,
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

  Widget _buildInput(AppLocalizations l10n) {
    final quota = ref.watch(dishAssistantQuotaProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        TextField(
          controller: _controller,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _generate(),
          decoration: InputDecoration(hintText: l10n.dishAssistantHint),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            quota.when(
              data: (q) =>
                  l10n.dishAssistantRemainingLabel(q.remaining, q.limit),
              loading: () => '',
              error: (_, _) => '',
            ),
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: l10n.dishAssistantGenerateAction,
          icon: Icons.auto_awesome,
          onPressed: _generate,
        ),
        const SizedBox(height: 24),
        Text(
          l10n.dishAssistantEmptyPrompt,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        // Spec 021 §B4: reassure the user that generation isn't final — the
        // dish can be edited right after creating it. Lowers pressure on the
        // prompt and clarifies they keep final control.
        const SizedBox(height: 12),
        Text(
          l10n.dishAssistantEditableNote,
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }

  Widget _buildReview(AppLocalizations l10n, DishCard card) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              if (card.photoPreviewUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      card.photoPreviewUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const ColoredBox(color: AppColors.surface),
                      errorBuilder: (context, _, _) =>
                          const ColoredBox(color: AppColors.surface),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Text(card.displayName, style: AppTypography.sectionTitle),
              const SizedBox(height: 4),
              Text(
                '${dishCategoryLabel(l10n, card.category)} · '
                '${l10n.dishAssistantServingsLabel(card.baseServings)}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.accentSecondary,
                ),
              ),
              if (card.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  card.description,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(l10n.dishAssistantIngredientsTitle, style: AppTypography.sectionTitle),
              const SizedBox(height: 8),
              for (final ing in card.ingredients) _IngredientRow(ingredient: ing),
              const SizedBox(height: 20),
              Text(l10n.dishAssistantPreparationTitle, style: AppTypography.sectionTitle),
              const SizedBox(height: 8),
              Text(
                card.preparation,
                style: AppTypography.body.copyWith(height: 1.5),
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
                    onPressed: _discard,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      l10n.dishAssistantDiscardAction,
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
                  label: l10n.dishAssistantSaveAction,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.ingredient});

  final DishCardIngredient ingredient;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final amount = '${_fmt(ingredient.quantity)} ${ingredient.unitLabel}'.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ingredient.displayName,
                        style: AppTypography.body,
                      ),
                    ),
                    if (ingredient.isNew) ...[
                      const SizedBox(width: 8),
                      _NewBadge(label: l10n.dishAssistantNewIngredientMarker),
                    ],
                  ],
                ),
                if (ingredient.prepNote != null)
                  Text(
                    ingredient.prepNote!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  static String _fmt(num q) {
    if (q == q.roundToDouble()) return q.toInt().toString();
    return q.toString();
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentSecondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.accentSecondary,
        ),
      ),
    );
  }
}
