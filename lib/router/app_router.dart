import 'package:go_router/go_router.dart';

import '../features/placeholder/placeholder_screen.dart';

/// Application router. Spec 001 only needs a single placeholder route; this
/// file exists so later phases can extend the route table without churning
/// `main.dart`.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const PlaceholderScreen(),
    ),
  ],
);
