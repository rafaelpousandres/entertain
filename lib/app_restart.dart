import 'package:flutter/widgets.dart';

/// Rebuilds everything below it from scratch on demand.
///
/// Spec 035 §D: after an in-app account deletion the session, every cached
/// provider and every screen belong to an account that no longer exists. The
/// app is anonymous-first, so the right next state is the first-launch one: a
/// fresh `ProviderScope`, whose bootstrap signs in a new anonymous user.
/// Swapping the subtree's key does exactly that, without killing the process.
class AppRestart extends StatefulWidget {
  const AppRestart({super.key, required this.builder});

  /// Builds the app. Called again, under a new key, on every [restart].
  final WidgetBuilder builder;

  /// The nearest [AppRestart], or null when there is none (widget tests).
  static AppRestartState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<AppRestartState>();

  @override
  State<AppRestart> createState() => AppRestartState();
}

class AppRestartState extends State<AppRestart> {
  Key _key = UniqueKey();

  void restart() => setState(() => _key = UniqueKey());

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: Builder(builder: widget.builder));
}
