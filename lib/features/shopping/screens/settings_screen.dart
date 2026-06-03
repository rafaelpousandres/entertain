import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/primary_button.dart';
import '../../../ui/segmented_choice.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/data/reference_data.dart';
import '../../events/data/events_providers.dart' show currentGroupIdProvider;
import '../data/message_channel.dart';
import '../data/shopping_providers.dart';
import '../supplier_category_format.dart';

/// Global app settings (Specification 005 §2.5): the outgoing-message
/// signature and the per-supplier-category channel + address.
///
/// Persistence decision (left open by the Spec): an explicit Save action in
/// the bottom action bar, consistent with every other editor in the app
/// (event form, dish editor, ingredient editor). This keeps persistence
/// bulletproof — no focus-loss edge cases — and matches the established
/// pattern rather than introducing a one-off autosave surface.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _signatureController = TextEditingController();
  final _addressControllers = <String, TextEditingController>{};
  final _channels = <String, MessageChannel?>{};
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _signatureController.dispose();
    for (final c in _addressControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// One-time initialisation of the form controllers from loaded data. Runs
  /// in build the first time all three sources resolve; setting controller
  /// text here doesn't require a rebuild.
  void _seed(
    String signature,
    List<SupplierCategory> categories,
    Map<String, dynamic> settingsMap,
  ) {
    if (_seeded) return;
    _signatureController.text = signature;
    for (final category in categories) {
      final setting = settingsMap[category.id];
      _channels[category.id] = setting?.channel;
      _addressControllers[category.id] = TextEditingController(
        text: setting?.channelAddress ?? '',
      );
    }
    _seeded = true;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final groupId = await ref.read(currentGroupIdProvider.future);
      final repo = ref.read(settingsRepositoryProvider);

      final signature = _signatureController.text.trim();
      await repo.updateSignature(groupId, signature.isEmpty ? null : signature);

      for (final entry in _addressControllers.entries) {
        final address = entry.value.text.trim();
        await repo.upsertSetting(
          groupId: groupId,
          supplierCategoryId: entry.key,
          channel: _channels[entry.key],
          channelAddress: address.isEmpty ? null : address,
        );
      }

      ref.invalidate(groupSignatureProvider);
      ref.invalidate(groupSupplierSettingsProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveAction)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsSaveError)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    final categoriesAsync = ref.watch(supplierCategoriesProvider(localeCode));
    final settingsAsync = ref.watch(groupSupplierSettingsProvider);
    final signatureAsync = ref.watch(groupSignatureProvider);

    final loading =
        categoriesAsync.isLoading ||
        settingsAsync.isLoading ||
        signatureAsync.isLoading;
    final hasError =
        categoriesAsync.hasError ||
        settingsAsync.hasError ||
        signatureAsync.hasError;

    Widget body;
    if (hasError) {
      body = _Message(text: l10n.settingsLoadError);
    } else if (loading) {
      body = const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    } else {
      final categories = categoriesAsync.value!
          .where((c) => !isPantryCategory(c.code))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      _seed(signatureAsync.value!, categories, settingsAsync.value!);
      body = _SettingsForm(
        signatureController: _signatureController,
        categories: categories,
        addressControllers: _addressControllers,
        channels: _channels,
        onChannelChanged: (categoryId, channel) =>
            setState(() => _channels[categoryId] = channel),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(l10n.settingsScreenTitle, style: AppTypography.display),
      ),
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: PrimaryButton(
          label: l10n.saveAction,
          icon: Icons.check,
          onPressed: (_saving || loading || hasError) ? null : _save,
        ),
      ),
    );
  }
}

class _SettingsForm extends StatelessWidget {
  const _SettingsForm({
    required this.signatureController,
    required this.categories,
    required this.addressControllers,
    required this.channels,
    required this.onChannelChanged,
  });

  final TextEditingController signatureController;
  final List<SupplierCategory> categories;
  final Map<String, TextEditingController> addressControllers;
  final Map<String, MessageChannel?> channels;
  final void Function(String categoryId, MessageChannel? channel)
  onChannelChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          l10n.settingsSignatureSectionTitle,
          style: AppTypography.sectionTitle,
        ),
        const SizedBox(height: 12),
        FieldLabel(
          label: l10n.settingsSignatureLabel,
          child: AppTextField(
            controller: signatureController,
            hintText: l10n.settingsSignatureHint,
            maxLines: 3,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          l10n.settingsCategoriesSectionTitle,
          style: AppTypography.sectionTitle,
        ),
        const SizedBox(height: 12),
        for (final category in categories) ...[
          _CategorySettingCard(
            category: category,
            channel: channels[category.id],
            addressController: addressControllers[category.id]!,
            onChannelChanged: (channel) =>
                onChannelChanged(category.id, channel),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CategorySettingCard extends StatelessWidget {
  const _CategorySettingCard({
    required this.category,
    required this.channel,
    required this.addressController,
    required this.onChannelChanged,
  });

  final SupplierCategory category;
  final MessageChannel? channel;
  final TextEditingController addressController;
  final ValueChanged<MessageChannel?> onChannelChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                supplierCategoryIcon(category.code),
                size: 20,
                color: AppColors.accentSecondary,
              ),
              const SizedBox(width: 8),
              Text(category.name, style: AppTypography.body),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.settingsChannelLabel,
            style: AppTypography.label.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          SegmentedChoice<MessageChannel?>(
            value: channel,
            onChanged: onChannelChanged,
            options: [
              SegmentedChoiceOption(MessageChannel.whatsapp, l10n.channelWhatsApp),
              SegmentedChoiceOption(MessageChannel.email, l10n.channelEmail),
              SegmentedChoiceOption(null, l10n.channelNone),
            ],
          ),
          if (channel != null) ...[
            const SizedBox(height: 12),
            FieldLabel(
              label: channel == MessageChannel.whatsapp
                  ? l10n.addressWhatsAppLabel
                  : l10n.addressEmailLabel,
              child: AppTextField(
                controller: addressController,
                hintText: channel == MessageChannel.whatsapp
                    ? l10n.addressWhatsAppHint
                    : l10n.addressEmailHint,
                keyboardType: channel == MessageChannel.whatsapp
                    ? TextInputType.phone
                    : TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
              ),
            ),
          ],
        ],
      ),
    );
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
