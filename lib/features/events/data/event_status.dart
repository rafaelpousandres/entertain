/// Derived event status (Specification 008 §2.4).
///
/// A computed, never-persisted classification of an event from its date and the
/// shopping state of its menu. Distinct from the (largely vestigial) persisted
/// `events.status` enum (planning / confirmed / done); this is what the events
/// list groups by and what the detail header shows as a chip.
library;

import 'event.dart';

/// Per-event aggregate of ingredient readiness, summed across the menu.
/// [total] is the line count; [notReady] is how many are in a state other than
/// `at_home` / `received`.
typedef EventReadiness = ({int total, int notReady});

enum DerivedEventStatus { inPreparation, ready, past }

/// Derives an event's status (Spec §2.4):
///   * **past** — its date is strictly before [today] (overrides everything).
///   * **ready** — today or later AND every ingredient is `at_home`/`received`.
///   * **inPreparation** — today or later AND at least one ingredient is not yet
///     in / received, or the menu has no ingredients at all.
///
/// [today] must be a date-only value (local midnight). [readiness] is null when
/// the event has no ingredient lines.
DerivedEventStatus deriveEventStatus(
  Event event,
  EventReadiness? readiness,
  DateTime today,
) {
  final date = event.eventDate;
  if (date != null && DateTime(date.year, date.month, date.day).isBefore(today)) {
    return DerivedEventStatus.past;
  }
  if (readiness == null || readiness.total == 0) {
    return DerivedEventStatus.inPreparation;
  }
  return readiness.notReady == 0
      ? DerivedEventStatus.ready
      : DerivedEventStatus.inPreparation;
}
