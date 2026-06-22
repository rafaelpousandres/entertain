import 'package:entertain/features/ai_dish_assistant/data/dish_assistant.dart';
import 'package:entertain/features/stock_photos/data/quota.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 020 §8 — dish_assistant quota math (the generic Spec 019 quota reused
/// with a new key). Pure, no Supabase.
void main() {
  test('system default limit is 3 (mirror of the Edge Function constant)', () {
    expect(kDishAssistantDefaultLimit, 3);
  });

  test('quota key namespaces this consumer', () {
    expect(kDishAssistantQuotaKey, 'dish_assistant');
  });

  group('QuotaStatus for dish_assistant', () {
    test('free tier: 1 used of 3 → 2 remaining, not exhausted', () {
      const q = QuotaStatus(used: 1, limit: 3);
      expect(q.remaining, 2);
      expect(q.isExhausted, isFalse);
    });

    test('used == limit → exhausted, remaining 0', () {
      const q = QuotaStatus(used: 3, limit: 3);
      expect(q.isExhausted, isTrue);
      expect(q.remaining, 0);
    });

    test('premium entitlement (50) reuses the same value object', () {
      const q = QuotaStatus(used: 10, limit: 50);
      expect(q.remaining, 40);
      expect(q.isExhausted, isFalse);
    });
  });
}
