import 'package:go_router/go_router.dart';

import '../features/events/data/event.dart';
import '../features/events/screens/event_detail_screen.dart';
import '../features/events/screens/event_form_screen.dart';
import '../features/events/screens/events_list_screen.dart';
import '../features/startup/bootstrap_gate.dart';

/// Application router.
///
/// Routes mirror the screen-group taxonomy from the spec — the home is
/// the Events list, with create / edit / detail hanging off it. Later
/// groups (dishes, settings) extend this without touching `main.dart`.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) =>
          const BootstrapGate(child: EventsListScreen()),
      routes: [
        GoRoute(
          path: 'events/new',
          builder: (context, state) => const EventFormScreen(),
        ),
        GoRoute(
          path: 'events/:id',
          builder: (context, state) =>
              EventDetailScreen(eventId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: 'events/:id/edit',
          builder: (context, state) {
            final initial = state.extra is Event ? state.extra as Event : null;
            return EventFormScreen(
              eventId: state.pathParameters['id']!,
              initialEvent: initial,
            );
          },
        ),
      ],
    ),
  ],
);
