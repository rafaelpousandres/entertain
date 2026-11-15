import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/primary_button.dart';
import '../data/ai_consent_prefs.dart';

/// Public privacy policy (GitHub Pages), where the AI provider is disclosed.
const String kPrivacyPolicyUrl =
    'https://rafaelpousandres.github.io/entertain/privacy/';

/// Spec 035 §E — stands in front of the AI screens (dish assistant, menu
/// wizard) until the user has agreed, once, to their request being sent to the
/// third-party AI provider.
///
/// It gates the *screen*, not a button, so every way in is covered — the
/// catalog, the event menu's "create with AI", the menu wizard — including
/// entry points added later. Until the user accepts, [child] is never built,
/// so nothing can be sent. Cancelling leaves the screen.
class AiConsentGate extends StatefulWidget {
  const AiConsentGate({super.key, required this.child});

  final Widget child;

  @override
  State<AiConsentGate> createState() => _AiConsentGateState();
}

class _AiConsentGateState extends State<AiConsentGate> {
  /// null while the stored answer loads.
  bool? _consented;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var value = false;
    try {
      value = await AiConsentPrefs.read();
    } catch (_) {
      // Unreadable storage ⇒ ask (never assume consent).
    }
    if (mounted) setState(() => _consented = value);
  }

  Future<void> _accept() async {
    try {
      await AiConsentPrefs.grant();
    } catch (_) {
      // Not persisted ⇒ the user is simply asked again next time.
    }
    if (mounted) setState(() => _consented = true);
  }

  @override
  Widget build(BuildContext context) {
    final consented = _consented;
    if (consented == true) return widget.child;
    if (consented == null) {
      return const Scaffold(backgroundColor: AppColors.bg);
    }

    final l10n = AppLocalizations.of(context);
    final secondary = AppTypography.body.copyWith(
      color: AppColors.textSecondary,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiConsentTitle, style: AppTypography.display),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  Text(l10n.aiConsentIntro, style: AppTypography.body),
                  const SizedBox(height: 14),
                  Text(l10n.aiConsentSentTitle, style: AppTypography.label),
                  const SizedBox(height: 6),
                  for (final item in [
                    l10n.aiConsentSentRequest,
                    l10n.aiConsentSentEvent,
                    l10n.aiConsentSentCatalog,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $item', style: AppTypography.body),
                    ),
                  const SizedBox(height: 10),
                  Text(l10n.aiConsentNotSent, style: secondary),
                  const SizedBox(height: 10),
                  Text(l10n.aiConsentAdvice, style: secondary),
                  const SizedBox(height: 10),
                  Text(l10n.aiConsentTranslation, style: secondary),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => launchUrl(
                        Uri.parse(kPrivacyPolicyUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(
                        Icons.open_in_new,
                        size: 18,
                        color: AppColors.accentSecondary,
                      ),
                      label: Text(
                        l10n.aiConsentPolicyLink,
                        style: AppTypography.button.copyWith(
                          color: AppColors.accentSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                children: [
                  PrimaryButton(
                    label: l10n.aiConsentAccept,
                    onPressed: _accept,
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(
                      l10n.cancelAction,
                      style: AppTypography.button.copyWith(
                        color: AppColors.textSecondary,
                      ),
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
