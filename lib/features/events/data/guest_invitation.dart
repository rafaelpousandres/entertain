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

/// §1.6 / Spec 029 — the editable invitation *body* prefilled from the event
/// (title, date+time, place) plus the confirm question. Reused as the editable
/// default and as the fallback body when the host hasn't customised the text.
/// The per-guest greeting, the RSVP link and the closing thanks are NOT here —
/// they wrap the body per guest in [assembleInvitationMessage] at send time.
String composeInvitationPrefill(
  AppLocalizations l10n,
  Locale locale,
  Event event,
) {
  // The when/where block, kept apart so a blank line can sit above it (and so it
  // collapses cleanly when the event has neither a date nor a place).
  final details = <String>[];
  final date = event.eventDate;
  if (date != null) {
    var when = formatLongDate(date, locale);
    final time = event.eventTime;
    if (time != null) {
      final dt = DateTime(2000, 1, 1, time.hour, time.minute);
      final hm = DateFormat.Hm(locale.toLanguageTag()).format(dt);
      when = l10n.invitationWhenWithTime(when, hm);
    }
    details.add(l10n.invitationWhenLine(when));
  }
  final place = event.locationName?.trim();
  if (place != null && place.isNotEmpty) {
    details.add(l10n.invitationWhereLine(place));
  }
  final lines = <String>[invitationInviteLine(l10n, event)];
  if (details.isNotEmpty) {
    lines
      ..add('') // blank line: the invite opening ↕ the when/where block
      ..addAll(details);
  }
  lines
    ..add('') // blank line: details ↕ the confirm question
    ..add(l10n.invitationCloseLine);
  return lines.join('\n');
}

/// Spec 029 (manual scope) — the invite opening, adapted to the event type:
/// "al sopar/al dinar {títol}" for dinner/lunch, and a plain "{títol}" for other
/// events (no meal word). The grammar (article/contraction) lives in the ARB so
/// each language reads naturally.
String invitationInviteLine(AppLocalizations l10n, Event event) =>
    switch (event.type) {
      EventType.lunch => l10n.invitationInviteLineLunch(event.title),
      EventType.dinner => l10n.invitationInviteLineDinner(event.title),
      EventType.other => l10n.invitationInviteLineOther(event.title),
    };

/// Spec 029 — the full message sent to one guest: a personalised greeting, the
/// invitation [body] (the prefill or the host's custom text) and the closing
/// thanks, each block separated by a blank line. Pure so it's unit-tested.
/// (The public RSVP link is parked until Pro, so no link block here.)
String assembleInvitationMessage({
  required String greeting,
  required String body,
  required String thanks,
}) => [greeting, '', body, '', thanks].join('\n');

/// Spec 029 (manual scope) — the host sets a guest's restrictions as three
/// independent booleans (vegetarian, vegan, gluten-free) directly on
/// [EventGuest]. Vegetarian/vegan are mutually exclusive, enforced in the editor
/// UI; the Convidats pills read the booleans straight. No "level" enum is needed.

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

/// Spec 029 — the public RSVP URL for a guest, or null when there's no token or
/// no configured Supabase base URL. PARKED until Entertain goes Pro: serving the
/// HTML page needs a custom domain, so the invitation no longer embeds this link
/// (RSVP is managed manually for now). Kept + unit-tested so the link format is
/// ready to wire back in. The page reads its language from `lang`.
String? rsvpUrl({
  required String baseUrl,
  required String? token,
  required String langCode,
}) {
  if (baseUrl.isEmpty || token == null || token.isEmpty) return null;
  return '$baseUrl/functions/v1/rsvp?token=$token&lang=$langCode';
}
