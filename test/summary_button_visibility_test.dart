import 'package:entertain/features/events/data/event.dart';
import 'package:entertain/features/events/data/events_providers.dart';
import 'package:entertain/features/events/screens/event_detail_screen.dart';
import 'package:entertain/l10n/app_localizations.dart';
import 'package:entertain/features/photos/data/media.dart';
import 'package:entertain/features/photos/data/media_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Release 1.0.30 §2 — "Crea full resum" must be visible WITHOUT scrolling on
/// the Esdeveniment tab, no matter how much the form content grows. The frozen
/// failure: the button used to sit after the last form field, so a two-line
/// title or filled notes pushed it below the fold. It now lives in the
/// persistent bottom action bar; this guard pumps a deliberately long event
/// and asserts the button is on screen with no scroll gesture performed.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// An event bulky enough to overflow the fold in the old layout: a title
  /// that wraps to two lines and notes with real content.
  Event longEvent() => Event(
        id: 'e1',
        groupId: 'g1',
        title: 'Gran dinar d\'estiu a la casa del poble amb tota la família, '
            'els veïns i els amics de sempre',
        type: EventType.lunch,
        format: EventFormat.seated,
        guestCount: 24,
        eventDate: DateTime(2026, 8, 15),
        locationName: 'Casa del poble, plaça Major, 1, segona planta',
        notes: 'Recordar les al·lèrgies de la Júlia i el Pau.\n'
            'Portar cadires plegables extra del garatge.\n'
            'Encarregar el pa el dia abans a la fleca de baix.',
        createdAt: DateTime(2026, 1, 1),
      );

  testWidgets(
      '"Crea full resum" is visible without scrolling on a long event',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        eventByIdProvider.overrideWith((ref, id) async => longEvent()),
        eventReadinessProvider.overrideWith((ref) async => {}),
        entityMediaProvider.overrideWith((ref, target) async => <Media>[]),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // focusEventTab lands directly on the Esdeveniment tab.
        home: EventDetailScreen(eventId: 'e1', focusEventTab: true),
      ),
    ));
    await tester.pumpAndSettle();

    // No scroll has happened; the action must already be tappable…
    final button = find.text(l10n.summaryCreateAction);
    expect(button.hitTestable(), findsOneWidget);

    // …and fully inside the screen, not straddling the fold.
    final screen = tester.getSize(find.byType(MaterialApp));
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(screen.height));
  });
}
