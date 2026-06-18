import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

/// How long the brand logo stays visible after the first frame (Spec 015 §3).
/// The native launch screen shows the same logo before this; the in-app overlay
/// continues it so the logo is visible for a minimum of ~1s, then fades out.
const Duration _splashMinVisible = Duration(seconds: 1);
const Duration _splashFade = Duration(milliseconds: 250);

/// Top-level widget. Riverpod's `ProviderScope` is set up in `main.dart` so
/// this widget can focus on theming, routing, localisation, and the brief
/// post-launch splash overlay (§3).
class EntertainApp extends StatefulWidget {
  const EntertainApp({super.key});

  @override
  State<EntertainApp> createState() => _EntertainAppState();
}

class _EntertainAppState extends State<EntertainApp> {
  // The native splash hands off to the first Flutter frame almost instantly on
  // a fast device; this keeps the logo on screen a moment longer (§3). Two
  // flags: start the fade after the minimum, then drop the overlay from the
  // tree once the fade completes so it never intercepts taps.
  bool _showSplash = true;
  bool _splashGone = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(_splashMinVisible, () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      routerConfig: appRouter,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Stack(
          children: [
            ?child,
            if (!_splashGone)
              IgnorePointer(
                ignoring: !_showSplash,
                child: AnimatedOpacity(
                  opacity: _showSplash ? 1 : 0,
                  duration: _splashFade,
                  onEnd: () {
                    if (!_showSplash && mounted) {
                      setState(() => _splashGone = true);
                    }
                  },
                  child: const _SplashOverlay(),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The brand logo centred on the app background — visually continuous with the
/// native launch screen (same icon, same `#FBF5EA` colour).
///
/// Spec 016 §5.3: the Android 12+ native splash masks its icon to a circle and
/// uses the *padded foreground* artwork. The overlay mirrors that exactly — the
/// same foreground asset, the same circular mask, on the same background — so
/// the native → overlay handover looks like one continuous logo with no jump in
/// artwork, shape, or size.
class _SplashOverlay extends StatelessWidget {
  const _SplashOverlay();

  /// Visible diameter of the splash logo, tuned to match the Android 12 native
  /// splash icon circle.
  static const double _diameter = 180;

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.bg,
      child: Center(
        child: ClipOval(
          child: Image(
            image: AssetImage('assets/icon/entertain - icon foreground.png'),
            width: _diameter,
            height: _diameter,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
