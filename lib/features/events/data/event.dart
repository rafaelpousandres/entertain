/// Domain model for an `event` row.
///
/// Only the columns this screen group reads or writes are modelled. Address
/// / latitude / longitude live in the schema for later phases (see the
/// data model document) and are intentionally absent here, per the "lean
/// first" rule in `CLAUDE.md`.
library;

import 'package:flutter/material.dart';

enum EventType { lunch, dinner, other }

enum EventFormat { seated, buffet, other }

enum EventStatus { planning, confirmed, done }

/// Source of truth for serialising enum values into Postgres `enum` types.
extension EventTypeWire on EventType {
  String get wire => switch (this) {
    EventType.lunch => 'lunch',
    EventType.dinner => 'dinner',
    EventType.other => 'other',
  };

  static EventType parse(String value) => switch (value) {
    'lunch' => EventType.lunch,
    'dinner' => EventType.dinner,
    _ => EventType.other,
  };
}

extension EventFormatWire on EventFormat {
  String get wire => switch (this) {
    EventFormat.seated => 'seated',
    EventFormat.buffet => 'buffet',
    EventFormat.other => 'other',
  };

  static EventFormat parse(String value) => switch (value) {
    'seated' => EventFormat.seated,
    'buffet' => EventFormat.buffet,
    _ => EventFormat.other,
  };
}

extension EventStatusWire on EventStatus {
  String get wire => switch (this) {
    EventStatus.planning => 'planning',
    EventStatus.confirmed => 'confirmed',
    EventStatus.done => 'done',
  };

  static EventStatus parse(String value) => switch (value) {
    'confirmed' => EventStatus.confirmed,
    'done' => EventStatus.done,
    _ => EventStatus.planning,
  };
}

class Event {
  const Event({
    required this.id,
    required this.groupId,
    required this.title,
    required this.type,
    required this.format,
    required this.guestCount,
    required this.status,
    required this.createdAt,
    this.eventDate,
    this.eventTime,
    this.locationName,
    this.notes,
  });

  final String id;
  final String groupId;
  final String title;
  final EventType type;
  final EventFormat format;
  final DateTime? eventDate;
  final TimeOfDay? eventTime;
  final String? locationName;
  final int guestCount;
  final String? notes;
  final EventStatus status;
  final DateTime createdAt;

  factory Event.fromRow(Map<String, dynamic> row) {
    return Event(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      title: row['title'] as String,
      type: EventTypeWire.parse(row['type'] as String),
      format: EventFormatWire.parse(row['format'] as String),
      eventDate: _parseDate(row['event_date']),
      eventTime: _parseTime(row['event_time']),
      locationName: row['location_name'] as String?,
      guestCount: (row['guest_count'] as num).toInt(),
      notes: row['notes'] as String?,
      status: EventStatusWire.parse(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  /// Columns we read from the `events` table. Listed once and reused by
  /// the repository so reads stay consistent.
  static const String selectColumns =
      'id, group_id, title, type, format, event_date, event_time, '
      'location_name, guest_count, notes, status, created_at';
}

DateTime? _parseDate(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  return DateTime.parse(raw as String);
}

TimeOfDay? _parseTime(Object? raw) {
  if (raw == null) return null;
  // Postgres returns `time` as "HH:MM:SS" (or with sub-second precision).
  final text = raw.toString();
  final parts = text.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return TimeOfDay(hour: h, minute: m);
}

/// Serialises a [TimeOfDay] into a Postgres-compatible `HH:MM:SS` string.
String formatTimeForDb(TimeOfDay value) {
  final h = value.hour.toString().padLeft(2, '0');
  final m = value.minute.toString().padLeft(2, '0');
  return '$h:$m:00';
}

/// Serialises a date-only [DateTime] into `YYYY-MM-DD`.
String formatDateForDb(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
