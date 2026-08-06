import 'package:entertain/features/stock_photos/data/quota.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec 019 §D.2 — entitlement/quota math (pure, no Supabase).
void main() {
  group('QuotaStatus', () {
    test('used < limit → not exhausted, remaining is the gap', () {
      const q = QuotaStatus(used: 3, limit: 10);
      expect(q.isExhausted, isFalse);
      expect(q.remaining, 7);
    });

    test('used == limit → exhausted, remaining 0', () {
      const q = QuotaStatus(used: 10, limit: 10);
      expect(q.isExhausted, isTrue);
      expect(q.remaining, 0);
    });

    test('used > limit (e.g. limit lowered later) → remaining clamps to 0', () {
      const q = QuotaStatus(used: 12, limit: 10);
      expect(q.isExhausted, isTrue);
      expect(q.remaining, 0);
    });
  });

  // No default-limit or period tests: the client no longer holds a limit
  // value or computes periods — `get_quota_status` resolves both server-side.
  test('quota key namespaces this consumer', () {
    expect(kStockPhotosQuotaKey, 'stock_photos');
  });
}
