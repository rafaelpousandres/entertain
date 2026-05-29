import 'package:flutter/material.dart';

import 'event.dart';

/// Mutable view of an event used by the form screen. Holds the editable
/// fields while the user is filling in / editing the form; converted to a
/// row payload at save time.
class EventDraft {
  EventDraft({
    required this.title,
    required this.type,
    required this.format,
    required this.guestCount,
    this.eventDate,
    this.eventTime,
    this.locationName,
    this.notes,
  });

  /// Defaults used when starting a new event from scratch. Decisions
  /// flagged at the start of spec 003: `lunch` / `seated` / 4 guests.
  factory EventDraft.empty() => EventDraft(
    title: '',
    type: EventType.lunch,
    format: EventFormat.seated,
    guestCount: 4,
  );

  factory EventDraft.fromEvent(Event event) => EventDraft(
    title: event.title,
    type: event.type,
    format: event.format,
    guestCount: event.guestCount,
    eventDate: event.eventDate,
    eventTime: event.eventTime,
    locationName: event.locationName,
    notes: event.notes,
  );

  String title;
  EventType type;
  EventFormat format;
  int guestCount;
  DateTime? eventDate;
  TimeOfDay? eventTime;
  String? locationName;
  String? notes;

  /// Build the row payload for `insert` / `update`. `group_id` is added by
  /// the repository to keep this struct UI-only.
  Map<String, dynamic> toRow() {
    return {
      'title': title.trim(),
      'type': type.wire,
      'format': format.wire,
      'event_date': eventDate == null ? null : formatDateForDb(eventDate!),
      'event_time': eventTime == null ? null : formatTimeForDb(eventTime!),
      'location_name': _nullIfBlank(locationName),
      'guest_count': guestCount,
      'notes': _nullIfBlank(notes),
    };
  }
}

String? _nullIfBlank(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
