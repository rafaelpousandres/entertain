-- Fix: the dish-assistant Edge Function reads the unit catalog and the supplier
-- category catalog with the SERVICE ROLE — at generate (loadUnits /
-- loadSupplierCategories, to give Claude the catalogs as context) and at save
-- (persistDish resolves unit_code -> unit_id and needs a fallback unit). But
-- public.units and public.supplier_categories were granted only to
-- anon/authenticated (units is read-only system content; supplier_categories is
-- user-data DML) — never to service_role. The service role has BYPASSRLS but
-- Postgres checks table privileges first, so those reads failed with
-- "permission denied". An empty unit catalog is non-fatal at generate (Claude
-- still emits codes) but persistDish then finds no units at all and throws
-- "no_units" — save fails. (Same lesson as media / translations / quota_*.)
--
-- Grant the service role SELECT on both. Read-only: writes are unaffected. This
-- is the same gap the Spec 019/020 grants left open for these two tables.
-- Additive.
grant select on table public.units               to service_role;
grant select on table public.supplier_categories to service_role;
