import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/primary_button.dart';
import '../../../ui/secondary_button.dart';
import '../../../ui/segmented_choice.dart';
import '../../../ui/stepper_field.dart';
import '../../events/data/events_providers.dart' show currentGroupIdProvider;
import '../data/catalog_providers.dart';
import '../data/dish.dart';
import '../data/dish_category.dart';
import '../data/reference_data.dart';
import 'ingredient_line_editor_screen.dart';

/// Create / edit a catalog dish and its recipe lines (Specification 004
/// screen 2). Works on an in-memory [DishDraft]; the line editor returns
/// line drafts that are kept in memory until the whole dish is saved.
class DishEditorScreen extends ConsumerWidget {
  const DishEditorScreen({super.key, this.dishId});

  final String? dishId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (dishId == null) {
      return _DishForm(initial: DishDraft.empty());
    }

    final l10n = AppLocalizations.of(context);
    final dishAsync = ref.watch(dishByIdProvider(dishId!));
    final linesAsync = ref.watch(dishLinesProvider(dishId!));

    if (dishAsync.isLoading || linesAsync.isLoading) {
      return const _Scaffold(child: _Loading());
    }
    if (dishAsync.hasError || linesAsync.hasError) {
      return _Scaffold(
        child: _Error(
          message: l10n.dishesLoadError,
          onRetry: () {
            ref.invalidate(dishByIdProvider(dishId!));
            ref.invalidate(dishLinesProvider(dishId!));
          },
        ),
      );
    }

    // Seed the editor with fresh copies so editing never mutates the cached
    // provider state until the user saves.
    final lines = [for (final l in linesAsync.value!) l.copy()];
    return _DishForm(
      dishId: dishId,
      initial: DishDraft.fromDish(dishAsync.value!, lines),
    );
  }
}

class _DishForm extends ConsumerStatefulWidget {
  const _DishForm({this.dishId, required this.initial});

  final String? dishId;
  final DishDraft initial;

  bool get isEditing => dishId != null;

  @override
  ConsumerState<_DishForm> createState() => _DishFormState();
}

