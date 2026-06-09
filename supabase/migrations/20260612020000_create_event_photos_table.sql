-- Specification 009 §2.2 — event photo album.
--
-- Unlike dishes and ingredients (one "main" photo each, tracked by a
-- `photo_path` column), an event carries **multiple** photos presented as a
-- carousel. They live in their own child table, one row per photo, ordered by
-- `position`. The bytes are in the `event-photos` bucket under
-- `{event_id}/{photo_id}.jpg` (Spec §2.2.1).
--
-- Order semantics (§2.2.6): ascending `position`, then ascending `created_at`
-- as tiebreaker. A new photo gets `position` = the current photo count, so it
-- appends to the end.

create table public.event_photos (
  id          uuid primary key default gen_random_uuid(),
  event_id    uuid not null references public.events(id) on delete cascade,
  photo_path  text not null,
  position    integer not null default 0,
  created_at  timestamptz not null default now()
);

create index event_photos_event_id_position_idx
  on public.event_photos (event_id, position);

-- Row-level security: a photo row is accessible to members of its event's
-- group, mirroring the event_dishes policy (group via event). One ALL policy
-- since the access rule is identical for select / insert / update / delete.
alter table public.event_photos enable row level security;

create policy event_photos_all on public.event_photos
  for all to authenticated
  using (
    exists (
      select 1 from public.events e
      where e.id = event_photos.event_id
        and public.is_group_member(e.group_id)
    )
  )
  with check (
    exists (
      select 1 from public.events e
      where e.id = event_photos.event_id
        and public.is_group_member(e.group_id)
    )
  );
