import 'package:entertain/features/ai_menu_wizard/data/menu_wizard.dart';
import 'package:entertain/features/stock_photos/data/quota.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 022 §7 — menu_wizard quota math (the generic Spec 019 quota reused with
/// a third key). Pure, no Supabase.
void main() {
  test('system default limit is 2 (mirror of the Edge Function constant)', () {
    expect(kMenuWizardDefaultLimit, 2);
  });

  test('quota key namespaces this consumer', () {
    expect(kMenuWizardQuotaKey, 'menu_wizard');
  });

  group('QuotaStatus for menu_wizard (free 2)', () {
    test('1 used of 2 → 1 remaining, not exhausted', () {
      const q = QuotaStatus(used: 1, limit: 2);
      expect(q.remaining, 1);
      expect(q.isExhausted, isFalse);
    });

    test('used == limit → exhausted, remaining 0', () {
      const q = QuotaStatus(used: 2, limit: 2);
      expect(q.isExhausted, isTrue);
      expect(q.remaining, 0);
    });

    test('premium entitlement (15) reuses the same value object', () {
      const q = QuotaStatus(used: 4, limit: 15);
      expect(q.remaining, 11);
      expect(q.isExhausted, isFalse);
    });
  });
}
