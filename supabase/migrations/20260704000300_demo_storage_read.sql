-- ============================================================================
-- Spec 033 §A.3 — shared read-only demo photos (M4)
--
-- The demo dataset's photos live ONCE under a `demo/` prefix in each per-type
-- bucket (uploaded by the operator stage step). Every new user's demo `media`
-- rows REFERENCE those shared blobs instead of copying them — so seeding is
-- pure SQL and Storage stays flat regardless of how many users sign up.
--
-- This adds a SELECT policy letting any authenticated user read objects under
-- `demo/` in the four photo buckets. There is deliberately NO insert/update/
-- delete policy for that prefix, so the shared assets are read-only to clients
-- (only the service-role operator uploads them) — that is what keeps users
-- isolated: nobody can mutate or remove another user's demo image.
--
-- ADDITIVE / NON-DESTRUCTIVE: only new RLS policies on storage.objects.
-- ============================================================================

drop policy if exists "demo shared read dish"       on storage.objects;
drop policy if exists "demo shared read ingredient" on storage.objects;
drop policy if exists "demo shared read event"      on storage.objects;
drop policy if exists "demo shared read drink"      on storage.objects;

create policy "demo shared read dish" on storage.objects
  for select to authenticated
  using (bucket_id = 'dish-photos' and name like 'demo/%');

create policy "demo shared read ingredient" on storage.objects
  for select to authenticated
  using (bucket_id = 'ingredient-photos' and name like 'demo/%');

create policy "demo shared read event" on storage.objects
  for select to authenticated
  using (bucket_id = 'event-photos' and name like 'demo/%');

create policy "demo shared read drink" on storage.objects
  for select to authenticated
  using (bucket_id = 'drink-photos' and name like 'demo/%');
