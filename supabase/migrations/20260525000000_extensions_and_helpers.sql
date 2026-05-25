-- Phase 0 — foundations: required extensions and the shared updated_at
-- trigger. Run before any table migration.

-- pgcrypto provides gen_random_uuid(); a stable choice across Postgres
-- versions and the Supabase default. Wrapped in IF NOT EXISTS so re-applying
-- the migration on a clean DB is safe.
create extension if not exists pgcrypto;

-- Single trigger function reused by every table that carries updated_at.
-- Kept in the public schema so the per-table CREATE TRIGGER statements can
-- reference it without a schema prefix in subsequent migrations.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
