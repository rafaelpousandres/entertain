import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Supabase init + anonymous session run inside `appBootstrapProvider`
  // so the home screen can render the loading / error states the spec
  // calls for, rather than hanging before any UI exists.
  runApp(const ProviderScope(child: EntertainApp()));
}
