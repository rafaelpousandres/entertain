import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/app_logo.dart';
import '../../../ui/dirty_tabs_guard.dart';
import '../../../ui/primary_button.dart';
import '../../../ui/segmented_choice.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/data/reference_data.dart';
import '../../events/data/events_providers.dart' show currentGroupIdProvider;
import '../data/group_supplier_setting.dart';
import '../data/message_channel.dart';
import '../data/shopping_providers.dart';
import '../supplier_category_format.dart';

/// App version shown in the General tab (Spec 012 §2.1). Read at runtime from
/// the platform package metadata so the card always reflects the real
/// `pubspec.yaml` version (`version+build`) instead of a hand-maintained literal
/// that can drift away from what testers actually have installed.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

/// Settings screen, reorganised into three tabs (Spec 007 §2.2):
///
///   * **General** — about the app (name, version). Locale is auto-detected;
///     the language selector is out of scope for the MVP.
///   * **Proveïdors** — supplier category admin (list, add, and per-category
///     detail with channel/address; see [SupplierCategoryDetailScreen]).
///   * **Missatges** — the outgoing-message greeting and signature.
///
/// Default tab is General. The bottom action bar is per-tab: Save on
/// Missatges, "Afegeix categoria" on Proveïdors, nothing on General.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _greetingController = TextEditingController();
  final _signatureController = TextEditingController();
  // Spec 008 §2.9: the group's text-message channel, edited alongside the
  // greeting and signature on the Missatges tab.
  TextMessageChannel _textChannel = TextMessageChannel.whatsapp;
  bool _seeded = false;
  bool _saving = false;

  // Spec 011 §2.5: the last saved/seeded values, so the tab-switch guard can
  // tell whether the Missatges tab is dirty and restore them on Discard.
  String _seededGreeting = '';
  String _seededSignature = '';
  late TextMessageChannel _seededChannel;

  /// Whether the Missatges tab has unsaved edits (the only editable Settings
  /// tab; General and Proveïdors are read-only here).
  bool get _messagesDirty =>
      _seeded &&
      (_greetingController.text != _seededGreeting ||
          _signatureController.text != _seededSignature ||
          _textChannel != _seededChannel);

  /// §2.5: restore the Missatges fields to their last saved values, called when
  /// the user confirms Discard on a tab switch.
  void _discardMessages() {
    _greetingController.text = _seededGreeting;
    _signatureController.text = _seededSignature;
    setState(() => _textChannel = _seededChannel);
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    _greetingController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  void _seedMessages(
    String greeting,
    String signature,
    TextMessageChannel textChannel,
  ) {
    if (_seeded) return;
    _greetingController.text = greeting;
    _signatureController.text = signature;
    _textChannel = textChannel;
    _seededGreeting = greeting;
    _seededSignature = signature;
    _seededChannel = textChannel;
    _seeded = true;
  }

  Future<void> _saveMessages() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final groupId = await ref.read(currentGroupIdProvider.future);
      final repo = ref.read(settingsRepositoryProvider);

      // The greeting is stored verbatim, empty included (Fixes round 2 §2.1):
      // an explicitly cleared greeting must stay cleared, not revert to the
      // default. The signature, by contrast, nulls out to fall back to the
      // display name.
      await repo.updateGreeting(groupId, _greetingController.text.trim());
      final signature = _signatureController.text.trim();
      await repo.updateSignature(groupId, signature.isEmpty ? null : signature);
      // Spec 008 §2.9: persist the text-message channel together with the rest.
      await repo.updateTextMessageChannel(groupId, _textChannel);

      ref.invalidate(groupGreetingProvider);
      ref.invalidate(groupSignatureProvider);
      ref.invalidate(groupTextMessageChannelProvider);
      // §2.5: the saved values are now the clean baseline, so the tab-switch
      // guard no longer treats the Missatges tab as dirty.
      _seededGreeting = _greetingController.text;
      _seededSignature = _signatureController.text;
      _seededChannel = _textChannel;
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveAction)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsSaveError)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addCategory() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => const _AddCategorySheet(),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      final groupId = await ref.read(currentGroupIdProvider.future);
      await ref
          .read(catalogRepositoryProvider)
          .createUserSupplierCategory(groupId: groupId, name: name.trim());
      ref.invalidate(supplierCategoriesProvider);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsSaveError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final greetingAsync = ref.watch(groupGreetingProvider);
    final signatureAsync = ref.watch(groupSignatureProvider);
    final textChannelAsync = ref.watch(groupTextMessageChannelProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        // Spec 012 §2.1: a small brand logo in the header, beside the title.
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 28, borderRadius: 7),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                l10n.settingsScreenTitle,
                style: AppTypography.display,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // §2.3: the Missatges tab saves from an AppBar check (always visible
          // above the keyboard) instead of a bottom button.
          if (_tab.index == 2)
            IconButton(
              icon: const Icon(Icons.check),
              color: AppColors.accentSecondary,
              tooltip: l10n.saveAction,
              onPressed: _saving ? null : _saveMessages,
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.accentSecondary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.accentSecondary,
          labelStyle: AppTypography.label,
          unselectedLabelStyle: AppTypography.label,
          tabs: [
            Tab(text: l10n.settingsTabGeneral),
            Tab(text: l10n.settingsTabSuppliers),
            Tab(text: l10n.settingsTabMessages),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        // §2.5: guard tab switches away from the Missatges tab when it has
        // unsaved edits (the General and Proveïdors tabs are read-only here).
        child: DirtyTabsGuard(
          controller: _tab,
          isTabDirty: (index) => index == 2 && _messagesDirty,
          onConfirmDiscard: (_) => _discardMessages(),
          child: TabBarView(
            controller: _tab,
            children: [
              const _GeneralTab(),
              _SuppliersTab(localeCode: localeCode),
              _MessagesTab(
                greetingAsync: greetingAsync,
                signatureAsync: signatureAsync,
                textChannelAsync: textChannelAsync,
                greetingController: _greetingController,
                signatureController: _signatureController,
                textChannel: _textChannel,
                onChannelChanged: (c) => setState(() => _textChannel = c),
                onSeed: _seedMessages,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(l10n),
    );
  }

  Widget? _buildBottomBar(AppLocalizations l10n) {
    // §2.3: Missatges saves from the AppBar check now; only Proveïdors keeps a
    // bottom action ("Afegeix categoria"). General has none.
    if (_tab.index != 1) return null;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: PrimaryButton(
          label: l10n.supplierCategoryAddAction,
          icon: Icons.add,
          onPressed: _addCategory,
        ),
      ),
    );
  }
}

class _GeneralTab extends ConsumerWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // §2.1: version resolved at runtime; show a neutral ellipsis until it loads
    // (a fraction of a second) rather than flashing a wrong number.
    final version = ref.watch(appVersionProvider).value ?? '…';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          // Spec 012 §2.1: the brand logo sits beside the app name/version.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppLogo(size: 52, borderRadius: 12),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.appTitle, style: AppTypography.sectionTitle),
                    const SizedBox(height: 6),
                    Text(
                      l10n.settingsAboutVersion(version),
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.settingsAboutDescription,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Spec 012 §2.3: telegraphic onboarding card.
        const SizedBox(height: 16),
        const _GettingStartedCard(),
        // Spec 010 §2.5: the user's Supabase Auth id, near the bottom of the
        // General tab, so a data-deletion request by email can identify the
        // account. The id is exposed only here.
        const SizedBox(height: 16),
        const _PrivacyDataCard(),
      ],
    );
  }
}

