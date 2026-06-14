import 'package:flutter/material.dart';

import 'edit_scaffold.dart';

/// Spec 011 §2.5 — the universal tab-switch unsaved-changes guard.
///
/// `PopScope` guards the back button but not switches between tabs that share a
/// route, so a user could edit a field in one tab, switch to another, and lose
/// the changes silently. This widget watches a [TabController] and, when the
/// user tries to leave a tab that reports dirty, snaps back to it and shows the
/// same "Unsaved changes" dialog used for the back button
/// ([showUnsavedChangesDialog]):
///
///   * **Discard** → [onConfirmDiscard] is called for the tab being left (clear
///     its dirty state), then the switch completes.
///   * **Cancel** → the user stays on the current tab.
///
/// It wraps the part of the subtree that should own the dialog's [BuildContext]
/// (typically the body / `TabBarView`) and renders [child] unchanged; the
/// [TabBar] itself may live anywhere that shares the same [controller] (in this
/// app it sits in the `AppBar.bottom`).
class DirtyTabsGuard extends StatefulWidget {
  const DirtyTabsGuard({
    super.key,
    required this.controller,
    required this.isTabDirty,
    required this.onConfirmDiscard,
    required this.child,
  });

  final TabController controller;

  /// Whether the tab at [index] currently has unsaved changes.
  final bool Function(int index) isTabDirty;

  /// Clears the dirty state of the tab being left, after the user confirms
  /// Discard. The argument is the index of the tab left behind.
  final void Function(int leftIndex) onConfirmDiscard;

  final Widget child;

  @override
  State<DirtyTabsGuard> createState() => _DirtyTabsGuardState();
}

class _DirtyTabsGuardState extends State<DirtyTabsGuard> {
  /// True while we are programmatically moving the controller (snap-back or the
  /// confirmed switch), so our own writes don't re-trigger the guard.
  bool _suppress = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTabChange);
  }

  @override
  void didUpdateWidget(DirtyTabsGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTabChange);
      widget.controller.addListener(_onTabChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChange);
    super.dispose();
  }

  void _onTabChange() {
    final c = widget.controller;
    if (_suppress || !c.indexIsChanging) return;
    final from = c.previousIndex;
    final to = c.index;
    if (from == to || !widget.isTabDirty(from)) return;
    _guard(from, to);
  }

  Future<void> _guard(int from, int to) async {
    // Snap back to the dirty tab so it stays visible behind the dialog.
    _suppress = true;
    widget.controller.index = from;
    _suppress = false;

    final discard = await showUnsavedChangesDialog(context);
    if (!mounted) return;
    if (discard) {
      widget.onConfirmDiscard(from);
      _suppress = true;
      widget.controller.index = to;
      _suppress = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
