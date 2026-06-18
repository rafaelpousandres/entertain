import 'package:entertain/features/events/widgets/event_formatters.dart';
import 'package:entertain/features/shopping/data/needed_by_format.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Specification 015 §1 — the needed-by sentence in the supplier message:
/// date only when no time, date + time when a time is set, empty with no date.

void main() {
  // `neededBySentence` formats the date via intl; the running app initialises
  // this through flutter_localizations, so tests must do it explicitly.
  setUpAll(() => initializeDateFormatting());

  group('formatNeededByTime (24-hour HH:mm)', () {
    test('zero-pads hours and minutes', () {
      expect(formatNeededByTime(const TimeOfDay(hour: 9, minute: 5)), '09:05');
      expect(formatNeededByTime(const TimeOfDay(hour: 13, minute: 0)), '13:00');
      expect(formatNeededByTime(const TimeOfDay(hour: 0, minute: 0)), '00:00');
      expect(formatNeededByTime(const TimeOfDay(hour: 23, minute: 59)), '23:59');
    });
  });

  group('formatNeededByTimeDisplay (Spec 016 §5.4 — appends the hour mark)', () {
    test('appends "h" to the 24-hour time', () {
      expect(
        formatNeededByTimeDisplay(const TimeOfDay(hour: 13, minute: 0)),
        '13:00h',
      );
      expect(
        formatNeededByTimeDisplay(const TimeOfDay(hour: 9, minute: 5)),
        '09:05h',
      );
    });
  });

  group('neededBySentence', () {
    late AppLocalizations l10n;
    const locale = Locale('en');
    final date = DateTime(2026, 6, 20);

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(locale);
    });

    test('no date → empty sentence (omitted from the message)', () {
      expect(neededBySentence(l10n, locale, null, null), '');
      expect(
        neededBySentence(l10n, locale, null, const TimeOfDay(hour: 13, minute: 0)),
        '',
      );
    });

    test('date only → date sentence, no time', () {
      final dayMonth = formatDayMonth(date, locale);
      final sentence = neededBySentence(l10n, locale, date, null);
      expect(sentence, l10n.supplierMessageNeededBy(dayMonth));
      expect(sentence.contains('13:00'), isFalse);
    });

    test('date + time → date-and-time sentence carrying the 24h time', () {
      final dayMonth = formatDayMonth(date, locale);
      final sentence = neededBySentence(
        l10n,
        locale,
        date,
        const TimeOfDay(hour: 13, minute: 0),
      );
      // Spec 016 §5.4: the displayed time carries the hour mark ("13:00h").
      expect(sentence, l10n.supplierMessageNeededByWithTime(dayMonth, '13:00h'));
      expect(sentence.contains('13:00h'), isTrue);
      // The with-time sentence is distinct from the date-only one.
      expect(sentence, isNot(neededBySentence(l10n, locale, date, null)));
    });
  });
}
