-- Specification 009 Fixes §2 / §6 — missing GRANT on event_photos.
--
-- The table was created in 20260612020000_create_event_photos_table.sql with
-- its RLS policy, but — like the Phase 0 tables before the
-- 20260525001000_grants.sql migration — it never received the matching
-- table-level privileges. Postgres checks the traditional GRANTs *before* any
-- RLS policy runs and rejects the request with "permission denied for table
-- event_photos" first, so every read/insert/delete against the album failed:
--
--   * deleting an event aborted on the `event_photos` purge (the first thing
--     deleteEvent() touches), surfacing as "couldn't save the event" (§2);
--   * the photos section's SELECT failed, leaving the carousel stuck on a
--     spinner / "couldn't load the photo" even for events with no photos (§6).
--
-- Granting full DML to anon + authenticated restores the same two-layer model
-- the rest of the schema uses: the GRANT lets the request reach RLS, and the
-- existing `event_photos_all` policy (group membership via the parent event)
-- gates which rows each caller may actually touch.

grant select, insert, update, delete on table
  public.event_photos
to anon, authenticated;
