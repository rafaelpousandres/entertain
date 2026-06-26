/// Spec 022 §4 — client-side quota constants for the AI menu wizard.
///
/// The quota itself is enforced server-side (the `menu-wizard` Edge Function +
/// the generic Spec 019 `quota_usage`/`quota_entitlements` tables and the atomic
/// `consume_quota` RPC). This is just the read side: the namespacing key and the
/// system default. [QuotaStatus] and [currentPeriodUtc] are reused from the
/// stock-photos quota (the same generic infra), not duplicated.
library;

/// The quota key for the menu wizard — the third consumer of the generic Spec
/// 019 quota (after `stock_photos`, `dish_assistant`).
const String kMenuWizardQuotaKey = 'menu_wizard';

/// System default monthly limit when a group has no `quota_entitlements` row.
/// MUST match `DEFAULT_LIMIT` in supabase/functions/menu-wizard/index.ts.
/// Free 2/month; premium (15) is an entitlement row, no code change.
const int kMenuWizardDefaultLimit = 2;
