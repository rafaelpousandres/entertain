-- Phase 0 — table, schema, and type privileges (GRANT) for the API roles.
--
-- RLS (migration ...0700) decides which *rows* a caller may touch, but
-- Postgres checks the traditional table privileges first and rejects the
-- request — "permission denied for table ..." — before any policy is
-- evaluated when those privileges are missing. Supabase relies on BOTH
-- layers. The Spec 002 migrations created the RLS policies but not the
-- matching GRANTs, so anon/authenticated were denied at the privilege check
-- (the Spec 002 connectivity test only exercised anonymous sign-in, a
-- different endpoint that never touches these tables, so it went unnoticed).
--
-- Principle (data model §4, applied uniformly here):
--   * anon + authenticated may SELECT/INSERT/UPDATE/DELETE on the user-data
--     tables — RLS already restricts which rows each role actually sees or
--     writes (anon has no write policies, so its writes are still denied by
--     RLS; the grant just stops the request failing before RLS runs).
--   * anon + authenticated may only SELECT the system-content tables.
--   * Nothing is granted on later-phase tables (none exist yet in Phase 0).
--
-- No GRANT on sequences is needed: every primary key defaults to
-- gen_random_uuid(), so Phase 0 defines no sequences at all.

-- Schema usage -----------------------------------------------------------
-- Required to reference anything inside the schema. Granted explicitly so a
-- from-scratch `supabase db reset` reproduces the full privilege set
-- independently of any evolving Supabase default.
grant usage on schema public to anon, authenticated;

-- Enum type usage --------------------------------------------------------
-- Columns of these enum types are read and written through the API; using an
-- enum value requires USAGE on its type. Postgres grants type USAGE to PUBLIC
-- by default, but we state it explicitly for reproducibility.
grant usage on type public.profile_locale          to anon, authenticated;
grant usage on type public.membership_role         to anon, authenticated;
grant usage on type public.event_type              to anon, authenticated;
grant usage on type public.event_format            to anon, authenticated;
grant usage on type public.event_status            to anon, authenticated;
grant usage on type public.dish_category           to anon, authenticated;
grant usage on type public.unit_magnitude          to anon, authenticated;
grant usage on type public.order_status            to anon, authenticated;
grant usage on type public.order_item_status       to anon, authenticated;
grant usage on type public.media_owner_type        to anon, authenticated;
grant usage on type public.media_kind              to anon, authenticated;
grant usage on type public.translation_entity_type to anon, authenticated;

-- User-data tables -------------------------------------------------------
-- Full DML; RLS gates the rows. supplier_categories, ingredients, and
-- message_templates also hold system rows (group_id null), but their SELECT
-- policies already expose those, so they belong here rather than below.
grant select, insert, update, delete on table
  public.groups,
  public.profiles,
  public.memberships,
  public.events,
  public.supplier_categories,
  public.ingredients,
  public.dishes,
  public.dish_ingredients,
  public.event_dishes,
  public.event_dish_ingredients,
  public.orders,
  public.order_items,
  public.message_templates,
  public.media
to anon, authenticated;

-- System-content tables (read-only) --------------------------------------
-- Pure system catalogs with only a SELECT policy; users never write them
-- (the service role, which bypasses RLS, seeds and maintains them).
grant select on table
  public.units,
  public.translations
to anon, authenticated;
