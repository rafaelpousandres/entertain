import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/app_form_field.dart';
import '../../../ui/primary_button.dart';
import '../../../ui/segmented_choice.dart';
import '../../catalog/data/catalog_providers.dart';
import '../../catalog/data/dish.dart' show formatQuantity;
import '../../catalog/data/reference_data.dart';
import '../../events/data/event.dart';
import '../../events/data/events_providers.dart';
import '../../events/widgets/event_formatters.dart';
import '../data/group_supplier_setting.dart';
import '../data/message_channel.dart';
import '../data/message_composer.dart';
import '../data/message_dispatcher.dart';
import '../data/shopping_delta.dart';
import '../data/shopping_models.dart';
import '../data/shopping_providers.dart';

/// Composes and sends the supplier message for one category of one event
/// (Specification 005 §2.4). The body is the current unsent delta; sending
/// freezes it into a new `orders` row and dispatches through the configured
/// (or per-send overridden) channel.
class SupplierMessageScreen extends ConsumerStatefulWidget {
  const SupplierMessageScreen({
    super.key,
    required this.eventId,
    required this.categoryId,
  });

  final String eventId;
  final String categoryId;

  @override
  ConsumerState<SupplierMessageScreen> createState() =>
      _SupplierMessageScreenState();
}

class _SupplierMessageScreenState
    extends ConsumerState<SupplierMessageScreen> {
  /// Per-send destination override (Spec §2.4). Null until the user sets one;
  /// it never touches the persisted Settings configuration.
  bool _hasOverride = false;
  MessageChannel? _overrideChannel;
  String? _overrideAddress;

  bool _sending = false;

  /// Effective destination for this send: the override if set, else the
  /// group's configured setting for this category.
  ({MessageChannel? channel, String? address}) _destination(
    GroupSupplierSetting? configured,
  ) {
    if (_hasOverride) {
      return (channel: _overrideChannel, address: _overrideAddress);
    }
    return (channel: configured?.channel, address: configured?.channelAddress);
  }

  Future<void> _openOverrideSheet(GroupSupplierSetting? configured) async {
    final current = _destination(configured);
    final result = await showModalBottomSheet<_OverrideResult>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheetContext) => _OverrideSheet(
        initialChannel: current.channel,
        initialAddress: current.address,
      ),
    );
    if (result == null) return;
    setState(() {
      _hasOverride = true;
      _overrideChannel = result.channel;
      _overrideAddress = result.address;
    });
  }

  Future<void> _send({
    required Event event,
    required String categoryName,
    required List<ShoppingLine> delta,
    required Map<String, Unit> unitsById,
    required GroupSupplierSetting? configured,
    required String signature,
  }) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final destination = _destination(configured);
    final body = _composeBody(
      event: event,
      delta: delta,
      unitsById: unitsById,
      signature: signature,
      locale: locale,
      l10n: l10n,
    );
    final subject = _composeSubject(
      event: event,
      categoryName: categoryName,
      locale: locale,
      l10n: l10n,
    );

    setState(() => _sending = true);
    try {
      final outcome = await dispatchMessage(
        channel: destination.channel,
        address: destination.address,
        subject: subject,
        body: body,
      );
      await ref.read(shoppingRepositoryProvider).createSentOrder(
            eventId: widget.eventId,
            supplierCategoryId: widget.categoryId,
            channel: outcome.channel,
            address: outcome.address,
            sentAt: DateTime.now(),
            items: delta,
          );
      ref.invalidate(eventShoppingProvider(widget.eventId));
      if (!mounted) return;
      router.pop();
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.supplierMessageSendError)),
      );
      if (mounted) setState(() => _sending = false);
    }
  }

  String _composeBody({
    required Event event,
    required List<ShoppingLine> delta,
    required Map<String, Unit> unitsById,
    required String signature,
    required Locale locale,
    required AppLocalizations l10n,
  }) {
    return composeMessageBody(
      identifyingLine: _identifyingLine(event, locale, l10n),
      itemLines: [
        for (final line in delta)
          composeItemLine(
            quantity: formatQuantity(line.quantity),
            unit: unitsById[line.unitId]?.name,
            ingredientName: line.ingredientName,
          ),
      ],
      signature: signature,
    );
  }

  String _identifyingLine(Event event, Locale locale, AppLocalizations l10n) {
    if (event.eventDate == null) return event.title;
    return '${event.title}${l10n.metadataSeparator}'
        '${formatLongDate(event.eventDate!, locale)}';
  }

  String _categoryName(List<SupplierCategory>? categories) {
    if (categories == null) return '';
    for (final c in categories) {
      if (c.id == widget.categoryId) return c.name;
    }
    return '';
  }

  String _composeSubject({
    required Event event,
    required String categoryName,
    required Locale locale,
    required AppLocalizations l10n,
  }) {
    final parts = <String>[
      event.title,
      categoryName,
      if (event.eventDate != null) formatLongDate(event.eventDate!, locale),
    ];
    return parts.join(l10n.metadataSeparator);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final localeCode = locale.languageCode;

    final eventAsync = ref.watch(eventByIdProvider(widget.eventId));
    final shoppingAsync = ref.watch(eventShoppingProvider(widget.eventId));
    final categoriesAsync = ref.watch(supplierCategoriesProvider(localeCode));
    final unitsAsync = ref.watch(unitsProvider(localeCode));
    final settingsAsync = ref.watch(groupSupplierSettingsProvider);
    final signatureAsync = ref.watch(groupSignatureProvider);

    final asyncs = [
      eventAsync,
      shoppingAsync,
      categoriesAsync,
      unitsAsync,
      settingsAsync,
      signatureAsync,
    ];
    final loading = asyncs.any((a) => a.isLoading);
    final hasError = asyncs.any((a) => a.hasError);

    final categoryName = _categoryName(categoriesAsync.value);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.backAction,
          onPressed: () => context.pop(),
        ),
        title: Text(categoryName, style: AppTypography.sectionTitle),
      ),
      body: SafeArea(
        top: false,
        child: Builder(
          builder: (context) {
            if (hasError) {
              return _Message(text: l10n.eventsLoadError);
            }
            if (loading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              );
            }

            final event = eventAsync.value!;
            final shopping = shoppingAsync.value!;
            final unitsById = {for (final u in unitsAsync.value!) u.id: u};
            final configured = settingsAsync.value![widget.categoryId];
            final signature = signatureAsync.value!;

            final categoryLines =
                linesByCategory(shopping.lines)[widget.categoryId] ??
                const <ShoppingLine>[];
            final categoryOrders =
                ordersByCategory(shopping.orders)[widget.categoryId] ??
                const <SupplierOrder>[];
            final delta = deltaForCategory(categoryLines, categoryOrders);

            if (delta.isEmpty) {
              return _NothingToSend(
                event: event,
                categoryName: categoryName,
                orders: categoryOrders,
                unitsById: unitsById,
                locale: locale,
              );
            }

            final body = _composeBody(
              event: event,
              delta: delta,
              unitsById: unitsById,
              signature: signature,
              locale: locale,
              l10n: l10n,
            );
            final destination = _destination(configured);

            return _Composer(
              event: event,
              categoryName: categoryName,
              messageBody: body,
              destinationChannel: destination.channel,
              destinationAddress: destination.address,
              locale: locale,
              onChangeDestination: () => _openOverrideSheet(configured),
            );
          },
        ),
      ),
      bottomNavigationBar: (loading || hasError)
          ? null
          : _SendBar(
              shoppingAsync: shoppingAsync,
              onSend: () {
                final event = eventAsync.value!;
                final shopping = shoppingAsync.value!;
                final unitsById = {
                  for (final u in unitsAsync.value!) u.id: u,
                };
                final configured = settingsAsync.value![widget.categoryId];
                final signature = signatureAsync.value!;
                final categoryLines =
                    linesByCategory(shopping.lines)[widget.categoryId] ??
                    const <ShoppingLine>[];
                final categoryOrders =
                    ordersByCategory(shopping.orders)[widget.categoryId] ??
                    const <SupplierOrder>[];
                final delta = deltaForCategory(categoryLines, categoryOrders);
                if (delta.isEmpty) return;
                _send(
                  event: event,
                  categoryName: categoryName,
                  delta: delta,
                  unitsById: unitsById,
                  configured: configured,
                  signature: signature,
                );
              },
              sending: _sending,
            ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.event,
    required this.categoryName,
    required this.messageBody,
    required this.destinationChannel,
    required this.destinationAddress,
    required this.locale,
    required this.onChangeDestination,
  });

  final Event event;
  final String categoryName;
  final String messageBody;
  final MessageChannel? destinationChannel;
  final String? destinationAddress;
  final Locale locale;
  final VoidCallback onChangeDestination;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinationText = _destinationText(l10n);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(categoryName, style: AppTypography.display),
        const SizedBox(height: 6),
        Text(
          _headerLine(l10n),
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        if (destinationText != null) ...[
          Row(
            children: [
              Icon(
                destinationChannel == MessageChannel.whatsapp
                    ? Icons.chat_outlined
                    : destinationChannel == MessageChannel.email
                    ? Icons.mail_outline
                    : Icons.ios_share,
                size: 18,
                color: AppColors.accentSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  destinationText,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Text(
          l10n.supplierMessagePreviewLabel,
          style: AppTypography.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: SelectableText(messageBody, style: AppTypography.body),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: onChangeDestination,
            icon: const Icon(
              Icons.edit_outlined,
              size: 18,
              color: AppColors.accentSecondary,
            ),
            label: Text(
              l10n.supplierMessageChangeDestination,
              style: AppTypography.button.copyWith(
                color: AppColors.accentSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _headerLine(AppLocalizations l10n) {
    if (event.eventDate == null) return event.title;
    return '${event.title}${l10n.metadataSeparator}'
        '${formatLongDate(event.eventDate!, locale)}';
  }

  String? _destinationText(AppLocalizations l10n) {
    final address = destinationAddress?.trim() ?? '';
    if (destinationChannel == MessageChannel.whatsapp && address.isNotEmpty) {
      return '${l10n.channelWhatsApp}: $address';
    }
    if (destinationChannel == MessageChannel.email && address.isNotEmpty) {
      return '${l10n.channelEmail}: $address';
    }
    return null; // share sheet — destination chosen at send time
  }
}

class _SendBar extends StatelessWidget {
  const _SendBar({
    required this.shoppingAsync,
    required this.onSend,
    required this.sending,
  });

  final AsyncValue shoppingAsync;
  final VoidCallback onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Hide the send bar entirely on the "nothing to send" state.
    final shopping = shoppingAsync.value;
    if (shopping == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: PrimaryButton(
          label: l10n.supplierMessageSendAction,
          icon: Icons.send,
          onPressed: sending ? null : onSend,
        ),
      ),
    );
  }
}

/// Empty-delta state (Spec §2.4): nothing new to send, plus the history of
/// orders already sent for this category.
class _NothingToSend extends StatelessWidget {
  const _NothingToSend({
    required this.event,
    required this.categoryName,
    required this.orders,
    required this.unitsById,
    required this.locale,
  });

  final Event event;
  final String categoryName;
  final List<SupplierOrder> orders;
  final Map<String, Unit> unitsById;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(categoryName, style: AppTypography.display),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Text(
                l10n.supplierMessageNothingToSendTitle,
                style: AppTypography.sectionTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.supplierMessageNothingToSendBody,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        if (orders.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            l10n.supplierMessagePreviousOrders,
            style: AppTypography.sectionTitle,
          ),
          const SizedBox(height: 8),
          for (final order in orders)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SentOrderCard(
                order: order,
                unitsById: unitsById,
                locale: locale,
              ),
            ),
        ],
      ],
    );
  }
}

/// A sent order shown as a historical entry — its send date and frozen items.
/// Reused by the shopping panel and the nothing-to-send state.
class SentOrderCard extends StatelessWidget {
  const SentOrderCard({
    super.key,
    required this.order,
    required this.unitsById,
    required this.locale,
  });

  final SupplierOrder order;
  final Map<String, Unit> unitsById;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateText = order.sentAt == null
        ? ''
        : formatLongDate(order.sentAt!.toLocal(), locale);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 16,
                color: AppColors.success,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.shoppingSentOrderTitle(dateText),
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                l10n.shoppingSentOrderItemCount(order.items.length),
                style: AppTypography.caption,
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                composeItemLine(
                  quantity: formatQuantity(item.quantity),
                  unit: unitsById[item.unitId]?.name,
                  ingredientName: item.ingredientName,
                ),
                style: AppTypography.caption,
              ),
            ),
        ],
      ),
    );
  }
}

