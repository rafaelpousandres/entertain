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
import '../data/ingredient_state.dart';
import '../data/message_channel.dart';
import '../data/message_composer.dart';
import '../data/message_dispatcher.dart';
import '../data/shopping_delta.dart';
import '../data/shopping_models.dart';
import '../data/shopping_providers.dart';
import '../supplier_category_format.dart';

/// Fixes §2.3: the unit name to print in a message line, or null when the
/// unit is flagged `omit_in_display` (or unknown) so the composer drops the
/// unit and its connector — "3 ous", not "3 unitats de ous".
String? _displayUnit(Unit? unit) =>
    (unit == null || unit.omitInDisplay) ? null : unit.name;

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

  /// Needed-by date (Fixes §2.5): the date the goods are required by — the
  /// only date shared with the supplier. Initialised once from the event (the
  /// day before its date, if any) and editable before sending.
  bool _neededByInitialised = false;
  DateTime? _neededByDate;

  bool _sending = false;

  /// Effective destination for this send: the override if set, else the
  /// group's configured setting for this category.
  ({MessageChannel? channel, String? address}) _destination(
    GroupSupplierSetting? configured,
  ) {
    if (_hasOverride) {
      return (channel: _overrideChannel, address: _overrideAddress);
    }
    // Fixes §2.1: the default channel's stored address (phone for WhatsApp,
    // email for Email).
    return (channel: configured?.channel, address: configured?.defaultAddress);
  }

  Future<void> _openOverrideSheet(GroupSupplierSetting? configured) async {
    final current = _destination(configured);
    // Seed each field from the per-channel stored address, letting an active
    // override take precedence for the channel it set (Fixes §2.1 / §2.2).
    final phone = _hasOverride && _overrideChannel == MessageChannel.whatsapp
        ? _overrideAddress
        : configured?.phoneAddress;
    final email = _hasOverride && _overrideChannel == MessageChannel.email
        ? _overrideAddress
        : configured?.emailAddress;
    final result = await showModalBottomSheet<_OverrideResult>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheetContext) => _OverrideSheet(
        initialChannel: current.channel,
        initialPhone: phone,
        initialEmail: email,
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
    required String categoryName,
    required List<ShoppingLine> delta,
    required Map<String, Unit> unitsById,
    required GroupSupplierSetting? configured,
    required String greeting,
    required String signature,
  }) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final destination = _destination(configured);
    final body = _composeBody(
      delta: delta,
      unitsById: unitsById,
      greeting: greeting,
      signature: signature,
      locale: locale,
      l10n: l10n,
    );
    final subject = _composeSubject(
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

      // Fixes §2.7: opening the channel is not proof the message went out. If
      // nothing came up (no app, or the share sheet was dismissed), leave the
      // order unsent and let the user retry. Otherwise ask them to confirm.
      if (!outcome.opened) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.supplierMessageNotSent)),
        );
        if (mounted) setState(() => _sending = false);
        return;
      }

      final confirmed = await _confirmSent();
      if (confirmed != true) {
        // "No" (or dismissed): the message did not go out. Stay on the screen
        // so the user can retry.
        if (mounted) setState(() => _sending = false);
        return;
      }

      final repo = ref.read(shoppingRepositoryProvider);
      await repo.createSentOrder(
        eventId: widget.eventId,
        supplierCategoryId: widget.categoryId,
        channel: outcome.channel,
        address: outcome.address,
        sentAt: DateTime.now(),
        neededByDate: _neededByDate,
        items: delta,
      );
      // Spec 007 §3.2: every line in the sent order moves to `ordered`, here
      // at the call site after the confirmation — the dispatcher stays unaware
      // of the state machine (Spec §5).
      await repo.updateLineStates(
        [for (final line in delta) line.id],
        IngredientState.ordered,
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

  /// Post-channel confirmation (Fixes §2.7): the only reliable signal the app
  /// has that the message actually left the device.
  Future<bool?> _confirmSent() {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          l10n.supplierMessageConfirmSentTitle,
          style: AppTypography.sectionTitle,
        ),
        content: Text(
          l10n.supplierMessageConfirmSentBody,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.supplierMessageConfirmSentNo,
              style: AppTypography.button.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.supplierMessageConfirmSentYes,
              style: AppTypography.button.copyWith(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  String _composeBody({
    required List<ShoppingLine> delta,
    required Map<String, Unit> unitsById,
    required String greeting,
    required String signature,
    required Locale locale,
    required AppLocalizations l10n,
  }) {
    return composeMessageBody(
      greeting: greeting,
      leadingLine: _neededBySentence(locale, l10n),
      itemLines: [
        for (final line in delta)
          composeItemLine(
            quantity: formatQuantity(line.quantity),
            // Fixes §2.3: a unit flagged omit_in_display drops out (and the
            // connector with it) by reusing the no-unit path → "3 ous".
            unit: _displayUnit(unitsById[line.unitId]),
            connector: l10n.messageItemConnector,
            ingredientName: line.ingredientName,
            prepNote: line.prepNote,
            // Fixes §2.4: Catalan-only "de" → "d'" elision before vowels/h.
            elideConnector: locale.languageCode == 'ca',
          ),
      ],
      signature: signature,
    );
  }

  /// The needed-by sentence shared with the supplier, e.g. "Per al dia 5 de
  /// juny", or empty when the user left the date unset (Fixes §2.5).
  String _neededBySentence(Locale locale, AppLocalizations l10n) {
    final date = _neededByDate;
    if (date == null) return '';
    return l10n.supplierMessageNeededBy(formatDayMonth(date, locale));
  }

  String _categoryName(List<SupplierCategory>? categories) {
    if (categories == null) return '';
    for (final c in categories) {
      if (c.id == widget.categoryId) return c.name;
    }
    return '';
  }

  /// Email subject (Fixes §2.5): no event title, no event date — only the
  /// category and, when set, the needed-by sentence. Keeps the supplier's
  /// inbox informative without leaking the event.
  String _composeSubject({
    required String categoryName,
    required Locale locale,
    required AppLocalizations l10n,
  }) {
    final neededBy = _neededBySentence(locale, l10n);
    final parts = <String>[
      categoryName,
      if (neededBy.isNotEmpty) neededBy,
    ];
    return parts.join(l10n.metadataSeparator);
  }

  Future<void> _pickNeededBy(DateTime? eventDate) async {
    final initial = _neededByDate ?? eventDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(
      () => _neededByDate = DateTime(picked.year, picked.month, picked.day),
    );
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
    final greetingAsync = ref.watch(groupGreetingProvider);
    final signatureAsync = ref.watch(groupSignatureProvider);

    final asyncs = [
      eventAsync,
      shoppingAsync,
      categoriesAsync,
      unitsAsync,
      settingsAsync,
      greetingAsync,
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
            // Null greeting means "never set" — fall back to the localised
            // default ("Hola,"); an empty string means the user cleared it.
            final greeting = greetingAsync.value ?? l10n.settingsGreetingDefault;
            final signature = signatureAsync.value!;

            // Fixes §2.5: default the needed-by date to the day before the
            // event (when known), once, before the first paint. Assigned
            // directly — we are already inside build, and it must not override
            // a value the user has since picked.
            if (!_neededByInitialised) {
              _neededByInitialised = true;
              final d = event.eventDate;
              _neededByDate = d == null
                  ? null
                  : DateTime(d.year, d.month, d.day)
                      .subtract(const Duration(days: 1));
            }

            final categoryLines =
                linesByCategory(shopping.lines)[widget.categoryId] ??
                const <ShoppingLine>[];
            final categoryOrders =
                ordersByCategory(shopping.orders)[widget.categoryId] ??
                const <SupplierOrder>[];
            final delta = deltaForCategory(categoryLines);

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
              delta: delta,
              unitsById: unitsById,
              greeting: greeting,
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
              neededByDate: _neededByDate,
              onPickNeededBy: () => _pickNeededBy(event.eventDate),
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
                final shopping = shoppingAsync.value!;
                final unitsById = {
                  for (final u in unitsAsync.value!) u.id: u,
                };
                final configured = settingsAsync.value![widget.categoryId];
                final greeting =
                    greetingAsync.value ?? l10n.settingsGreetingDefault;
                final signature = signatureAsync.value!;
                final categoryLines =
                    linesByCategory(shopping.lines)[widget.categoryId] ??
                    const <ShoppingLine>[];
                final delta = deltaForCategory(categoryLines);
                if (delta.isEmpty) return;
                _send(
                  categoryName: categoryName,
                  delta: delta,
                  unitsById: unitsById,
                  configured: configured,
                  greeting: greeting,
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
    required this.neededByDate,
    required this.onPickNeededBy,
    required this.onChangeDestination,
  });

  final Event event;
  final String categoryName;
  final String messageBody;
  final MessageChannel? destinationChannel;
  final String? destinationAddress;
  final Locale locale;
  final DateTime? neededByDate;
  final VoidCallback onPickNeededBy;
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
                channelIcon(destinationChannel),
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
        // Needed-by date (Fixes §2.5): editable, defaults to the day before
        // the event; the only date that reaches the supplier.
        Text(
          l10n.supplierMessageNeededByLabel,
          style: AppTypography.label.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPickNeededBy,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_outlined,
                    size: 18,
                    color: AppColors.accentSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      neededByDate == null
                          ? l10n.supplierMessageNeededByEmpty
                          : formatLongDate(neededByDate!, locale),
                      style: AppTypography.body.copyWith(
                        color: neededByDate == null
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.disabled,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
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
                  unit: _displayUnit(unitsById[item.unitId]),
                  connector: l10n.messageItemConnector,
                  ingredientName: item.ingredientName,
                  prepNote: item.prepNote,
                  elideConnector: locale.languageCode == 'ca',
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

/// Per-send destination chooser (Spec §2.4, Fixes §2.1). Holds a phone and an
/// email field independently and a channel selector; switching the channel
/// changes which stored address the send uses, so the user can flip from the
/// default WhatsApp number to the email address (or vice versa) before sending.
class _OverrideSheet extends StatefulWidget {
  const _OverrideSheet({
    this.initialChannel,
    this.initialPhone,
    this.initialEmail,
  });

  final MessageChannel? initialChannel;
  final String? initialPhone;
  final String? initialEmail;

  @override
  State<_OverrideSheet> createState() => _OverrideSheetState();
}

class _OverrideSheetState extends State<_OverrideSheet> {
  late MessageChannel? _channel = widget.initialChannel;
  late final TextEditingController _phoneController =
      TextEditingController(text: widget.initialPhone ?? '');
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail ?? '');

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
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
              // Fixes round 3 §2.2: icon chips (label kept as tooltip) so the
              // four channels read at a glance and never truncate as text.
              options: [
                SegmentedChoiceOption(
                  MessageChannel.whatsapp,
                  l10n.channelWhatsApp,
                  icon: channelIcon(MessageChannel.whatsapp),
                ),
                SegmentedChoiceOption(
                  MessageChannel.email,
                  l10n.channelEmail,
                  icon: channelIcon(MessageChannel.email),
                ),
                SegmentedChoiceOption(
                  MessageChannel.share,
                  l10n.channelShare,
                  icon: channelIcon(MessageChannel.share),
                ),
                SegmentedChoiceOption(
                  null,
                  l10n.channelNone,
                  icon: channelIcon(null),
                ),
              ],
            ),
            if (_channel == MessageChannel.whatsapp) ...[
              const SizedBox(height: 16),
              FieldLabel(
                label: l10n.supplierPhoneLabel,
                child: AppTextField(
                  controller: _phoneController,
                  autofocus: true,
                  hintText: l10n.addressWhatsAppHint,
                  keyboardType: TextInputType.phone,
                  textCapitalization: TextCapitalization.none,
                ),
              ),
            ] else if (_channel == MessageChannel.email) ...[
              const SizedBox(height: 16),
              FieldLabel(
                label: l10n.supplierEmailLabel,
                child: AppTextField(
                  controller: _emailController,
                  autofocus: true,
                  hintText: l10n.addressEmailHint,
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                ),
              ),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              label: l10n.applyAction,
              onPressed: () {
                // The send uses the address of the selected channel.
                final address = switch (_channel) {
                  MessageChannel.whatsapp => _phoneController.text.trim(),
                  MessageChannel.email => _emailController.text.trim(),
                  // Compartir / Cap both go through the share sheet — no address.
                  MessageChannel.share => '',
                  null => '',
                };
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
