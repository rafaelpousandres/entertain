import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_colors.dart';
import '../data/event.dart';
import '../data/event_status.dart';

/// Translates an [EventType] to its localised label.
String eventTypeLabel(AppLocalizations l10n, EventType type) {
  return switch (type) {
    EventType.lunch => l10n.eventTypeLunch,
    EventType.dinner => l10n.eventTypeDinner,
    EventType.other => l10n.eventTypeOther,
  };
}

String eventFormatLabel(AppLocalizations l10n, EventFormat format) {
  return switch (format) {
    EventFormat.seated => l10n.eventFormatSeated,
    EventFormat.buffet => l10n.eventFormatBuffet,
    EventFormat.other => l10n.eventFormatOther,
  };
}

String eventStatusLabel(AppLocalizations l10n, EventStatus status) {
  return switch (status) {
    EventStatus.planning => l10n.eventStatusPlanning,
    EventStatus.confirmed => l10n.eventStatusConfirmed,
    EventStatus.done => l10n.eventStatusDone,
  };
}

/// Localised label for the derived event status (Spec 008 §2.4).
String derivedEventStatusLabel(
  AppLocalizations l10n,
  DerivedEventStatus status,
) {
  return switch (status) {
    DerivedEventStatus.inPreparation => l10n.eventStatusInPreparation,
    DerivedEventStatus.ready => l10n.eventStatusReady,
    DerivedEventStatus.past => l10n.eventStatusPast,
  };
}

/// Indicator colour for the derived event status (Spec 008 §2.4): red while in
/// preparation, green when ready, a calm muted brown once past.
Color derivedEventStatusColor(DerivedEventStatus status) {
  return switch (status) {
    DerivedEventStatus.inPreparation => AppColors.danger,
    DerivedEventStatus.ready => AppColors.success,
    DerivedEventStatus.past => AppColors.textTertiary,
  };
}

/// Composes the "type · guests" line shown beneath an event card title on the
/// list screen. The event's status is conveyed by the coloured dot next to the
/// title and by the section it sits under (Spec 008 §2.4), so it is no longer
/// repeated as text here.
String eventListMetadata(AppLocalizations l10n, Event event, Locale locale) {
  final parts = [
    eventTypeLabel(l10n, event.type),
    l10n.guestsCount(event.guestCount),
  ];
  return parts.join(l10n.metadataSeparator);
}

/// Long, human form of a date for the event detail metadata line — e.g.
/// "diumenge, 14 de juny".
String formatLongDate(DateTime date, Locale locale) {
  return DateFormat.MMMMEEEEd(locale.toLanguageTag()).format(date);
}

/// Day-and-month form, without the weekday — e.g. "5 de juny". Used for the
/// needed-by sentence in supplier messages (Fixes §2.5), which reads more
/// naturally without the weekday.
String formatDayMonth(DateTime date, Locale locale) {
  return DateFormat.MMMMd(locale.toLanguageTag()).format(date);
}

/// Composes the "date · guests" line shown on the event detail header.
String eventDetailMetadata(AppLocalizations l10n, Event event, Locale locale) {
  final guests = l10n.guestsCount(event.guestCount);
  if (event.eventDate == null) {
    return guests;
  }
  final dateText = formatLongDate(event.eventDate!, locale);
  if (event.eventTime != null) {
    final timeText = _formatLocalTime(event.eventTime!, locale);
    return '$dateText, $timeText${l10n.metadataSeparator}$guests';
  }
  return '$dateText${l10n.metadataSeparator}$guests';
}

String _formatLocalTime(TimeOfDay value, Locale locale) {
  final dt = DateTime(2000, 1, 1, value.hour, value.minute);
  return DateFormat.Hm(locale.toLanguageTag()).format(dt);
}
