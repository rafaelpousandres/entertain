import 'package:entertain/l10n/app_localizations.dart';
import 'package:entertain/ui/dirty_tabs_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 011 §2.5 — the universal tab-switch unsaved-changes guard. Leaving a
/// dirty tab prompts the "Unsaved changes" dialog: Discard switches and clears
/// the dirty state; Cancel stays put.

class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(length: 2, vsync: this);
  bool _tab0Dirty = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            controller: _controller,
            tabs: const [
              Tab(text: 'One'),
              Tab(text: 'Two'),
            ],
          ),
        ),
        body: DirtyTabsGuard(
          controller: _controller,
          isTabDirty: (index) => index == 0 && _tab0Dirty,
          onConfirmDiscard: (_) => _tab0Dirty = false,
          child: TabBarView(
            controller: _controller,
            children: const [
              Center(child: Text('Body one')),
              Center(child: Text('Body two')),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  Future<AppLocalizations> en() =>
      AppLocalizations.delegate.load(const Locale('en'));

  testWidgets(
    'switching away from a dirty tab prompts the dialog (criterion 9)',
    (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();

      final l10n = await en();
      expect(find.text(l10n.unsavedChangesTitle), findsOneWidget);
    },
  );

  testWidgets('Cancel keeps the user on the current tab (criterion 11)', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    await tester.pumpAndSettle();
    final l10n = await en();

    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.cancelAction));
    await tester.pumpAndSettle();

    // Still on tab one.
    expect(find.text('Body one'), findsOneWidget);
    expect(find.text(l10n.unsavedChangesTitle), findsNothing);
  });

  testWidgets(
    'Discard switches the tab and clears the dirty state (criterion 10)',
    (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.pumpAndSettle();
      final l10n = await en();

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.discardChangesAction));
      await tester.pumpAndSettle();

      // Switched to tab two; the dialog is gone.
      expect(find.text('Body two'), findsOneWidget);
      expect(find.text(l10n.unsavedChangesTitle), findsNothing);

      // Dirty state cleared, so a later switch back and forth no longer prompts.
      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.unsavedChangesTitle), findsNothing);
    },
  );
}
