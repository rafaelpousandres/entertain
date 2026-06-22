import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../catalog/data/catalog_providers.dart';
import '../data/dish_assistant_providers.dart';
import '../data/dish_assistant_repository.dart';
import '../data/dish_option.dart';

/// Spec 020 §7 — "Crea un plat amb IA". A name field, up to 3 option cards
/// (name, key ingredients, servings, photo, summary), and a remaining-quota
/// header. Tapping an option saves it via the Edge Function and opens the new
/// dish; a reached limit shows the paywall-seam message.
class DishAssistantScreen extends ConsumerStatefulWidget {
  const DishAssistantScreen({super.key});

  @override
  ConsumerState<DishAssistantScreen> createState() =>
      _DishAssistantScreenState();
}

class _DishAssistantScreenState extends ConsumerState<DishAssistantScreen> {
  final _controller = TextEditingController();
  AsyncValue<List<DishOption>>? _results;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _locale => Localizations.localeOf(context).languageCode;

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _results = const AsyncValue.loading());
    try {
      final options = await ref
          .read(dishAssistantRepositoryProvider)
          .search(name: query, locale: _locale);
      if (mounted) setState(() => _results = AsyncValue.data(options));
    } catch (e, st) {
      if (mounted) setState(() => _results = AsyncValue.error(e, st));
    }
  }

  Future<void> _pick(DishOption option) async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(dishAssistantRepositoryProvider)
          .save(option: option);
      if (!mounted) return;
      // New dish + (possibly) new ingredients; refresh the catalogs and quota.
      ref.invalidate(dishesListProvider);
      ref.invalidate(ingredientsListProvider);
      ref.invalidate(dishAssistantQuotaProvider);
      // Open the freshly created dish; back returns to the catalog.
      context.pushReplacement('/dishes/${result.dishId}');
    } on QuotaExceededException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showLimitReached(e.limit);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.dishAssistantSaveError)),
      );
    }
  }

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
    final quota = ref.watch(dishAssistantQuotaProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          l10n.dishAssistantTitle,
          style: AppTypography.sectionTitle,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: l10n.dishAssistantHint,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.auto_awesome_outlined),
                        color: AppColors.accentSecondary,
                        tooltip: l10n.dishAssistantSearchAction,
                        onPressed: _search,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      quota.when(
                        data: (q) =>
                            l10n.dishAssistantRemainingLabel(q.remaining, q.limit),
                        loading: () => '',
                        error: (_, _) => '',
                      ),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                Expanded(child: _buildResults(l10n)),
              ],
            ),
            if (_saving)
              ColoredBox(
                color: const Color(0x33000000),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.accent),
                      const SizedBox(height: 12),
                      Text(
                        l10n.dishAssistantSaving,
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

  Widget _buildResults(AppLocalizations l10n) {
    final results = _results;
    if (results == null) {
      return _CenteredHint(text: l10n.dishAssistantEmptyPrompt);
    }
    return results.when(
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: 12),
            Text(
              l10n.dishAssistantSearching,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      error: (_, _) => _CenteredHint(text: l10n.dishAssistantError),
      data: (options) {
        if (options.isEmpty) {
          return _CenteredHint(text: l10n.dishAssistantNoResults);
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: options.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _OptionCard(
            option: options[i],
            onTap: () => _pick(options[i]),
          ),
        );
      },
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.option, required this.onTap});

  final DishOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ingredients = option.ingredientNames.take(4).join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (option.photoUrl != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  option.photoUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const ColoredBox(color: AppColors.bg),
                  errorBuilder: (context, _, _) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.displayName,
                    style: AppTypography.sectionTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.dishAssistantServingsLabel(option.baseServings),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.accentSecondary,
                    ),
                  ),
                  if (option.summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      option.summary,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (ingredients.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      ingredients,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
