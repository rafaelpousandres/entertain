/// Spec 020 §6 — client-side quota constants for the AI dish assistant.
///
/// The quota itself is enforced server-side (the `dish-assistant` Edge Function
/// + the generic Spec 019 `quota_usage`/`quota_entitlements` tables and the
/// atomic `consume_quota` RPC). This is just the read side: the namespacing key
/// and the system default. [QuotaStatus] and [currentPeriodUtc] are reused from
/// the stock-photos quota (the same generic infra) rather than duplicated.
library;

/// The quota key for the dish assistant — a second consumer of the generic
/// Spec 019 quota, proving the design generalizes beyond stock photos.
const String kDishAssistantQuotaKey = 'dish_assistant';

/// System default monthly limit when a group has no `quota_entitlements` row.
/// MUST match `DEFAULT_LIMIT` in supabase/functions/dish-assistant/index.ts.
/// Free 3/month; premium (50) is an entitlement row, no code change.
const int kDishAssistantDefaultLimit = 3;
