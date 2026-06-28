/// Read model for an `event_guests` row (Spec 023 Layer 1).
///
/// A flat per-event guest record: contact fields + a manual RSVP [state] + an
/// [invitedAt] stamp (set when the invitation is sent). Mirrors the lightweight
/// shape of [EventDish]/[EventDrink] read models.
library;

import 'guest_state.dart';

export 'guest_state.dart' show GuestState, GuestStateWire, guestStateOrder;

class EventGuest {
  const EventGuest({
    required this.id,
    required this.name,
    required this.state,
    this.phone,
    this.email,
    this.invitedAt,
    this.rsvpToken,
    this.dietVegetarian = false,
    this.dietVegan = false,
    this.dietGlutenFree = false,
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final GuestState state;

  /// When the host last sent this guest an invitation (§1.6). Null = not yet
  /// contacted; drives the "invitat" marker on the row.
  final DateTime? invitedAt;

  /// Spec 029 — the guest's unguessable RSVP capability; the invitation link
  /// embeds it. Null only on legacy rows read before the column existed.
  final String? rsvpToken;

  /// Spec 029 §C2 — the dietary restrictions the guest self-reported on the RSVP
  /// page (per-event, optional). Shown to the host on the Convidats tab.
  final bool dietVegetarian;
  final bool dietVegan;
  final bool dietGlutenFree;

  bool get isInvited => invitedAt != null;

  /// True when the guest reported any restriction (drives the Convidats pills).
  bool get hasDietaryFlags => dietVegetarian || dietVegan || dietGlutenFree;

  /// Whether the guest can be sent an invitation at all (§1.2: at least one of
  /// phone/email is needed to send).
  bool get hasPhone => (phone?.trim().isNotEmpty) ?? false;
  bool get hasEmail => (email?.trim().isNotEmpty) ?? false;
  bool get canInvite => hasPhone || hasEmail;

  factory EventGuest.fromRow(Map<String, dynamic> row) {
    final phone = (row['phone'] as String?)?.trim();
    final email = (row['email'] as String?)?.trim();
    final invited = row['invited_at'];
    return EventGuest(
      id: row['id'] as String,
      name: row['name'] as String,
      phone: (phone?.isEmpty ?? true) ? null : phone,
      email: (email?.isEmpty ?? true) ? null : email,
      state: GuestStateWire.parse(row['state'] as String?),
      invitedAt: invited == null ? null : DateTime.parse(invited as String),
      rsvpToken: row['rsvp_token'] as String?,
      dietVegetarian: (row['diet_vegetarian'] as bool?) ?? false,
      dietVegan: (row['diet_vegan'] as bool?) ?? false,
      dietGlutenFree: (row['diet_gluten_free'] as bool?) ?? false,
    );
  }

  static const String selectColumns =
      'id, name, phone, email, state, invited_at, rsvp_token, '
      'diet_vegetarian, diet_vegan, diet_gluten_free';
}
