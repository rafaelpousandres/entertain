import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/primary_button.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/data/reference_data.dart';
import '../../events/data/events_providers.dart' show currentGroupIdProvider;
import '../data/group_supplier_setting.dart';
import '../data/message_channel.dart';
import '../data/shopping_providers.dart';
import '../supplier_category_format.dart';

/// App version shown in the General tab. Kept in sync with `pubspec.yaml`'s
/// `version:` (the MVP has no `package_info_plus` dependency — Lean first).
const String _appVersion = '1.0.0';

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
  bool _seeded = false;
  bool _saving = false;

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

  void _seedMessages(String greeting, String signature) {
    if (_seeded) return;
    _greetingController.text = greeting;
    _signatureController.text = signature;
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

      ref.invalidate(groupGreetingProvider);
      ref.invalidate(groupSignatureProvider);
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

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(l10n.settingsScreenTitle, style: AppTypography.display),
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
        child: TabBarView(
          controller: _tab,
          children: [
            const _GeneralTab(),
            _SuppliersTab(localeCode: localeCode),
            _MessagesTab(
              greetingAsync: greetingAsync,
              signatureAsync: signatureAsync,
              greetingController: _greetingController,
              signatureController: _signatureController,
              onSeed: _seedMessages,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(l10n),
    );
  }

  Widget? _buildBottomBar(AppLocalizations l10n) {
    // General has no action bar; Proveïdors adds a category; Missatges saves.
    if (_tab.index == 0) return null;
    final isMessages = _tab.index == 2;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: PrimaryButton(
          label: isMessages
              ? l10n.saveAction
              : l10n.supplierCategoryAddAction,
          icon: isMessages ? Icons.check : Icons.add,
          onPressed: isMessages
              ? (_saving ? null : _saveMessages)
              : _addCategory,
        ),
      ),
    );
  }
}

class _GeneralTab extends StatelessWidget {
  const _GeneralTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.appTitle, style: AppTypography.sectionTitle),
              const SizedBox(height: 6),
              Text(
                l10n.settingsAboutVersion(_appVersion),
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
    );
  }
}

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
    // User categories first (the manageable ones), then system, each sorted by
    // name — a calm, predictable order for the admin list.
    final categories = [...categoriesAsync.value!]..sort((a, b) {
        if (a.isUserCategory != b.isUserCategory) {
          return a.isUserCategory ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        for (final category in categories) ...[
          _CategoryRow(
            category: category,
            setting: settingsMap[category.id],
            onTap: () => context.push(
              '/settings/category',
              extra: category,
            ),
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
    final address = setting?.channelAddress?.trim() ?? '';
    final label = channel == MessageChannel.whatsapp
        ? l10n.channelWhatsApp
        : l10n.channelEmail;
    return address.isEmpty ? label : '$label${l10n.metadataSeparator}$address';
  }
}

class _MessagesTab extends StatelessWidget {
  const _MessagesTab({
    required this.greetingAsync,
    required this.signatureAsync,
    required this.greetingController,
    required this.signatureController,
    required this.onSeed,
  });

  final AsyncValue<String?> greetingAsync;
  final AsyncValue<String> signatureAsync;
  final TextEditingController greetingController;
  final TextEditingController signatureController;
  final void Function(String greeting, String signature) onSeed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (greetingAsync.hasError || signatureAsync.hasError) {
      return _Message(text: l10n.settingsLoadError);
    }
    if (greetingAsync.isLoading || signatureAsync.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    // Null greeting means "never set" — seed the localised default ("Hola,").
    // An empty string means the user cleared it; keep it empty.
    final greeting = greetingAsync.value ?? l10n.settingsGreetingDefault;
    onSeed(greeting, signatureAsync.value!);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          l10n.settingsSignatureSectionTitle,
          style: AppTypography.sectionTitle,
        ),
        const SizedBox(height: 12),
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
