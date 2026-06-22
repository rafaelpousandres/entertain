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

  test('system default limit is 10 (mirror of the Edge Function constant)', () {
    expect(kStockPhotosDefaultLimit, 10);
  });

  group('currentPeriodUtc', () {
    test('formats YYYY-MM, zero-padded month', () {
      expect(currentPeriodUtc(DateTime.utc(2026, 6, 22)), '2026-06');
      expect(currentPeriodUtc(DateTime.utc(2026, 12, 1)), '2026-12');
    });

    test('uses UTC: a late-night local instant maps to the UTC month', () {
      // 2026-06-30 23:30 UTC is still June in UTC.
      expect(currentPeriodUtc(DateTime.utc(2026, 6, 30, 23, 30)), '2026-06');
    });

    test('a new month resets the period key', () {
      expect(currentPeriodUtc(DateTime.utc(2026, 6, 30)), '2026-06');
      expect(currentPeriodUtc(DateTime.utc(2026, 7, 1)), '2026-07');
    });
  });
}
