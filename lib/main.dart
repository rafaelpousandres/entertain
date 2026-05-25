import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/supabase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Spec 002 §2.4: initialise Supabase at startup. The call is a no-op
  // when no credentials were provided at build time, leaving the rest of
  // the app to behave exactly as it did in spec 001.
  await initSupabase();

  runApp(const ProviderScope(child: EntertainApp()));
}
