import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../ui/secondary_button.dart';
import '../../../ui/section_header.dart';
import '../../../ui/single_choice_sheet.dart';
import '../../shopping/data/message_channel.dart';
import '../../shopping/data/message_dispatcher.dart';
import '../../shopping/data/shopping_providers.dart'
    show groupTextMessageChannelProvider;
import '../data/event.dart';
import '../data/event_guest.dart';
import '../data/events_providers.dart';
import '../data/guest_invitation.dart';
import '../data/guest_state.dart';

/// Spec 023 §1.4–§1.6 — the Convidats tab content: grand total + over-capacity
/// notice + a "Text d'invitació" entry, then the guest list grouped by state in
/// a single-open accordion (the pattern unified in Spec 024). Each row can be
/// edited (tap) or invited (send icon → WhatsApp/SMS/email via the reused
/// order-message dispatch).
class EventGuestsView extends ConsumerStatefulWidget {
  const EventGuestsView({super.key, required this.event});

  final Event event;

  @override
  ConsumerState<EventGuestsView> createState() => _EventGuestsViewState();
}

class _EventGuestsViewState extends ConsumerState<EventGuestsView> {
  // Accordion: at most one state group open at a time (null = all collapsed).
  GuestState? _open;
  bool _sending = false;

  void _toggle(GuestState state) {
    setState(() => _open = _open == state ? null : state);
  }

  /// §1.6 — build the invitation and hand it to the guest's channel. Offers the
  /// channels the guest supports; the app composes, the user sends.
  Future<void> _invite(EventGuest guest) async {
    if (_sending) return;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final messenger = ScaffoldMessenger.of(context);
    final channels = availableInviteChannels(
      hasPhone: guest.hasPhone,
      hasEmail: guest.hasEmail,
    );
    if (channels.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.guestInviteNoContact)),
      );
      return;
    }

    InviteChannel? chosen = channels.first;
    if (channels.length > 1) {
      chosen = null;
      await showSingleChoiceSheet<InviteChannel>(
        context: context,
        title: l10n.guestInviteChannelTitle,
        options: [
          SingleChoiceOption(
            value: InviteChannel.text,
            label: l10n.guestInviteViaText,
          ),
          SingleChoiceOption(
            value: InviteChannel.email,
            label: l10n.guestInviteViaEmail,
          ),
        ],
        selectedValue: null,
        onSelected: (v) => chosen = v,
      );
      if (chosen == null) return; // dismissed
    }

    final event = widget.event;
    final body = (event.invitationText?.trim().isNotEmpty ?? false)
        ? event.invitationText!.trim()
        : composeInvitationPrefill(l10n, locale, event);
    final subject = l10n.invitationSubject(event.title);
    final textChannel =
        ref.read(groupTextMessageChannelProvider).value ??
        TextMessageChannel.whatsapp;

    setState(() => _sending = true);
    try {
      final outcome = await dispatchMessage(
        channel: chosen == InviteChannel.email
            ? MessageChannel.email
            : MessageChannel.whatsapp,
        address: chosen == InviteChannel.email ? guest.email : guest.phone,
        subject: subject,
        body: body,
        textChannel: textChannel,
      );
      if (!mounted) return;
      setState(() => _sending = false);
      if (!outcome.opened) return; // nothing launched / share dismissed
      // §1.6: mark the guest as invited once the channel actually came up.
      await ref
          .read(eventsRepositoryProvider)
          .markGuestInvited(guest.id, DateTime.now());
      ref.invalidate(eventGuestsProvider(widget.event.id));
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.guestInviteSent)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.guestInviteError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final guestsAsync = ref.watch(eventGuestsProvider(widget.event.id));

    return guestsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          l10n.eventsLoadError,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
      ),
      data: (guests) {
        final byState = groupGuestsByState(guests);
        final confirmed = byState[GuestState.confirmat]!.length;
        final overCapacity = isOverCapacity(
          confirmedCount: confirmed,
          guestCount: widget.event.guestCount,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.guestsTotalLabel, style: AppTypography.sectionTitle),
                Text(
                  l10n.guestCountLabel(guests.length),
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (overCapacity) ...[
              const SizedBox(height: 12),
              _OverCapacityBanner(
                message: l10n.guestOverCapacityNotice(
                  confirmed,
                  widget.event.guestCount,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SecondaryButton(
              label: l10n.invitationTextAction,
              icon: Icons.mail_outline,
              onPressed: () =>
                  context.push('/events/${widget.event.id}/invitation-text'),
            ),
            const SizedBox(height: 16),
            if (guests.isEmpty)
              _GuestsEmpty(message: l10n.guestsEmptyBody)
            else
              for (final state in guestStateOrder)
                if (byState[state]!.isNotEmpty) ...[
                  SectionHeader(
                    icon: guestStateIcon(state),
                    label: guestStateLabel(l10n, state),
                    countLabel: l10n.guestCountLabel(byState[state]!.length),
                    iconColor: guestStateColor(state),
                    iconRingColor: guestStateColor(state),
                    expanded: _open == state,
                    onToggle: () => _toggle(state),
                  ),
                  if (_open == state)
                    for (final guest in byState[state]!)
                      _GuestRow(
                        guest: guest,
                        sending: _sending,
                        onTap: () => context.push(
                          '/events/${widget.event.id}/guests/${guest.id}',
                          extra: guest,
                        ),
                        onInvite: () => _invite(guest),
                      ),
                ],
          ],
        );
      },
    );
  }
}

class _OverCapacityBanner extends StatelessWidget {
  const _OverCapacityBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.accentSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestsEmpty extends StatelessWidget {
  const _GuestsEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _GuestRow extends StatelessWidget {
  const _GuestRow({
    required this.guest,
    required this.sending,
    required this.onTap,
    required this.onInvite,
  });

  final EventGuest guest;
  final bool sending;
  final VoidCallback onTap;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final contact = [
      if (guest.hasPhone) guest.phone!,
      if (guest.hasEmail) guest.email!,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(guest.name, style: AppTypography.body),
                      ),
                      if (guest.isInvited) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.mark_email_read_outlined,
                          size: 16,
                          color: AppColors.accentSecondary,
                        ),
                      ],
                    ],
                  ),
                  if (contact.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        contact,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (guest.canInvite)
              IconButton(
                icon: const Icon(Icons.send_outlined, size: 20),
                color: AppColors.accent,
                tooltip: l10n.guestInviteAction,
                onPressed: sending ? null : onInvite,
              ),
          ],
        ),
      ),
    );
  }
}
