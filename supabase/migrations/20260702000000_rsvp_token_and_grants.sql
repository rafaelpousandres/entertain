-- Spec 029 — public RSVP web surface (guests Layer 2).
--
-- Per-guest RSVP token + the self-reported dietary restrictions (C2) + the
-- service_role privileges the public `rsvp` Edge Function needs.
--
-- rsvp_token: the guest's unguessable capability. The invitation link embeds
--   it, and the function reads/writes ONLY the row matched by `rsvp_token`
--   (never a list, never another key). Adding it with a default backfills every
--   existing guest; new guests get one automatically. `unique` makes it a
--   per-guest capability and creates the lookup index.
--
-- diet_*: optional, PER-EVENT restrictions the guest self-reports on the RSVP
--   page (3 checkboxes aligned with the VGN/VGT/SG system; vegan implies
--   vegetarian). `not null default false` → existing guests start as "nothing
--   reported". The same token-row UPDATE that records the answer writes these in
--   one statement — no change to the token isolation. Shown to the host on the
--   Convidats tab. (No menu-vs-restrictions check here — capture only.)
--
-- House rule (CLAUDE.md): any table an Edge Function touches via the service
-- role needs an explicit GRANT — Postgres checks table privileges *before* the
-- RLS bypass, so a missing grant fails with "permission denied for table …".
-- Layer 1 (20260627000000) granted event_guests only to anon/authenticated; the
-- rsvp function READS (name/state/diet/event) and UPDATES (state + diet) the
-- single token row, so it gets SELECT + UPDATE here (no INSERT/DELETE; the grant
-- is table-wide, so it covers the new columns). `events` already has SELECT
-- for service_role (20260626000000).

alter table public.event_guests
  add column if not exists rsvp_token uuid not null default gen_random_uuid();

alter table public.event_guests
  add column if not exists diet_vegetarian  boolean not null default false,
  add column if not exists diet_vegan       boolean not null default false,
  add column if not exists diet_gluten_free boolean not null default false;

create unique index if not exists event_guests_rsvp_token_key
  on public.event_guests (rsvp_token);

grant select, update on table public.event_guests to service_role;
