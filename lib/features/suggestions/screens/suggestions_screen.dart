import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/primary_button.dart';
import '../../events/data/events_providers.dart' show currentGroupIdProvider;
import '../../shopping/screens/settings_screen.dart' show appVersionProvider;
import '../data/suggestions_providers.dart';

/// Suggestions box (Specification 021 Part A).
///
/// A lightweight, AI-free feedback channel reached from Settings. The user
/// types a free-text suggestion (the system keyboard's voice dictation works
/// here — a plain multi-line field, nothing blocks it) and sends it; the row
/// is stored for a later manual dump. An indicator shows how many suggestions
/// the group has sent so far.
class SuggestionsScreen extends ConsumerStatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  ConsumerState<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends ConsumerState<SuggestionsScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Enable/disable the send button as the field fills/empties.
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final groupId = await ref.read(currentGroupIdProvider.future);
      final userId = ref.read(currentUserIdProvider);
      final appVersion = await ref.read(appVersionProvider.future);
      await ref.read(suggestionsRepositoryProvider).create(
            groupId: groupId,
            userId: userId,
            appVersion: appVersion,
            text: text,
          );
      // Refresh the counter so it reflects the row we just inserted.
      ref.invalidate(suggestionsCountProvider);
      if (!mounted) return;
      _controller.clear();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.suggestionsSentConfirm)),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.suggestionsSendError)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final countAsync = ref.watch(suggestionsCountProvider);
    final canSend = !_sending && _controller.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(l10n.suggestionsTitle, style: AppTypography.display),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              l10n.suggestionsIntro,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: l10n.suggestionsFieldLabel,
              // Spec 021 §B-fix 2: hint the app's locale to the field so some
              // keyboards start in the right language. Best-effort only — the
              // OS owns the keyboard and may still open in the system language;
              // we suggest, we don't force.
              child: Localizations.override(
                context: context,
                locale: Localizations.localeOf(context),
                child: AppTextField(
                  controller: _controller,
                  hintText: l10n.suggestionsFieldHint,
                  maxLines: 6,
                ),
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: l10n.suggestionsSendAction,
              icon: Icons.send,
              onPressed: canSend ? _send : null,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                countAsync.maybeWhen(
                  data: (n) => l10n.suggestionsSentCount(n),
                  orElse: () => '',
                ),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
