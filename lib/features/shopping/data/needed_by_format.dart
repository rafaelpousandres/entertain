/// Needed-by date/time formatting for the supplier message (Spec 015 §1).
///
/// Kept here, outside the screen, so the date-vs-date+time rule is unit-tested
/// without a widget. The composer / subject ask for one sentence; this builds
/// it from the optional date and optional time.
library;

import 'package:flutter/material.dart' show Locale, TimeOfDay;

import '../../../l10n/app_localizations.dart';
import '../../events/widgets/event_formatters.dart';

/// Wire form of a needed-by time: 24-hour, zero-padded "HH:mm". Append ":00"
/// for the Postgres `time` column. Use [formatNeededByTimeDisplay] for anything
/// the user sees.
String formatNeededByTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// Display form of a needed-by time, with the hour mark appended: "13:00h"
/// (Spec 016 §5.4, ca/es/en). Used in the supplier message and wherever the
/// time renders for the user — never for the DB wire value.
String formatNeededByTimeDisplay(TimeOfDay time) => '${formatNeededByTime(time)}h';

/// The needed-by sentence shared with the supplier:
///   * no date          → '' (omitted; Fixes §2.5),
///   * date only        → "Needed by 20 June",
///   * date and time    → "Needed by 20 June at 13:00".
String neededBySentence(
  AppLocalizations l10n,
  Locale locale,
  DateTime? date,
  TimeOfDay? time,
) {
  if (date == null) return '';
  final dayMonth = formatDayMonth(date, locale);
  if (time == null) return l10n.supplierMessageNeededBy(dayMonth);
  return l10n.supplierMessageNeededByWithTime(
    dayMonth,
    formatNeededByTimeDisplay(time),
  );
}
