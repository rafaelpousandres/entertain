-- Specification 009 §2.2 — photo storage buckets and their access policies.
--
-- Three private buckets, in the same EU-region project as the database
-- (Spec §2.2.1):
--
--   dish-photos        — one photo per dish,        named `{dish_id}.jpg`
--   ingredient-photos  — one photo per ingredient,  named `{ingredient_id}.jpg`
--   event-photos       — many per event,            named `{event_id}/{photo_id}.jpg`
--
-- All private (public = false): every read/write goes through an
-- authenticated, RLS-checked request. Access is gated by the SAME principle as
-- the rest of the schema — a member of the owning row's group may read and
-- write — by deriving the owning id from the object path and joining the
-- parent table.
--
-- NOTE FOR THE OPERATOR: managing `storage.objects` policies requires
-- privileges the migration role may not have on the hosted project. If
-- `supabase db push` rejects this migration, run it from the Supabase
-- dashboard SQL editor (which executes with admin privileges). The bucket
-- rows and policies are idempotent, so re-running is safe.

-- Buckets ----------------------------------------------------------------
insert into storage.buckets (id, name, public)
values
  ('dish-photos',       'dish-photos',       false),
  ('ingredient-photos', 'ingredient-photos', false),
  ('event-photos',      'event-photos',      false)
on conflict (id) do nothing;

-- Policies ---------------------------------------------------------------
-- `id::text = split_part(name, …)` casts the known-valid uuid to text rather
-- than casting the (possibly malformed) object name to uuid, so a stray object
-- name can never raise a cast error inside the policy.

-- dish-photos: object `{dish_id}.jpg` → dishes.group_id.
drop policy if exists "dish_photos_group_access" on storage.objects;
create policy "dish_photos_group_access" on storage.objects
  for all to authenticated
  using (
    bucket_id = 'dish-photos'
    and exists (
      select 1 from public.dishes d
      where d.id::text = split_part(storage.objects.name, '.', 1)
        and public.is_group_member(d.group_id)
    )
  )
  with check (
    bucket_id = 'dish-photos'
    and exists (
      select 1 from public.dishes d
      where d.id::text = split_part(storage.objects.name, '.', 1)
        and public.is_group_member(d.group_id)
    )
  );

-- ingredient-photos: object `{ingredient_id}.jpg` → ingredients.group_id.
drop policy if exists "ingredient_photos_group_access" on storage.objects;
create policy "ingredient_photos_group_access" on storage.objects
  for all to authenticated
  using (
    bucket_id = 'ingredient-photos'
    and exists (
      select 1 from public.ingredients i
      where i.id::text = split_part(storage.objects.name, '.', 1)
        and public.is_group_member(i.group_id)
    )
  )
  with check (
    bucket_id = 'ingredient-photos'
    and exists (
      select 1 from public.ingredients i
      where i.id::text = split_part(storage.objects.name, '.', 1)
        and public.is_group_member(i.group_id)
    )
  );

-- event-photos: object `{event_id}/{photo_id}.jpg` → events.group_id.
drop policy if exists "event_photos_group_access" on storage.objects;
create policy "event_photos_group_access" on storage.objects
  for all to authenticated
  using (
    bucket_id = 'event-photos'
    and exists (
      select 1 from public.events e
      where e.id::text = split_part(storage.objects.name, '/', 1)
        and public.is_group_member(e.group_id)
    )
  )
  with check (
    bucket_id = 'event-photos'
    and exists (
      select 1 from public.events e
      where e.id::text = split_part(storage.objects.name, '/', 1)
        and public.is_group_member(e.group_id)
    )
  );
