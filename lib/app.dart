import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'theme/app_typography.dart';

/// How long the brand logo stays visible after the first frame (Spec 015 §3).
/// The native launch screen shows the same logo before this; the in-app overlay
/// continues it so the logo is visible for a minimum of ~1s, then fades out.
const Duration _splashMinVisible = Duration(seconds: 2);
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
  bool _nativeSplashHandled = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(_splashMinVisible, () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_nativeSplashHandled) {
      _nativeSplashHandled = true;
      _revealWhenReady();
    }
  }

  // Decode the overlay logo before dropping the held native splash, so the
  // in-app overlay can paint the logo on the very first frame it is visible.
  // The native splash (plain cream) stays up until then: the cream is
  // continuous and the logo appears once, with no blank frame in the handover.
  Future<void> _revealWhenReady() async {
    try {
      await precacheImage(_SplashOverlay.logo, context);
    } catch (_) {
      // A precache failure must never strand the app behind the native splash.
    }
    FlutterNativeSplash.remove();
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

  /// The brand mark shown by the overlay. Exposed so the app can `precacheImage`
  /// the exact same provider before revealing the overlay — guaranteeing a
  /// cache hit so the logo paints on its first visible frame.
  static const AssetImage logo = AssetImage(
    'assets/icon/entertain - icon foreground.png',
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The logo stays at the exact centre to match the native splash (a seamless
    // handover, see above); Spec 026 Part B floats the localized slogan below it
    // with an Align, so adding it never shifts the logo's position.
    return ColoredBox(
      color: AppColors.bg,
      child: Stack(
        children: [
          const Center(
            child: ClipOval(
              child: Image(
                image: logo,
                width: _diameter,
                height: _diameter,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.34),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                l10n.splashSlogan,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  // High-contrast ink on the cream splash (was a muted, italic,
                  // yellow-underlined style; the underline came from the Text
                  // sitting outside any Material — pinned off explicitly here).
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.normal,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
