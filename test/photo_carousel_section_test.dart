import 'package:entertain/features/photos/data/media.dart';
import 'package:entertain/features/photos/data/media_providers.dart';
import 'package:entertain/features/photos/widgets/photo_carousel_section.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 010 §2.3 / Spec 009 Fixes §6 — the reusable photo carousel must never
/// strand the user on a spinner or a "couldn't load the photo" error: an empty
/// carousel and a failed read both show the add-photo placeholder so the first
/// photo can always be added. Exercised here for a dish (the same widget serves
/// all three entity types).
void main() {
  const target = (type: MediaEntityType.dish, entityId: 'dish-1');

  Future<void> pumpSection(
    WidgetTester tester, {
    required Future<List<Media>> Function() media,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entityMediaProvider(target).overrideWith((ref) => media()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(
            body: PhotoCarouselSection(
              type: MediaEntityType.dish,
              entityId: 'dish-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'empty carousel shows the add-photo placeholder, not an error or spinner',
    (tester) async {
      await pumpSection(tester, media: () async => []);

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
        media: () async => throw Exception('permission denied for media'),
      );

      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(en.photoLoadError), findsNothing);
    },
  );
}
