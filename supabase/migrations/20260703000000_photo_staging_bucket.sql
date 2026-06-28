-- Specification 030 §B (completion) — photo-staging bucket.
--
-- Spec 030 §B lets the catalog editors (ingredient, dish, drink) attach photos
-- while CREATING the entity, before its row exists. But the per-entity Storage
-- policies (20260613070000 / 20260617030000) and the `media` RLS
-- (20260618000000) require the parent row to exist, so a photo written during
-- creation is denied — the "No s'ha pogut desar la foto" bug. This bucket is the
-- staging area: photos added during creation are uploaded here, keyed by the
-- caller's GROUP (not the not-yet-existing entity); on save the editor PROMOTES
-- them to the entity's real bucket (a client-side cross-bucket move, valid once
-- the row exists) and inserts the `media` row. Abandoned staged blobs (cancel,
-- back, app-kill) are swept by the `sweep-staging` function after 24h.
--
-- Path: `{group_id}/{uuid}.jpg`. The first path segment is the owning group and
-- is the only access key — a member of that group may read and write its own
-- staging area. No entity row is involved, so the entity-scoped policies are NOT
-- relaxed; the group membership check is exactly as strict as everywhere else.
--
-- NOTE FOR THE OPERATOR: like the other storage.objects migrations
-- (20260612030000 etc.), managing bucket policies needs privileges the migration
-- role may lack on the hosted project. If `supabase db push` rejects this
-- migration, run it from the Supabase dashboard SQL editor (admin privileges).
-- The bucket row and the policy are idempotent, so re-running is safe.

-- Bucket -----------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('photo-staging', 'photo-staging', false)
on conflict (id) do nothing;

-- Policy -----------------------------------------------------------------
-- Mirrors the entity buckets' defensive style: derive the owning id from the
-- object path and join the parent table, casting the KNOWN-VALID id to text
-- (`g.id::text = split_part(name, …)`) rather than casting the possibly
-- malformed object name to uuid — so a stray object name can never raise a cast
-- error inside the policy. Here the parent is the group itself.
drop policy if exists "photo_staging_group_access" on storage.objects;
create policy "photo_staging_group_access" on storage.objects
  for all to authenticated
  using (
    bucket_id = 'photo-staging'
    and exists (
      select 1 from public.groups g
      where g.id::text = split_part(storage.objects.name, '/', 1)
        and public.is_group_member(g.id)
    )
  )
  with check (
    bucket_id = 'photo-staging'
    and exists (
      select 1 from public.groups g
      where g.id::text = split_part(storage.objects.name, '/', 1)
        and public.is_group_member(g.id)
    )
  );
