-- Specification 010 §2.4 — polymorphic `media` table (Wave 1: create + RLS +
-- GRANT + triggers; backfill in the following migrations).
--
-- §2.3 promotes dishes and ingredients to multi-photo carousels, so the Spec
-- 009 hybrid (a per-event `event_photos` table plus single `photo_path` columns
-- on dishes/ingredients) no longer fits. This table unifies all photo storage
-- across the three entity types behind a polymorphic (entity_type, entity_id)
-- key.
--
-- NOTE on enums: the Phase 0 schema already shipped an unused `media_owner_type`
-- (7 owner kinds) for the originally-envisaged richer media model. Spec 010
-- deliberately introduces a leaner, purpose-built `media_entity_type` for the
-- three entities photos actually attach to today, matching the spec's schema.
-- The old `media_owner_type` / `media_kind` enums remain unused and harmless.
--
-- Storage: the existing buckets (`event-photos`, `dish-photos`,
-- `ingredient-photos`) and their object paths are kept as-is — `media.path`
-- just references them. The bucket is implied by `entity_type`. New uploads use
-- the same buckets under `{entity_id}/{photo_id}.jpg` (the storage policies are
-- widened in 20260613070000 to accept both that and the legacy flat
-- `{entity_id}.jpg` form). No blobs are moved (Spec §2.4 decision).
--
-- Wave 2 (a later spec, after one validated release cycle) drops the old
-- structures (`event_photos`, the `photo_path` columns). They stay in the DB
-- for now but are no longer touched by the app.

-- Replace the unused Phase 0 `media` table. The original cross-cutting
-- migration (20260525000600) created a `media` table for the originally-
-- envisaged richer model (group_id, owner_type over 7 kinds, kind photo/video,
-- storage_path, caption, sort_order), but it was never used — Spec 009 shipped
-- photos through the per-entity hybrid instead, so this table has always been
-- empty. Spec 010 repurposes the `media` name for the lean, photo-focused table
-- below. Guarded: abort loudly if the old table somehow holds rows, so we never
-- silently drop real data.
do $$
begin
  if to_regclass('public.media') is not null
     and exists (select 1 from public.media) then
    raise exception
      'public.media is not empty; review before Spec 010 replaces it';
  end if;
end $$;

drop table if exists public.media;

create type public.media_entity_type as enum ('event', 'dish', 'ingredient');
grant usage on type public.media_entity_type to anon, authenticated;

create table public.media (
  id          uuid primary key default gen_random_uuid(),
  entity_type public.media_entity_type not null,
  entity_id   uuid not null,
  path        text not null,             -- relative object path within the bucket
  position    integer not null default 0, -- ordering within the carousel
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index media_entity_idx on public.media (entity_type, entity_id, position);

create trigger trg_media_updated_at
  before update on public.media
  for each row execute function public.set_updated_at();

-- Row-level security ------------------------------------------------------
-- A media row is accessible to members of the owning entity's group. There is
-- no native FK to join through, so the group is reached per entity_type. Uses
-- the shared is_group_member() helper, consistent with the rest of the schema.
alter table public.media enable row level security;

create policy media_group_access on public.media
  for all to authenticated
  using (
    case entity_type
      when 'event' then exists (
        select 1 from public.events e
        where e.id = media.entity_id and public.is_group_member(e.group_id)
      )
      when 'dish' then exists (
        select 1 from public.dishes d
        where d.id = media.entity_id and public.is_group_member(d.group_id)
      )
      when 'ingredient' then exists (
        select 1 from public.ingredients i
        where i.id = media.entity_id and public.is_group_member(i.group_id)
      )
    end
  )
  with check (
    case entity_type
      when 'event' then exists (
        select 1 from public.events e
        where e.id = media.entity_id and public.is_group_member(e.group_id)
      )
      when 'dish' then exists (
        select 1 from public.dishes d
        where d.id = media.entity_id and public.is_group_member(d.group_id)
      )
      when 'ingredient' then exists (
        select 1 from public.ingredients i
        where i.id = media.entity_id and public.is_group_member(i.group_id)
      )
    end
  );

-- GRANT (Spec 009 lesson): Postgres checks table privileges *before* RLS, so a
-- missing GRANT surfaces as "permission denied for table media" before any
-- policy runs. Grant full DML to anon + authenticated; RLS (above) decides
-- which rows each caller may actually touch. The anonymous app user signs in as
-- `authenticated`, so the policy covers it; `anon` has the grant but no policy,
-- so its writes are still denied by RLS — matching the rest of the schema.
grant select, insert, update, delete on table public.media
  to anon, authenticated;

-- Referential integrity (polymorphic) ------------------------------------
-- Postgres has no polymorphic FK, so a BEFORE INSERT/UPDATE trigger validates
-- that entity_id references an existing row in the table named by entity_type.
-- security definer so the existence check is authoritative regardless of the
-- caller's RLS view; cross-group inserts are still blocked by the RLS WITH
-- CHECK above (this only enforces existence, not ownership).
create or replace function public.media_validate_entity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (
    case new.entity_type
      when 'event' then exists (select 1 from public.events where id = new.entity_id)
      when 'dish' then exists (select 1 from public.dishes where id = new.entity_id)
      when 'ingredient' then exists (select 1 from public.ingredients where id = new.entity_id)
    end
  ) then
    raise exception 'media.entity_id % does not reference an existing %',
      new.entity_id, new.entity_type;
  end if;
  return new;
end;
$$;

create trigger trg_media_validate_entity
  before insert or update on public.media
  for each row execute function public.media_validate_entity();

-- Cleanup on entity delete -----------------------------------------------
-- AFTER DELETE on each parent table removes its orphaned media rows. The
-- entity type is passed as a trigger argument. NOTE: events, dishes and
-- ingredients are *soft*-deleted by the app (they set `deleted_at`), so these
-- triggers fire only on a genuine hard DELETE — they are a safety net for SQL
-- maintenance / cascades, not the normal path. The app deletes media rows
-- explicitly when it soft-deletes an entity (mirroring how it handled
-- event_photos in Spec 009). Storage blobs are reclaimed app-side (non-fatal
-- orphan sweep), unchanged.
create or replace function public.media_cleanup_for_entity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.media
  where entity_type = tg_argv[0]::public.media_entity_type
    and entity_id = old.id;
  return old;
end;
$$;

create trigger trg_media_cleanup_events
  after delete on public.events
  for each row execute function public.media_cleanup_for_entity('event');

create trigger trg_media_cleanup_dishes
  after delete on public.dishes
  for each row execute function public.media_cleanup_for_entity('dish');

create trigger trg_media_cleanup_ingredients
  after delete on public.ingredients
  for each row execute function public.media_cleanup_for_entity('ingredient');
