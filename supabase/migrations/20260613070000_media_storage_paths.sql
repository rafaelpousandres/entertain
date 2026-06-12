-- Specification 010 §2.4 / §2.3 — widen the dish/ingredient storage policies to
-- accept multi-photo object paths.
--
-- Spec 009 stored a single photo per dish / ingredient as a flat object named
-- after the row id (`{id}.jpg`), so the access policies derived the owning id
-- with `split_part(name, '.', 1)`. With §2.3 promoting these entities to
-- multi-photo carousels, new uploads land under a per-entity folder
-- (`{entity_id}/{photo_id}.jpg`, the same convention the event bucket already
-- uses), so a single object name can no longer be parsed by the dot alone.
--
-- These policies now derive the owning id as: the first path segment before a
-- '/' when the object lives in a folder (new multi-photo uploads), else the
-- part before the '.' (legacy single-photo objects). Both forms coexist in the
-- same bucket — no blobs are moved (Spec §2.4 decision). The event-photos
-- policy already used the folder form and is left unchanged.
--
-- NOTE FOR THE OPERATOR: like 20260612030000, this touches `storage.objects`
-- policies. If `supabase db push` lacks the privilege on the hosted project,
-- run it from the dashboard SQL editor. Idempotent (drop-if-exists + create).

-- dish-photos: `{dish_id}.jpg` or `{dish_id}/{photo_id}.jpg` → dishes.group_id.
drop policy if exists "dish_photos_group_access" on storage.objects;
create policy "dish_photos_group_access" on storage.objects
  for all to authenticated
  using (
    bucket_id = 'dish-photos'
    and exists (
      select 1 from public.dishes d
      where d.id::text = case
        when position('/' in storage.objects.name) > 0
          then split_part(storage.objects.name, '/', 1)
        else split_part(storage.objects.name, '.', 1)
      end
        and public.is_group_member(d.group_id)
    )
  )
  with check (
    bucket_id = 'dish-photos'
    and exists (
      select 1 from public.dishes d
      where d.id::text = case
        when position('/' in storage.objects.name) > 0
          then split_part(storage.objects.name, '/', 1)
        else split_part(storage.objects.name, '.', 1)
      end
        and public.is_group_member(d.group_id)
    )
  );

-- ingredient-photos: `{ingredient_id}.jpg` or `{ingredient_id}/{photo_id}.jpg`
-- → ingredients.group_id.
drop policy if exists "ingredient_photos_group_access" on storage.objects;
create policy "ingredient_photos_group_access" on storage.objects
  for all to authenticated
  using (
    bucket_id = 'ingredient-photos'
    and exists (
      select 1 from public.ingredients i
      where i.id::text = case
        when position('/' in storage.objects.name) > 0
          then split_part(storage.objects.name, '/', 1)
        else split_part(storage.objects.name, '.', 1)
      end
        and public.is_group_member(i.group_id)
    )
  )
  with check (
    bucket_id = 'ingredient-photos'
    and exists (
      select 1 from public.ingredients i
      where i.id::text = case
        when position('/' in storage.objects.name) > 0
          then split_part(storage.objects.name, '/', 1)
        else split_part(storage.objects.name, '.', 1)
      end
        and public.is_group_member(i.group_id)
    )
  );