/// Spec 012 §2.3 — a brief, scannable "Getting started" card on the General
/// tab. The fuller walk-through lives in the GitHub Pages tester manual (§2.5).
class _GettingStartedCard extends StatelessWidget {
  const _GettingStartedCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = [
      l10n.gettingStartedStep1,
      l10n.gettingStartedStep2,
      l10n.gettingStartedStep3,
      l10n.gettingStartedStep4,
      l10n.gettingStartedStep5,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.gettingStartedTitle, style: AppTypography.sectionTitle),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}.',
                    style: AppTypography.body.copyWith(
                      color: AppColors.accentSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Spec 010 §2.5 — "Privacy & data": shows the authenticated `user_id` (the
/// Supabase Auth UUID) with a copy-to-clipboard button so the user can quote it
/// in a deletion request. Reads the id directly from the auth session; falls
/// back to a neutral "Not available" line if there is somehow no session.
class _PrivacyDataCard extends StatelessWidget {
  const _PrivacyDataCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final userId = Supabase.instance.client.auth.currentUser?.id;

    Future<void> copy() async {
      if (userId == null) return;
      await Clipboard.setData(ClipboardData(text: userId));
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsAccountIdCopied)),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settingsPrivacyTitle, style: AppTypography.sectionTitle),
          const SizedBox(height: 12),
          Text(
            l10n.settingsAccountIdLabel,
            style: AppTypography.label.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SelectableText(
                  userId ?? l10n.settingsAccountIdUnavailable,
                  style: AppTypography.body.copyWith(
                    color: userId == null
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (userId != null)
                TextButton.icon(
                  onPressed: copy,
                  icon: const Icon(
                    Icons.copy_outlined,
                    size: 18,
                    color: AppColors.accentSecondary,
                  ),
                  label: Text(
                    l10n.settingsCopyAction,
                    style: AppTypography.button.copyWith(
                      color: AppColors.accentSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.settingsAccountIdHelp,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          // Spec 011 §2.1: link to the public deletion page the stores require,
          // in addition to the email instructions above.
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => launchUrl(
                Uri.parse(_deleteDataUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(
                Icons.open_in_new,
                size: 18,
                color: AppColors.accentSecondary,
              ),
              label: Text(
                l10n.settingsDeleteDataLink,
                style: AppTypography.button.copyWith(
                  color: AppColors.accentSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Public deletion page (Spec 011 §2.1), hosted on GitHub Pages alongside the
/// privacy policy. The stores may require this dedicated page for production.
const String _deleteDataUrl =
    'https://rafaelpousandres.github.io/entertain/delete-data/';

class _SuppliersTab extends ConsumerWidget {
  const _SuppliersTab({required this.localeCode});

  final String localeCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final categoriesAsync = ref.watch(supplierCategoriesProvider(localeCode));
    final settingsAsync = ref.watch(groupSupplierSettingsProvider);

    if (categoriesAsync.hasError || settingsAsync.hasError) {
      return _Message(text: l10n.settingsLoadError);
    }
    if (categoriesAsync.isLoading || settingsAsync.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    final settingsMap = settingsAsync.value!;
    // Spec 008 §2.7: dispatch-capable categories first, sorted alphabetically by
    // their localised label, then the consultive Rebost (pantry) at the bottom —
    // mirroring the shopping panel's order. Rebost is a pantry section, not a
    // supplier relationship, so it belongs visually after the real suppliers.
    final categories = [...categoriesAsync.value!]
      ..sort((a, b) {
        final aPantry = isPantryCategory(a.code);
        final bPantry = isPantryCategory(b.code);
        if (aPantry != bPantry) return aPantry ? 1 : -1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        for (final category in categories) ...[
          _CategoryRow(
            category: category,
            setting: settingsMap[category.id],
            onTap: () => context.push('/settings/category', extra: category),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.setting,
    required this.onTap,
  });

  final SupplierCategory category;
  final GroupSupplierSetting? setting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subtitle = _channelSubtitle(l10n);
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
              Icon(
                supplierCategoryIcon(category.code),
                size: 20,
                color: AppColors.accentSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.name,
                      style: AppTypography.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

  String? _channelSubtitle(AppLocalizations l10n) {
    final channel = setting?.channel;
    if (channel == null) return null;
    // Fixes §2.1: the indicator shows the default channel and its matching
    // address (phone for WhatsApp, email for Email). Compartir (round 2 §2.3)
    // has no address — just the channel label.
    final label = switch (channel) {
      MessageChannel.whatsapp => l10n.channelWhatsApp,
      MessageChannel.email => l10n.channelEmail,
      MessageChannel.share => l10n.channelShare,
    };
    if (channel == MessageChannel.share) return label;
    final address = setting?.defaultAddress?.trim() ?? '';
    return address.isEmpty ? label : '$label${l10n.metadataSeparator}$address';
  }
}

class _MessagesTab extends StatelessWidget {
  const _MessagesTab({
    required this.greetingAsync,
    required this.signatureAsync,
    required this.textChannelAsync,
    required this.greetingController,
    required this.signatureController,
    required this.textChannel,
    required this.onChannelChanged,
    required this.onSeed,
  });

  final AsyncValue<String?> greetingAsync;
  final AsyncValue<String> signatureAsync;
  final AsyncValue<TextMessageChannel> textChannelAsync;
  final TextEditingController greetingController;
  final TextEditingController signatureController;
  final TextMessageChannel textChannel;
  final ValueChanged<TextMessageChannel> onChannelChanged;
  final void Function(
    String greeting,
    String signature,
    TextMessageChannel textChannel,
  )
  onSeed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (greetingAsync.hasError ||
        signatureAsync.hasError ||
        textChannelAsync.hasError) {
      return _Message(text: l10n.settingsLoadError);
    }
    if (greetingAsync.isLoading ||
        signatureAsync.isLoading ||
        textChannelAsync.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    // Null greeting means "never set" — seed the localised default ("Hola,").
    // An empty string means the user cleared it; keep it empty.
    final greeting = greetingAsync.value ?? l10n.settingsGreetingDefault;
    onSeed(greeting, signatureAsync.value!, textChannelAsync.value!);

    // Spec 008 §2.8: no section title — two top-level fields (Salutació,
    // Signatura), then the §2.9 text-channel selector.
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        FieldLabel(
          label: l10n.settingsGreetingLabel,
          child: AppTextField(
            controller: greetingController,
            hintText: l10n.settingsGreetingHint,
          ),
        ),
        const SizedBox(height: 16),
        FieldLabel(
          label: l10n.settingsSignatureLabel,
          child: AppTextField(
            controller: signatureController,
            hintText: l10n.settingsSignatureHint,
            maxLines: 3,
          ),
        ),
        const SizedBox(height: 16),
        FieldLabel(
          label: l10n.settingsTextChannelLabel,
          child: SegmentedChoice<TextMessageChannel>(
            value: textChannel,
            onChanged: onChannelChanged,
            options: const [
              SegmentedChoiceOption(TextMessageChannel.sms, 'SMS'),
              SegmentedChoiceOption(TextMessageChannel.whatsapp, 'WhatsApp'),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddCategorySheet extends StatefulWidget {
  const _AddCategorySheet();

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          12 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              l10n.supplierCategoryAddTitle,
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: 16),
            FieldLabel(
              label: l10n.supplierCategoryNameLabel,
              child: AppTextField(
                controller: _controller,
                autofocus: true,
                hintText: l10n.supplierCategoryNameHint,
                textInputAction: TextInputAction.done,
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: l10n.createAction,
              icon: Icons.add,
              onPressed: () => _submit(context),
            ),
          ],
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          text,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
