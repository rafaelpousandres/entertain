-- Phase 0 — events.

create table public.events (
  id             uuid primary key default gen_random_uuid(),
  group_id       uuid not null references public.groups(id) on delete cascade,
  title          text not null,
  type           public.event_type   not null,
  format         public.event_format not null,
  event_date     date,
  event_time     time,
  location_name  text,
  address        text,
  latitude       numeric,
  longitude      numeric,
  guest_count    integer not null,
  notes          text,
  status         public.event_status not null default 'planning',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

create index events_group_id_idx on public.events (group_id);

create trigger trg_events_updated_at
  before update on public.events
  for each row execute function public.set_updated_at();
