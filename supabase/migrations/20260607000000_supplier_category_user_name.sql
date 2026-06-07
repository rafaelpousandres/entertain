-- Specification 007 (Phase 7A) — user supplier categories carry a name.
--
-- Decision taken with the project owner during 7A: system supplier
-- categories are NOT renamable or deletable from the app. Their display
-- names stay in `translations` (service-role-only writes) untouched, and the
-- shared rows are never mutated from the client. Only user-created categories
-- are fully managed in-app (add / rename / delete + channel & address).
--
-- The data model marks user-created content as monolingual (§5), so a user
-- category's name is a single value rather than a `translations` row — but
-- `supplier_categories` had no column to hold it. Add a nullable `name`:
--
--   * system rows (group_id null): `name` stays NULL; the display name is
--     resolved via `translations` exactly as before.
--   * user rows (group_id set): `name` holds the monolingual display name
--     typed by the user in their current locale.
--
-- The `group_id` column anticipated by the Spec already exists (Phase 0 core
-- migration 20260525000200), so no migration is needed for it.

alter table public.supplier_categories
  add column name text;
