-- Spec 023 Layer 1 — guest list & invitations (core).
--
-- A per-event guest list with manual RSVP state and an event-level invitation
-- template. Layer 1 is entirely client-side under RLS: NO Edge Function touches
-- this table, so it needs NO service_role grant (only anon/authenticated, the
-- client roles). Layer 2 (the RSVP link / public web surface) is a later pass;
-- if its `rsvp` Edge Function ever writes these rows with the service role, the
-- explicit service_role grant gets added in that migration (house rule).

create table public.event_guests (
  id          uuid primary key default gen_random_uuid(),
  event_id    uuid not null references public.events(id) on delete cascade,
  group_id    uuid not null references public.groups(id) on delete cascade,
  name        text not null,
  phone       text,
  email       text,
  state       text not null default 'pendent'
              check (state in ('pendent','confirmat','excusat')),
  invited_at  timestamptz,            -- set when the invitation is sent (§1.6)
  created_at  timestamptz not null default now()
);

-- Grouped read (accordion by state) + the per-event listing.
create index event_guests_event_state_idx
  on public.event_guests (event_id, state);

alter table public.event_guests enable row level security;

-- Group members may read/write their group's guests (same shape as the rest of
-- the per-event data). is_group_member is the shared membership predicate.
create policy event_guests_rw on public.event_guests
  for all to authenticated
  using (public.is_group_member(group_id))
  with check (public.is_group_member(group_id));

-- Table privileges are checked before RLS — grant the client roles (NOT
-- service_role: no Edge Function reads/writes this in Layer 1).
grant select, insert, update, delete on table public.event_guests
  to anon, authenticated;

-- Event-level invitation template (§1.6): prefilled from the event in the app,
-- editable by the host, reused as the message body when sending invitations.
alter table public.events add column if not exists invitation_text text;
