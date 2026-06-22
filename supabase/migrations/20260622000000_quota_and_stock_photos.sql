-- Specification 019 — entitlement/quota infrastructure + stock-photo provenance.
--
-- The project's first monetization infrastructure: a generic per-group,
-- calendar-month quota (`quota_key` namespaces consumers, so the URL importer
-- and AI features reuse it later with no schema change). Stock photos are the
-- only consumer for now (`quota_key = 'stock_photos'`). Also establishes a
-- latent platform-admin role (no UI) so a future admin/Billing flow has a real
-- authorization anchor, and adds nullable provenance columns to `media`.
--
-- Entirely additive (three tables, two RPCs, one helper, four nullable media
-- columns). Reuses the established idioms: `is_group_member(group_id)` for RLS
-- (...0700_rls.sql), `set_updated_at()` (...0000_extensions...), and the
-- GRANT-then-RLS two-layer model (...1000_grants.sql) — where *omitting* a DML
-- grant is what makes a table client-unwritable. Shown before push per house
-- rule; the destructive-migration stop does not apply.

-- 1. platform_admins — latent platform-admin role (§A.0, no UI) ----------
-- Platform scope (transcends groups); distinct from a future group-admin role.
create table public.platform_admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.platform_admins enable row level security;

-- A row's existence *is* the admin check. SECURITY DEFINER so the policy can
-- read the table while the table itself is locked down to clients.
create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.platform_admins where user_id = auth.uid()
  );
$$;
revoke all on function public.is_platform_admin() from public;
grant execute on function public.is_platform_admin() to anon, authenticated;

-- Self-referential: you may read this table only if you are in it.
create policy platform_admins_self_read on public.platform_admins
  for select to authenticated using (public.is_platform_admin());
-- SELECT-only grant; no client write path. Seeded out of band with the owner's
-- id by the service role (RLS still allows SELECT only to admins).
grant select on table public.platform_admins to anon, authenticated;

-- 2. quota_usage — the counter, one row per (group, key, month) ----------
create table public.quota_usage (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references public.groups(id) on delete cascade,
  quota_key  text not null,
  period     text not null,                  -- calendar month 'YYYY-MM' (UTC)
  used       integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (group_id, quota_key, period)
);
create index quota_usage_group_idx
  on public.quota_usage (group_id, quota_key, period);
create trigger trg_quota_usage_updated_at
  before update on public.quota_usage
  for each row execute function public.set_updated_at();

alter table public.quota_usage enable row level security;
-- Group members may READ the counter (to show "N left this month").
create policy quota_usage_select on public.quota_usage
  for select to authenticated using (public.is_group_member(group_id));
-- CRITICAL (paywall trust): SELECT only. With no insert/update/delete grant a
-- client's write is rejected at the privilege check before RLS even runs, so it
-- cannot reset or decrement its own usage. Only the Edge Function (service
-- role, via the RPCs below) writes this table.
grant select on table public.quota_usage to anon, authenticated;

-- 3. quota_entitlements — per-group limit + tier override ----------------
-- No row for a (group, key) ⇒ the system default applies (stock_photos = 10,
-- a constant in the Edge Function / client). Premium later = insert/raise a row.
create table public.quota_entitlements (
  id            uuid primary key default gen_random_uuid(),
  group_id      uuid not null references public.groups(id) on delete cascade,
  quota_key     text not null,
  monthly_limit integer not null,
  tier          text not null default 'free',  -- 'free' | 'premium' (informational)
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (group_id, quota_key)
);
create trigger trg_quota_entitlements_updated_at
  before update on public.quota_entitlements
  for each row execute function public.set_updated_at();

alter table public.quota_entitlements enable row level security;
create policy quota_entitlements_select on public.quota_entitlements
  for select to authenticated using (public.is_group_member(group_id));
-- SELECT only; writes via the service role later (Billing).
grant select on table public.quota_entitlements to anon, authenticated;

-- 4. Atomic guarded counter (service-role-only RPCs) ---------------------
-- consume_quota fuses the limit check with the increment in ONE statement so
-- two concurrent saves can never both pass at used = limit-1: the conflicting
-- unique row is locked by the UPDATE, and the WHERE guard blocks the increment
-- at the cap. Returns the new `used`, or NULL when the cap is reached (no row
-- updated ⇒ no RETURNING row). The Edge Function reserves a slot with this
-- *before* doing the download/upload, and refunds it with release_quota if the
-- save fails — so quota is charged only for a successful save.
create or replace function public.consume_quota(
  p_group_id uuid,
  p_quota_key text,
  p_period text,
  p_limit integer
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_used integer;
begin
  if p_limit < 1 then
    return null;                                  -- also guards the fresh-insert path
  end if;
  insert into public.quota_usage (group_id, quota_key, period, used)
  values (p_group_id, p_quota_key, p_period, 1)
  on conflict (group_id, quota_key, period)
  do update set used = public.quota_usage.used + 1
  where public.quota_usage.used < p_limit
  returning used into v_used;
  return v_used;                                  -- NULL ⇒ cap reached (blocked)
end;
$$;

create or replace function public.release_quota(
  p_group_id uuid,
  p_quota_key text,
  p_period text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.quota_usage set used = greatest(used - 1, 0)
  where group_id = p_group_id
    and quota_key = p_quota_key
    and period = p_period;
end;
$$;

revoke all on function public.consume_quota(uuid, text, text, integer) from public;
revoke all on function public.release_quota(uuid, text, text) from public;
grant execute on function public.consume_quota(uuid, text, text, integer) to service_role;
grant execute on function public.release_quota(uuid, text, text) to service_role;

-- 5. media provenance (§C.2) — additive, nullable ------------------------
-- Set only for stock photos (by the Edge Function). Camera/gallery photos leave
-- these null. The existing `media` GRANT already covers the new columns, and
-- the storage.objects RLS is path-based (unchanged).
alter table public.media
  add column source_provider text,   -- e.g. 'pexels'
  add column source_author   text,   -- photographer
  add column source_url      text,   -- the provider's photo page
  add column source_ref      text;   -- provider photo id
