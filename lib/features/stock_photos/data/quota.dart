/// Spec 019 §A — client-side quota model + pure helpers.
///
/// The quota itself is enforced server-side (the `stock-photos` Edge Function +
/// `quota_usage`/`quota_entitlements` with the atomic `consume_quota` RPC). This
/// file only mirrors the read side: the period key the client reads the counter
/// for, the default limit, and a small status value object for the UI.
library;

/// The quota key for stock photos (`quota_key` namespaces consumers so the URL
/// importer / AI features reuse the same tables later).
const String kStockPhotosQuotaKey = 'stock_photos';

/// System default monthly limit when a group has no `quota_entitlements` row.
/// MUST match `DEFAULT_LIMIT` in supabase/functions/stock-photos/index.ts — the
/// function is the source of truth for enforcement; this mirror only drives the
/// "N de 10" display before the first save of the month.
const int kStockPhotosDefaultLimit = 10;

/// Calendar month in UTC, e.g. `2026-06` (documented choice: UTC month, no
/// per-group timezone). Matches the Edge Function's `currentPeriod()`.
String currentPeriodUtc([DateTime? now]) {
  final d = (now ?? DateTime.now()).toUtc();
  final mm = d.month.toString().padLeft(2, '0');
  return '${d.year}-$mm';
}

/// A group's stock-photo usage for the current period.
class QuotaStatus {
  const QuotaStatus({required this.used, required this.limit});

  final int used;
  final int limit;

  /// Photos still available this month (never negative).
  int get remaining => used >= limit ? 0 : limit - used;

  /// Whether the cap is reached (the paywall seam).
  bool get isExhausted => used >= limit;
}
