import 'dart:typed_data';

import 'package:entertain/features/photos/data/media.dart';
import 'package:entertain/features/photos/data/media_providers.dart';
import 'package:entertain/features/photos/data/photo_edit_session.dart';
import 'package:entertain/features/photos/data/photo_storage.dart';
import 'package:entertain/features/photos/widgets/photo_carousel_section.dart';
import 'package:entertain/features/photos/widgets/photo_image.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 030 §B — in create mode the carousel renders the editor session's
/// staged photos (read from the registry, served out of the staging bucket),
/// not the `media` rows of an entity that does not exist yet.

// A valid 1×1 transparent PNG so Image.memory paints without decode errors.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  testWidgets('create mode renders the staged photos and the add tile', (
    tester,
  ) async {
    final registry = PhotoEditRegistry();
    final session = PhotoEditSession(
      type: MediaEntityType.dish,
      entityId: 'dish-new',
      creating: true,
    )
      ..addStaged('group-1/a.jpg')
      ..addStaged('group-1/b.jpg');
    registry.register(session);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoEditRegistryProvider.overrideWithValue(registry),
          // Serve any (bucket, path) as the dummy PNG so thumbnails paint.
          photoBytesProvider.overrideWith((ref, arg) async => _png),
          // If create mode wrongly read this, the test would still pass the add
          // tile check — so we also assert the staged thumbnails below.
          entityMediaProvider((
            type: MediaEntityType.dish,
            entityId: 'dish-new',
          )).overrideWith((ref) async => <Media>[]),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(
            body: PhotoCarouselSection(
              type: MediaEntityType.dish,
              entityId: 'dish-new',
              creating: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Two staged thumbnails (from the session) plus the pinned add tile.
    expect(find.byType(PhotoBytesImage), findsNWidgets(2));
    expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
  });

  testWidgets('create mode with no staged photos shows only the add tile', (
    tester,
  ) async {
    final registry = PhotoEditRegistry();
    registry.register(
      PhotoEditSession(
        type: MediaEntityType.dish,
        entityId: 'dish-new',
        creating: true,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoEditRegistryProvider.overrideWithValue(registry),
          photoBytesProvider.overrideWith((ref, arg) async => _png),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(
            body: PhotoCarouselSection(
              type: MediaEntityType.dish,
              entityId: 'dish-new',
              creating: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PhotoBytesImage), findsNothing);
    expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
  });
}
