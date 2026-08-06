-- Quota limits become server-resolved configuration (design approved 2026-08-06).
--
-- Closes the mirrored-constant defect: the per-key default limit lived as a
-- hardcoded pair (Edge Function DEFAULT_LIMIT + client k*DefaultLimit "MUST
-- match" mirror), so changing an operational parameter required a redeploy AND
-- an app release. After this migration the resolution chain lives in ONE place
-- (`effective_quota_limit`): group entitlement > `quota_defaults` row > NULL
-- (fail closed — callers treat NULL as a loud configuration error, never a
-- silent fallback). `get_quota_status` gives clients the resolved (used, limit)
-- pair in one call and computes the period itself, so the client no longer
-- duplicates the period definition either.
--
-- Entirely additive: one table (seeded), two functions, grants. Existing
-- tables, RPCs, policies and grants are untouched — apps in the field keep
-- working on their old read path.

-- 1. quota_defaults — the global per-key default limit ---------------------
-- One row per quota_key. Operational changes ("raise dish_assistant to 20 for
-- everyone") are an UPDATE here: immediate, deploy-free, reversible. Group
-- entitlements (Spec 019) still override per group — that stays the premium
-- seam.
create table public.quota_defaults (
  quota_key     text primary key,
  monthly_limit integer not null check (monthly_limit >= 0),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create trigger trg_quota_defaults_updated_at
  before update on public.quota_defaults
  for each row execute function public.set_updated_at();

-- Canonical free-tier values. Temporary operational overrides do NOT belong
-- here — they go in separate, clearly-labelled operational migrations (see
-- 20260806000100) or the Studio SQL editor; this migration carries structure
-- and canonical state only.
insert into public.quota_defaults (quota_key, monthly_limit) values
  ('dish_assistant', 3),
  ('menu_wizard', 2),
  ('stock_photos', 10);

alter table public.quota_defaults enable row level security;
-- Default limits are not sensitive; any signed-in client may read them.
create policy quota_defaults_select on public.quota_defaults
  for select to authenticated using (true);
-- SELECT only for clients (same paywall-trust model as quota_usage: no DML
-- grant means a client write dies at the privilege check, before RLS).
grant select on table public.quota_defaults to anon, authenticated;
-- Non-negotiable house rule: every table a service-role Edge Function reads
-- gets its service_role grant in the table's initial migration.
grant select on table public.quota_defaults to service_role;

-- 2. effective_quota_limit — THE resolution chain, used by both sides ------
-- entitlement (per group) > quota_defaults (global) > NULL. NULL only happens
-- if a seed row was deleted; callers must fail closed and loudly on it.
-- SECURITY DEFINER so the same function serves the client-facing RPC below
-- regardless of the caller's row visibility; it leaks nothing beyond what
-- members may already SELECT.
create or replace function public.effective_quota_limit(
  p_group_id uuid,
  p_quota_key text
) returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select e.monthly_limit from public.quota_entitlements e
      where e.group_id = p_group_id and e.quota_key = p_quota_key),
    (select d.monthly_limit from public.quota_defaults d
      where d.quota_key = p_quota_key)
  );
$$;
revoke all on function public.effective_quota_limit(uuid, text) from public;
grant execute on function public.effective_quota_limit(uuid, text)
  to service_role;

-- 3. get_quota_status — client read path: (used, limit) resolved server-side.
-- Computes the period internally (calendar month, UTC) so the period
-- definition has exactly one home. Guarded by is_group_member: SECURITY
-- DEFINER must not let a stranger probe another group's usage.
create or replace function public.get_quota_status(
  p_group_id uuid,
  p_quota_key text
) returns table (used integer, quota_limit integer)
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(
      (select u.used from public.quota_usage u
        where u.group_id = p_group_id
          and u.quota_key = p_quota_key
          and u.period = to_char(now() at time zone 'utc', 'YYYY-MM')),
      0
    ) as used,
    public.effective_quota_limit(p_group_id, p_quota_key) as quota_limit
  where public.is_group_member(p_group_id);
$$;
revoke all on function public.get_quota_status(uuid, text) from public;
grant execute on function public.get_quota_status(uuid, text)
  to anon, authenticated, service_role;
