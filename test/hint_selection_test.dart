import 'package:entertain/features/hints/data/hint.dart';
import 'package:entertain/features/hints/data/hint_selection.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 026 A.2/A.4 — pure hint-selection + locale-merge helpers.
void main() {
  const welcome = Hint(id: 'w', key: 'welcome', kind: HintKind.welcome, text: 'Hi');
  const tipA = Hint(id: 'a', key: 'a', kind: HintKind.tip, text: 'A');
  const tipB = Hint(id: 'b', key: 'b', kind: HintKind.tip, text: 'B');
  const hints = [welcome, tipA, tipB];

  group('entryHint', () {
    test('first-ever open shows the welcome hint', () {
      final h = entryHint(hints, welcomeSeen: false, randomIndex: (_) => 0);
      expect(h, welcome);
    });

    test('subsequent opens show a tip (never the welcome)', () {
      final h = entryHint(hints, welcomeSeen: true, randomIndex: (_) => 1);
      expect(h, tipB);
      expect(h!.kind, HintKind.tip);
    });

    test('first-ever open falls back to a tip when there is no welcome', () {
      final h = entryHint(
        const [tipA, tipB],
        welcomeSeen: false,
        randomIndex: (_) => 0,
      );
      expect(h, tipA);
    });

    test('returns null when there is nothing to show', () {
      expect(entryHint(const [], welcomeSeen: true, randomIndex: (_) => 0), isNull);
    });
  });

  group('randomTip', () {
    test('excludes the current key so "Més…" advances', () {
      final h = randomTip(hints, randomIndex: (_) => 0, excludeKey: 'a');
      expect(h, tipB); // only tipB remains in the pool, index 0
    });

    test('falls back to the full pool when excluding the only tip', () {
      final h = randomTip(const [tipA], randomIndex: (_) => 0, excludeKey: 'a');
      expect(h, tipA);
    });

    test('returns null when there are no tips', () {
      expect(randomTip(const [welcome], randomIndex: (_) => 0), isNull);
    });
  });

  group('mergeHintText', () {
    test('uses the app-locale text when present', () {
      expect(mergeHintText({'x': 'Hola'}, {'x': 'Hola-ca'}, 'x'), 'Hola');
    });
    test('falls back to Catalan when the locale is missing', () {
      expect(mergeHintText({}, {'x': 'Hola-ca'}, 'x'), 'Hola-ca');
    });
    test('returns empty when neither has the id', () {
      expect(mergeHintText({}, {}, 'x'), '');
    });
  });
}
