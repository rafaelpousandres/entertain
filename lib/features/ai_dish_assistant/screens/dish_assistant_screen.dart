import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/primary_button.dart';
import '../../catalog/data/catalog_providers.dart';
import '../data/dish_assistant_providers.dart';
import '../data/dish_assistant_repository.dart';
import '../data/dish_suggestion.dart';

/// Spec 020 §7 (v3) — "Crea un plat amb IA". One screen, two input paths:
///   • by name (top): "Cerca" → `suggest` → up to 3 title+URL suggestions, each
///     with a clickable URL (external browser) and a "Crea aquest plat" action.
///   • by URL (below): paste a recipe URL → "Crea des d'aquesta URL".
/// Both converge on `process` (the costly, quota-charging phase); a header shows
/// the remaining quota (informational — only `process` consumes it).
class DishAssistantScreen extends ConsumerStatefulWidget {
  const DishAssistantScreen({super.key});

  @override
  ConsumerState<DishAssistantScreen> createState() =>
      _DishAssistantScreenState();
}

class _DishAssistantScreenState extends ConsumerState<DishAssistantScreen> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  AsyncValue<List<DishSuggestion>>? _suggestions;
  bool _processing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  String get _locale => Localizations.localeOf(context).languageCode;

  bool _looksLikeUrl(String value) {
    final v = value.trim();
    return (v.startsWith('http://') || v.startsWith('https://')) &&
        v.contains('.');
  }

  Future<void> _suggest() async {
    final query = _nameController.text.trim();
    if (query.isEmpty || _processing) return;
    FocusScope.of(context).unfocus();
    setState(() => _suggestions = const AsyncValue.loading());
    try {
      final list = await ref
          .read(dishAssistantRepositoryProvider)
          .suggest(name: query, locale: _locale);
      if (mounted) setState(() => _suggestions = AsyncValue.data(list));
    } catch (e, st) {
      if (mounted) setState(() => _suggestions = AsyncValue.error(e, st));
    }
  }

  Future<void> _openUrl(String url) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.dishAssistantOpenError)));
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.dishAssistantOpenError)));
      }
    }
  }

  /// Both paths land here: Path A passes the picked suggestion (url + its name),
  /// Path B passes the pasted url. Charges quota; on success opens the new dish.
  Future<void> _process({required String url, String? name}) async {
    if (_processing) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();
    setState(() => _processing = true);
    try {
      final result = await ref
          .read(dishAssistantRepositoryProvider)
          .process(url: url, name: name, locale: _locale);
      if (!mounted) return;
      // New dish + (possibly) new ingredients; refresh the catalogs and quota.
      ref.invalidate(dishesListProvider);
      ref.invalidate(ingredientsListProvider);
      ref.invalidate(dishAssistantQuotaProvider);
      // Open the freshly created dish; back returns to the catalog.
      context.pushReplacement('/dishes/${result.dishId}');
    } on QuotaExceededException catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      _showLimitReached(e.limit);
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.dishAssistantSaveError)),
      );
    }
  }

  void _processFromUrl() {
    final url = _urlController.text.trim();
    if (!_looksLikeUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).dishAssistantInvalidUrl)),
      );
      return;
    }
    _process(url: url);
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
        title: Text(l10n.dishAssistantTitle, style: AppTypography.sectionTitle),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                // Path A — by name.
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _suggest(),
                  decoration: InputDecoration(
                    hintText: l10n.dishAssistantHint,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.auto_awesome_outlined),
                      color: AppColors.accentSecondary,
                      tooltip: l10n.dishAssistantSearchAction,
                      onPressed: _suggest,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
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
                const SizedBox(height: 8),
                _buildSuggestions(l10n),
                const SizedBox(height: 20),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 20),
                // Path B — by URL.
                Text(
                  l10n.dishAssistantUrlHint,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _processFromUrl(),
                  decoration: const InputDecoration(
                    hintText: 'https://…',
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: l10n.dishAssistantCreateFromUrlAction,
                  icon: Icons.link,
                  onPressed: _processFromUrl,
                ),
              ],
            ),
            if (_processing)
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

  Widget _buildSuggestions(AppLocalizations l10n) {
    final results = _suggestions;
    if (results == null) {
      return _Hint(text: l10n.dishAssistantEmptyPrompt);
    }
    return results.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
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
      error: (_, _) => _Hint(text: l10n.dishAssistantError),
      data: (list) {
        if (list.isEmpty) return _Hint(text: l10n.dishAssistantNoResults);
        return Column(
          children: [
            for (final s in list) ...[
              _SuggestionCard(
                suggestion: s,
                onOpen: () => _openUrl(s.url),
                onCreate: () => _process(url: s.url, name: s.title),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.onOpen,
    required this.onCreate,
  });

  final DishSuggestion suggestion;
  final VoidCallback onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            suggestion.title,
            style: AppTypography.sectionTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: onOpen,
            child: Row(
              children: [
                const Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: AppColors.accentSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    suggestion.url,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.accentSecondary,
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 18, color: AppColors.accent),
              label: Text(
                l10n.dishAssistantCreateThisAction,
                style: AppTypography.button.copyWith(color: AppColors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
