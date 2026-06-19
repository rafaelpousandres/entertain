import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Hold the native splash (a plain cream screen) on screen instead of letting
  // it disappear on the first Flutter frame. The app removes it only once the
  // in-app overlay has precached its logo (lib/app.dart), so the cream stays
  // continuous and the brand logo appears exactly once — no blank handover
  // frame, no double-logo flash.
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  // Supabase init + anonymous session run inside `appBootstrapProvider`
  // so the home screen can render the loading / error states the spec
  // calls for, rather than hanging before any UI exists.
  runApp(const ProviderScope(child: EntertainApp()));
}
