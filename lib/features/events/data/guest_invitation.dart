/// Spec 023 §1.5/§1.6 — pure helpers for the guest list: the invitation-text
/// prefill, the over-capacity check, the channels a guest can be invited
/// through, and the contact→fields mapping. Kept free of widgets so they are
/// unit-testable and reused by the Convidats UI.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../util/contact_picker.dart';
import '../widgets/event_formatters.dart';
import 'event.dart';
import 'event_guest.dart';

/// The channels an invitation can be sent through (§1.6). `text` resolves to
/// WhatsApp or SMS at send time per the group's preference (reusing the supplier
/// order-message dispatch); `email` opens the mail client.
enum InviteChannel { text, email }

/// Which channels a guest supports, in offer order (phone first). Empty when the
/// guest has neither a phone nor an email — then sending is blocked (§1.2).
List<InviteChannel> availableInviteChannels({
  required bool hasPhone,
  required bool hasEmail,
}) => [
  if (hasPhone) InviteChannel.text,
  if (hasEmail) InviteChannel.email,
];

/// §1.5 — informational only: the guest list is independent from the event's
/// people count, but the host is warned when more guests confirm than the
/// planned head-count.
bool isOverCapacity({required int confirmedCount, required int guestCount}) =>
    confirmedCount > guestCount;

/// §1.4 — buckets the guest list by state in [guestStateOrder], so the accordion
/// renders subtotals and the grand total without re-walking the list per group.
/// Every state key is present (empty list when none), keeping the UI simple.
Map<GuestState, List<EventGuest>> groupGuestsByState(List<EventGuest> guests) {
  final byState = <GuestState, List<EventGuest>>{
    for (final s in guestStateOrder) s: <EventGuest>[],
  };
  for (final g in guests) {
    byState[g.state]!.add(g);
  }
  return byState;
}

/// §1.6 — the invitation body prefilled from the event (name, date, place).
/// Only the parts the event actually has are included; reused as the editable
/// default and as the fallback body when the host hasn't customised the text.
String composeInvitationPrefill(
  AppLocalizations l10n,
  Locale locale,
  Event event,
) {
  final lines = <String>[
    l10n.invitationGreeting,
    l10n.invitationInviteLine(event.title),
  ];
  final date = event.eventDate;
  if (date != null) {
    var when = formatLongDate(date, locale);
    final time = event.eventTime;
    if (time != null) {
      final dt = DateTime(2000, 1, 1, time.hour, time.minute);
      when = '$when · ${DateFormat.Hm(locale.toLanguageTag()).format(dt)}';
    }
    lines.add(l10n.invitationWhenLine(when));
  }
  final place = event.locationName?.trim();
  if (place != null && place.isNotEmpty) {
    lines.add(l10n.invitationWhereLine(place));
  }
  lines.add(l10n.invitationCloseLine);
  return lines.join('\n');
}

/// The default form fields from a picked device contact (§1.2): the display
/// name plus the first phone/email. The editor refines multi-value contacts via
/// a choice sheet (the supplier pattern); this is the single-value mapping.
({String? name, String? phone, String? email}) guestFieldsFromContact(
  PickedContact contact,
) {
  String? firstOrNull(List<String> xs) => xs.isEmpty ? null : xs.first;
  return (
    name: contact.name,
    phone: firstOrNull(contact.phones),
    email: firstOrNull(contact.emails),
  );
}
