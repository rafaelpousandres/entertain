/// Spec 022 §4 — client-side quota key for the AI menu wizard.
///
/// The quota is enforced server-side (the `menu-wizard` Edge Function + the
/// generic Spec 019 `quota_usage` tables and the atomic `consume_quota` RPC).
/// The client holds no limit value: [QuotaStatus] and [fetchQuotaStatus] (the
/// `get_quota_status` read path, limit resolved server-side) are reused from
/// the stock-photos quota — the same generic infra, not duplicated.
library;

/// The quota key for the menu wizard — the third consumer of the generic Spec
/// 019 quota (after `stock_photos`, `dish_assistant`).
const String kMenuWizardQuotaKey = 'menu_wizard';
