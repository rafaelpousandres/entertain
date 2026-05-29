import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/catalog/data/dish.dart';
import '../features/catalog/screens/dish_catalog_screen.dart';
import '../features/catalog/screens/dish_editor_screen.dart';
import '../features/catalog/screens/ingredient_catalog_screen.dart';
import '../features/catalog/screens/ingredient_editor_screen.dart';
import '../features/catalog/screens/ingredient_line_editor_screen.dart';
import '../features/events/data/event.dart';
import '../features/events/screens/event_detail_screen.dart';
import '../features/events/screens/event_form_screen.dart';
import '../features/events/screens/events_list_screen.dart';
import '../features/shell/home_shell.dart';
import '../features/startup/bootstrap_gate.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Wraps a screen in the startup bootstrap gate so every entry point —
/// including deep links to detail / editor routes — waits for the Supabase
/// session before touching group-scoped data.
Widget _gated(Widget child) => BootstrapGate(child: child);

/// Application router.
///
/// Three co-equal sections (events, dishes, ingredients) live behind a
/// bottom navigation bar via a [StatefulShellRoute]; their list screens are
/// the branch roots. Detail and editor screens are root-navigator routes so
/// they cover the bar and own their action bars (Specification 004 §3.9).
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/events',
  routes: [
    GoRoute(path: '/', redirect: (_, _) => '/events'),

    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _gated(HomeShell(navigationShell: navigationShell)),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/events',
              builder: (context, state) => const EventsListScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dishes',
              builder: (context, state) => const DishCatalogScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/ingredients',
              builder: (context, state) => const IngredientCatalogScreen(),
            ),
          ],
        ),
      ],
    ),

    // Events — detail / create / edit (cover the bottom bar).
    GoRoute(
      path: '/events/new',
      builder: (context, state) => _gated(const EventFormScreen()),
    ),
    GoRoute(
      path: '/events/:id',
      builder: (context, state) =>
          _gated(EventDetailScreen(eventId: state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/events/:id/edit',
      builder: (context, state) {
        final initial = state.extra is Event ? state.extra as Event : null;
        return _gated(
          EventFormScreen(
            eventId: state.pathParameters['id']!,
            initialEvent: initial,
          ),
        );
      },
    ),

    // Dishes — create / edit.
    GoRoute(
      path: '/dishes/new',
      builder: (context, state) => _gated(const DishEditorScreen()),
    ),
    GoRoute(
      path: '/dishes/:id',
      builder: (context, state) =>
          _gated(DishEditorScreen(dishId: state.pathParameters['id']!)),
    ),

    // Ingredients — create / edit.
    GoRoute(
      path: '/ingredients/new',
      builder: (context, state) => _gated(const IngredientEditorScreen()),
    ),
    GoRoute(
      path: '/ingredients/:id',
      builder: (context, state) => _gated(
        IngredientEditorScreen(ingredientId: state.pathParameters['id']!),
      ),
    ),

    // Ingredient line editor — a transient sub-editor of the dish editor.
    // Its own path (not under /dishes/:id) avoids colliding with the dish
    // detail route; `extra` carries the line being edited, null when adding.
    GoRoute(
      path: '/dish-line-editor',
      builder: (context, state) => _gated(
        IngredientLineEditorScreen(
          initialLine: state.extra is DishLineDraft
              ? state.extra as DishLineDraft
              : null,
        ),
      ),
    ),
  ],
);
