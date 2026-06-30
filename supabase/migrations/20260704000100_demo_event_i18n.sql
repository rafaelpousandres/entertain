-- ============================================================================
-- Spec 033 §A.8 — demo event title/location translations (M2)
--
-- The demo catalog is already trilingual (via `translations`), but the 4 demo
-- EVENT titles + locations are plain stored strings, English-only on the
-- template. This adds a small lookup of their ca/es/en variants, keyed by a
-- stable `demo_key`, and tags the template's 4 events with that key. `seed_demo`
-- picks the row matching the new user's phone locale when cloning.
--
-- ADDITIVE / NON-DESTRUCTIVE: a new table + a new nullable column; the only
-- UPDATE touches the 4 event rows of the demo TEMPLATE group (tagging), not any
-- real user's data.
-- ============================================================================

create table if not exists public.demo_event_i18n (
  demo_key      text not null,
  locale        public.profile_locale not null,
  title         text not null,
  location_name text not null,
  primary key (demo_key, locale)
);

-- Operator/reference data; readable by anyone authenticated (seed_demo reads it
-- as SECURITY DEFINER anyway). No writes from clients.
alter table public.demo_event_i18n enable row level security;
drop policy if exists demo_event_i18n_read on public.demo_event_i18n;
create policy demo_event_i18n_read on public.demo_event_i18n
  for select to authenticated using (true);

insert into public.demo_event_i18n (demo_key, locale, title, location_name) values
  ('christmas','en','Christmas Eve Dinner','Rosewood Cottage'),
  ('christmas','ca','Sopar de Nit de Nadal','Casa Rosewood'),
  ('christmas','es','Cena de Nochebuena','Casa Rosewood'),
  ('brunch','en','Garden Brunch','Linden Terrace'),
  ('brunch','ca','Brunch al jardí','Terrassa Linden'),
  ('brunch','es','Brunch en el jardín','Terraza Linden'),
  ('italian','en','Italian Sunday Dinner','Casa Bianchi'),
  ('italian','ca','Sopar italià de diumenge','Casa Bianchi'),
  ('italian','es','Cena italiana de domingo','Casa Bianchi'),
  ('summer','en','Summer Garden Party','Willowbrook Garden'),
  ('summer','ca','Festa d''estiu al jardí','Jardí de Willowbrook'),
  ('summer','es','Fiesta de verano en el jardín','Jardín de Willowbrook')
on conflict (demo_key, locale) do update
  set title = excluded.title, location_name = excluded.location_name;

-- Stable key on every event so the clone can localise it; null for normal events.
alter table public.events add column if not exists demo_key text;

-- Tag the template group's 4 events (matched by their English title).
update public.events e set demo_key = v.k
from (values
  ('Christmas Eve Dinner','christmas'),
  ('Garden Brunch','brunch'),
  ('Italian Sunday Dinner','italian'),
  ('Summer Garden Party','summer')
) as v(title, k)
where e.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and e.title = v.title;
