import 'package:entertain/features/photos/data/media.dart';
import 'package:entertain/features/photos/data/media_providers.dart';
import 'package:entertain/features/photos/data/photo_storage.dart';
import 'package:entertain/features/photos/widgets/photo_carousel_section.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 034 §C2 — picking up a carousel photo to reorder it shows an immediate
/// "grabbed" state (lift + outline + a haptic tick), before the photo moves.

// A valid 1×1 transparent PNG so Image.memory paints without decode errors.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

const _target = (type: MediaEntityType.dish, entityId: 'dish-1');

Media _photo(String id, int position) => Media(
  id: id,
  entityType: MediaEntityType.dish,
  entityId: 'dish-1',
  path: 'dish-1/$id.jpg',
  position: position,
);

Future<void> _pumpCarousel(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        entityMediaProvider(
          _target,
        ).overrideWith((ref) async => [_photo('a', 0), _photo('b', 1)]),
        photoBytesProvider.overrideWith((ref, arg) async => _png),
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

void main() {
  testWidgets('a long-press pick-up lifts the photo before it moves', (
    tester,
  ) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _pumpCarousel(tester);
    // At rest nothing is lifted.
    expect(find.byType(PhotoDragProxy), findsNothing);

    // Press and hold the first photo, without moving the finger.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ClipRRect).first),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));

    // The grabbed state is on screen although the photo has not moved…
    expect(find.byType(PhotoDragProxy), findsOneWidget);
    // …and it is visibly scaled up.
    final scale = tester.widget<Transform>(
      find.descendant(
        of: find.byType(PhotoDragProxy),
        matching: find.byType(Transform),
      ).first,
    );
    expect(scale.transform.getMaxScaleOnAxis(), greaterThan(1.0));
    // …with a haptic tick confirming the pick-up.
    expect(haptics, contains('HapticFeedbackType.mediumImpact'));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(PhotoDragProxy), findsNothing);
  });

  testWidgets('the proxy is the plain thumbnail before the lift animates in', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: PhotoDragProxy(
            animation: AlwaysStoppedAnimation(0),
            child: SizedBox(width: 96, height: 88),
          ),
        ),
      ),
    );
    final scale = tester.widget<Transform>(
      find.descendant(
        of: find.byType(PhotoDragProxy),
        matching: find.byType(Transform),
      ),
    );
    expect(scale.transform.getMaxScaleOnAxis(), 1.0);
  });
}
