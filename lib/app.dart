import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Top-level widget. Riverpod's `ProviderScope` is set up in `main.dart` so
/// this widget can stay a plain `StatelessWidget` and focus on theming,
/// routing and localisation.
class EntertainApp extends StatelessWidget {
  const EntertainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      routerConfig: appRouter,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
    );
  }
}
