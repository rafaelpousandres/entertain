import 'package:entertain/app_restart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 035 §D — after an account deletion the app starts over. AppRestart
/// must hand the subtree a brand-new ProviderScope, so no provider keeps a
/// value that belonged to the deleted account.
final _counter = NotifierProvider<_Counter, int>(_Counter.new);

class _Counter extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

class _Probe extends ConsumerWidget {
  const _Probe();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      Text('value ${ref.watch(_counter)}'),
      TextButton(
        onPressed: () => ref.read(_counter.notifier).bump(),
        child: const Text('BUMP'),
      ),
      TextButton(
        onPressed: () => AppRestart.maybeOf(context)!.restart(),
        child: const Text('RESTART'),
      ),
    ],
  );
}

void main() {
  testWidgets('restart rebuilds the app with fresh provider state', (
    tester,
  ) async {
    await tester.pumpWidget(
      AppRestart(
        builder: (_) => const ProviderScope(
          child: MaterialApp(home: Scaffold(body: _Probe())),
        ),
      ),
    );
    await tester.tap(find.text('BUMP'));
    await tester.pump();
    expect(find.text('value 1'), findsOneWidget);

    await tester.tap(find.text('RESTART'));
    await tester.pumpAndSettle();
    expect(find.text('value 0'), findsOneWidget);
  });
}