class _DishFormState extends ConsumerState<_DishForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _preparationController;
  late final DishDraft _draft;

  bool _saving = false;
  bool _deleting = false;
  bool _submitted = false;
  String? _nameError;

  bool get _busy => _saving || _deleting;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _nameController = TextEditingController(text: _draft.name);
    _descriptionController = TextEditingController(
      text: _draft.description ?? '',
    );
    _preparationController = TextEditingController(
      text: _draft.preparation ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _preparationController.dispose();
    super.dispose();
  }

  Future<void> _addLine() async {
    final result = await context.push<LineEditorResult>('/dish-line-editor');
    if (result?.line != null) {
      setState(() => _draft.lines.add(result!.line!));
    }
  }

  Future<void> _editLine(int index) async {
    final result = await context.push<LineEditorResult>(
      '/dish-line-editor',
      extra: _draft.lines[index].copy(),
    );
    if (result == null) return;
    setState(() {
      if (result.removed) {
        _draft.lines.removeAt(index);
      } else if (result.line != null) {
        _draft.lines[index] = result.line!;
      }
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _submitted = true);
    _draft.name = _nameController.text;
    _draft.description = _descriptionController.text;
    _draft.preparation = _preparationController.text;

    if (_draft.name.trim().isEmpty) {
      setState(() => _nameError = l10n.dishNameRequired);
      return;
    }
    setState(() {
      _nameError = null;
      _saving = true;
    });

    final repo = ref.read(catalogRepositoryProvider);
    try {
      if (widget.isEditing) {
        await repo.updateDish(widget.dishId!, _draft);
        ref.invalidate(dishByIdProvider(widget.dishId!));
        ref.invalidate(dishLinesProvider(widget.dishId!));
      } else {
        final groupId = await ref.read(currentGroupIdProvider.future);
        await repo.createDish(_draft, groupId: groupId);
      }
      ref.invalidate(dishesListProvider);
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.dishSaveError)));
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          l10n.deleteDishConfirmTitle,
          style: AppTypography.sectionTitle,
        ),
        content: Text(
          l10n.deleteDishConfirmBody,
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
              l10n.deleteDishConfirmButton,
              style: AppTypography.button.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _delete();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _deleting = true);
    try {
      await ref.read(catalogRepositoryProvider).deleteDish(widget.dishId!);
      ref.invalidate(dishesListProvider);
      ref.invalidate(dishByIdProvider(widget.dishId!));
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.dishSaveError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final units = ref.watch(unitsProvider(localeCode)).value;
    final unitsById = {for (final u in units ?? const <Unit>[]) u.id: u};

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          widget.isEditing ? l10n.dishEditScreenTitle : l10n.dishNewScreenTitle,
          style: AppTypography.sectionTitle,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.backAction,
          onPressed: _busy ? null : () => context.pop(),
        ),
        actions: [
          if (widget.isEditing)
            PopupMenuButton<_OverflowAction>(
              icon: const Icon(Icons.more_vert),
              tooltip: l10n.moreActionsLabel,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (action) {
                switch (action) {
                  case _OverflowAction.delete:
                    _confirmDelete();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _OverflowAction.delete,
                  child: Text(
                    l10n.deleteAction,
                    style: AppTypography.body.copyWith(color: AppColors.danger),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            FieldLabel(
              label: l10n.dishNameLabel,
              child: AppTextField(
                controller: _nameController,
                hintText: l10n.dishNameHint,
                onChanged: (value) {
                  if (!_submitted) return;
                  setState(() {
                    _nameError =
                        value.trim().isEmpty ? l10n.dishNameRequired : null;
                  });
                },
              ),
            ),
            if (_nameError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _nameError!,
                  style: AppTypography.caption.copyWith(color: AppColors.danger),
                ),
              ),
            // Fixes round 2 §2.1: the description is a one-line subtitle of the
            // dish, so it sits immediately after the title, ahead of the
            // metadata fields (Nom → Descripció → Categoria → Racions base).
            const SizedBox(height: 16),
            FieldLabel(
              label: l10n.dishDescriptionLabel,
              child: AppTextField(
                controller: _descriptionController,
                hintText: l10n.dishDescriptionHint,
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: l10n.dishCategoryLabel,
              child: SegmentedChoice<DishCategory>(
                value: _draft.category,
                onChanged: (v) => setState(() => _draft.category = v),
                options: [
                  for (final c in dishCategoryOrder)
                    SegmentedChoiceOption(c, dishCategoryLabel(l10n, c)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: l10n.dishBaseServingsLabel,
              child: StepperField(
                value: _draft.baseServings,
                onChanged: (v) => setState(() => _draft.baseServings = v),
              ),
            ),
            const SizedBox(height: 24),
            Text(l10n.dishIngredientsSectionTitle, style: AppTypography.sectionTitle),
            const SizedBox(height: 8),
            if (_draft.lines.isEmpty)
              _LinesEmpty()
            else
              for (var i = 0; i < _draft.lines.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LineRow(
                    line: _draft.lines[i],
                    unit: unitsById[_draft.lines[i].unitId],
                    onTap: () => _editLine(i),
                  ),
                ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: l10n.addIngredientLineAction,
              icon: Icons.add,
              onPressed: _busy ? null : _addLine,
            ),
            // Fixes §2.2: the preparation goes below the ingredient lines so the
            // editor follows a recipe's natural reading order (title →
            // description → metadata → ingredients → preparation).
            const SizedBox(height: 24),
            FieldLabel(
              label: l10n.dishPreparationLabel,
              child: AppTextField(
                controller: _preparationController,
                hintText: l10n.dishPreparationHint,
                maxLines: 8,
                textInputAction: TextInputAction.newline,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: AppColors.bg,
            border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: PrimaryButton(
            label: l10n.saveAction,
            icon: Icons.check,
            onPressed: _busy ? null : _save,
          ),
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.unit, required this.onTap});

  final DishLineDraft line;
  final Unit? unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final qty = formatQuantity(
      line.quantity,
      decimalSeparator: quantityDecimalSeparator(
        Localizations.localeOf(context).languageCode,
      ),
    );
    final measure = unit == null ? qty : '$qty ${unit!.name}';
    final hasNote = line.prepNote != null && line.prepNote!.trim().isNotEmpty;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      line.ingredientName,
                      style: AppTypography.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasNote
                          ? '$measure${l10n.metadataSeparator}${line.prepNote!.trim()}'
                          : measure,
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: AppColors.disabled,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinesEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        l10n.dishLinesEmptyBody,
        textAlign: TextAlign.center,
        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(),
      body: SafeArea(top: false, child: child),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.accent),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: Text(
                l10n.retryAction,
                style: AppTypography.button.copyWith(color: AppColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _OverflowAction { delete }