class _OverrideResult {
  const _OverrideResult({this.channel, this.address});
  final MessageChannel? channel;
  final String? address;
}

class _OverrideSheet extends StatefulWidget {
  const _OverrideSheet({this.initialChannel, this.initialAddress});

  final MessageChannel? initialChannel;
  final String? initialAddress;

  @override
  State<_OverrideSheet> createState() => _OverrideSheetState();
}

class _OverrideSheetState extends State<_OverrideSheet> {
  late MessageChannel? _channel = widget.initialChannel;
  late final TextEditingController _addressController =
      TextEditingController(text: widget.initialAddress ?? '');

  @override
  void dispose() {
    _addressController.dispose();
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
              l10n.destinationOverrideTitle,
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: 16),
            SegmentedChoice<MessageChannel?>(
              value: _channel,
              onChanged: (channel) => setState(() => _channel = channel),
              options: [
                SegmentedChoiceOption(
                  MessageChannel.whatsapp,
                  l10n.channelWhatsApp,
                ),
                SegmentedChoiceOption(MessageChannel.email, l10n.channelEmail),
                SegmentedChoiceOption(null, l10n.channelNone),
              ],
            ),
            if (_channel != null) ...[
              const SizedBox(height: 16),
              FieldLabel(
                label: _channel == MessageChannel.whatsapp
                    ? l10n.addressWhatsAppLabel
                    : l10n.addressEmailLabel,
                child: AppTextField(
                  controller: _addressController,
                  autofocus: true,
                  hintText: _channel == MessageChannel.whatsapp
                      ? l10n.addressWhatsAppHint
                      : l10n.addressEmailHint,
                  keyboardType: _channel == MessageChannel.whatsapp
                      ? TextInputType.phone
                      : TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                ),
              ),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              label: l10n.applyAction,
              onPressed: () {
                final address = _addressController.text.trim();
                Navigator.of(context).pop(
                  _OverrideResult(
                    channel: _channel,
                    address: address.isEmpty ? null : address,
                  ),
                );
              },
            ),
          ],
        ),
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
