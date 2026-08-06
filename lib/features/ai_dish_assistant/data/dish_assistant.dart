/// Spec 020 §6 — client-side quota key for the AI dish assistant.
///
/// The quota is enforced server-side (the `dish-assistant` Edge Function + the
/// generic Spec 019 `quota_usage` tables and the atomic `consume_quota` RPC).
/// The client holds no limit value: [QuotaStatus] and [fetchQuotaStatus] (the
/// `get_quota_status` read path, limit resolved server-side) are reused from
/// the stock-photos quota — the same generic infra, not duplicated.
library;

/// The quota key for the dish assistant — a second consumer of the generic
/// Spec 019 quota, proving the design generalizes beyond stock photos.
const String kDishAssistantQuotaKey = 'dish_assistant';
