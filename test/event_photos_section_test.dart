import 'package:entertain/features/events/data/events_providers.dart';
import 'package:entertain/features/events/widgets/event_photos_section.dart';
import 'package:entertain/features/photos/data/event_photo.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 009 Fixes §6 — the event photos section must never strand the user on a
/// spinner or a "couldn't load the photo" error: an empty album and a failed
/// read both show the add-photo placeholder so the first photo can always be
/// added.
void main() {
  const eventId = 'event-1';

  Future<void> pumpSection(
    WidgetTester tester, {
    required Future<List<EventPhoto>> Function() photos,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventPhotosProvider(eventId).overrideWith((ref) => photos()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(
            body: EventPhotosSection(eventId: eventId),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'empty album shows the add-photo placeholder, not an error or spinner',
    (tester) async {
      await pumpSection(tester, photos: () async => []);

      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(en.photoLoadError), findsNothing);
    },
  );

  testWidgets(
    'a failed read degrades to the add-photo placeholder (the §6 bug repro)',
    (tester) async {
      await pumpSection(
        tester,
        photos: () async =>
            throw Exception('permission denied for event_photos'),
      );

      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(en.photoLoadError), findsNothing);
    },
  );
}
