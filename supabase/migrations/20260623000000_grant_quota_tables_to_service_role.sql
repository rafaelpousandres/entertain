-- Fix: the dish-assistant and stock-photos Edge Functions read the effective
-- monthly limit straight from public.quota_entitlements with the SERVICE ROLE,
-- to pass it to consume_quota. But the Spec 019 migration granted SELECT on the
-- quota tables only to anon/authenticated (the client read side) — never to
-- service_role. The service role has BYPASSRLS but Postgres still checks table
-- privileges first, so that read failed with "permission denied for table
-- quota_entitlements"; the function silently fell back to the system default
-- (3 / 10) and rejected callers who actually had a higher entitlement (e.g. a
-- 1000 row) with a false "limit reached" (same lesson as media/translations).
--
-- Grant the service role SELECT on both quota tables. quota_usage is included
-- for parity / future direct reads (today it is only touched via the SECURITY
-- DEFINER consume_quota/release_quota RPCs, which already work). Read-only:
-- writes still go solely through those RPCs, so the paywall-trust property
-- (clients cannot reset their own usage) is unchanged. Additive.
grant select on table public.quota_entitlements to service_role;
grant select on table public.quota_usage        to service_role;
