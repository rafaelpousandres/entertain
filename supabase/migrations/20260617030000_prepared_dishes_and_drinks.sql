-- Specification 014 — prepared dishes and drinks.
--
-- Adds two non-cooked menu item types, both the "degenerate case" of a recipe
-- (a single purchase line instead of an ingredient list):
--   * prepared dish — a dish bought ready-made; an attribute of the dish
--     (`acquisition_mode`), not a new entity.
--   * drink — its own catalog (`drinks`) + per-event copy (`event_drinks`).
-- Both reuse Spec 013's supplier model (a category → one or more suppliers,
-- resolved at order time) and flow into Shopping as single purchase lines.
--
-- Entirely additive: new enum, new columns, two new tables, a new media enum
-- value + bucket, and two idempotently-seeded system supplier categories. The
-- destructive-migration stop does not apply; shown before push per house rule.

-- 1. Dish acquisition mode ----------------------------------------------
create type public.dish_acquisition_mode as enum ('cooked', 'bought');
grant usage on type public.dish_acquisition_mode to anon, authenticated;

-- The four bought-dish columns are used only when acquisition_mode = 'bought';
-- a cooked dish keeps acquisition_mode 'cooked' and these stay null.
alter table public.dishes
  add column acquisition_mode     public.dish_acquisition_mode not null
                                  default 'cooked',
  add column supplier_category_id uuid references public.supplier_categories(id)
                                  on delete set null,
  add column purchase_unit        text,
  add column servings_per_unit    numeric;

-- 2. event_dishes: snapshot the bought-dish fields + a purchase state -----
-- `state` is the shopping state of the bought dish's single purchase line. It
-- is IGNORED for cooked dishes (their shopping state lives on the ingredient
-- lines in event_dish_ingredients), so a cooked dish never produces a phantom
-- purchase line — the app only builds a purchase line when acquisition_mode is
-- 'bought'.
alter table public.event_dishes
  add column acquisition_mode     public.dish_acquisition_mode not null
                                  default 'cooked',
  add column supplier_category_id uuid references public.supplier_categories(id)
                                  on delete set null,
  add column purchase_unit        text,
  add column servings_per_unit    numeric,
  add column state                public.ingredient_state not null
                                  default 'to_order';

-- 3. drinks catalog (per group, parallel to a prepared dish) -------------
create table public.drinks (
  id                   uuid primary key default gen_random_uuid(),
  group_id             uuid not null references public.groups(id) on delete cascade,
  name                 text not null,
  base_servings        integer not null default 4,
  supplier_category_id uuid references public.supplier_categories(id)
                       on delete set null,
  purchase_unit        text,
  servings_per_unit    numeric,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  deleted_at           timestamptz
);

create index drinks_group_id_idx on public.drinks (group_id);

create trigger trg_drinks_updated_at
  before update on public.drinks
  for each row execute function public.set_updated_at();

alter table public.drinks enable row level security;

create policy drinks_select on public.drinks
  for select to authenticated using (public.is_group_member(group_id));
create policy drinks_insert on public.drinks
  for insert to authenticated with check (public.is_group_member(group_id));
create policy drinks_update on public.drinks
  for update to authenticated
  using (public.is_group_member(group_id))
  with check (public.is_group_member(group_id));
create policy drinks_delete on public.drinks
  for delete to authenticated using (public.is_group_member(group_id));

-- New user-data table → needs an explicit GRANT (RLS gates rows, GRANT gates
-- table access; without it every call fails "permission denied" before RLS).
grant select, insert, update, delete on table public.drinks
  to anon, authenticated;

-- 4. event_drinks (per-event copy, mirror of event_dishes) ---------------
-- A drink copied into an event: an immutable snapshot, scaled to the guest
-- count. No ingredients — the drink is a single purchase line, so `state` is
-- always meaningful here (unlike the cooked-dish case on event_dishes).
create table public.event_drinks (
  id                   uuid primary key default gen_random_uuid(),
  event_id             uuid not null references public.events(id) on delete cascade,
  source_drink_id      uuid references public.drinks(id) on delete set null,
  drink_name           text not null,
  supplier_category_id uuid references public.supplier_categories(id)
                       on delete set null,
  purchase_unit        text,
  servings_per_unit    numeric,
  servings             integer not null,
  state                public.ingredient_state not null default 'to_order',
  sort_order           integer not null default 0,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create index event_drinks_event_id_idx       on public.event_drinks (event_id);
create index event_drinks_source_drink_id_idx on public.event_drinks (source_drink_id);

create trigger trg_event_drinks_updated_at
  before update on public.event_drinks
  for each row execute function public.set_updated_at();

alter table public.event_drinks enable row level security;

create policy event_drinks_all on public.event_drinks
  for all to authenticated
  using (
    exists (
      select 1 from public.events e
      where e.id = event_drinks.event_id
        and public.is_group_member(e.group_id)
    )
  )
  with check (
    exists (
      select 1 from public.events e
      where e.id = event_drinks.event_id
        and public.is_group_member(e.group_id)
    )
  );

grant select, insert, update, delete on table public.event_drinks
  to anon, authenticated;

-- 5. Media: a 'drink' entity type + its storage bucket -------------------
-- `if not exists` keeps the enum addition idempotent. The new value is not used
-- as a literal anywhere in this migration, so it is safe inside the migration
-- transaction (Postgres only forbids USING a value added in the same tx).
alter type public.media_entity_type add value if not exists 'drink';

insert into storage.buckets (id, name, public)
values ('drink-photos', 'drink-photos', false)
on conflict (id) do nothing;

-- drink-photos: `{drink_id}.jpg` or `{drink_id}/{photo_id}.jpg` →
-- drinks.group_id (mirrors the dish/ingredient policies, both path forms).
-- NOTE FOR THE OPERATOR: like 20260612030000 / 20260613070000, this touches
-- `storage.objects` policies. If `supabase db push` lacks the privilege on the
-- hosted project, run this file from the dashboard SQL editor. Idempotent.
drop policy if exists "drink_photos_group_access" on storage.objects;
create policy "drink_photos_group_access" on storage.objects
  for all to authenticated
  using (
    bucket_id = 'drink-photos'
    and exists (
      select 1 from public.drinks d
      where d.id::text = case
        when position('/' in storage.objects.name) > 0
          then split_part(storage.objects.name, '/', 1)
        else split_part(storage.objects.name, '.', 1)
      end
        and public.is_group_member(d.group_id)
    )
  )
  with check (
    bucket_id = 'drink-photos'
    and exists (
      select 1 from public.drinks d
      where d.id::text = case
        when position('/' in storage.objects.name) > 0
          then split_part(storage.objects.name, '/', 1)
        else split_part(storage.objects.name, '.', 1)
      end
        and public.is_group_member(d.group_id)
    )
  );

-- 6. Two system supplier categories (idempotent) ------------------------
-- System content (group_id null, is_system true), like butcher/fishmonger/
-- pantry: any group can add suppliers to them and set a default (Spec 013).
-- They are sensible defaults for prepared dishes / drinks, not a constraint.
-- Follows the seed pattern of 20260529000000_pantry_supplier_category.sql,
-- guarded with NOT EXISTS so re-running never inserts duplicates.
insert into public.supplier_categories (group_id, code, is_system)
select null, c.code, true
from (values ('prepared'), ('beverages')) as c(code)
where not exists (
  select 1 from public.supplier_categories sc
  where sc.code = c.code and sc.group_id is null
);

insert into public.translations (entity_type, entity_id, locale, field, text)
select 'supplier_category'::public.translation_entity_type,
       sc.id,
       t.locale::public.profile_locale,
       'name',
       t.text
from public.supplier_categories sc
join (values
  ('prepared',  'ca', 'Plats preparats'),
  ('prepared',  'es', 'Platos preparados'),
  ('prepared',  'en', 'Prepared dishes'),
  ('beverages', 'ca', 'Begudes'),
  ('beverages', 'es', 'Bebidas'),
  ('beverages', 'en', 'Drinks')
) as t(code, locale, text) on t.code = sc.code
where sc.group_id is null
  and not exists (
    select 1 from public.translations tr
    where tr.entity_type = 'supplier_category'::public.translation_entity_type
      and tr.entity_id = sc.id
      and tr.locale = t.locale::public.profile_locale
      and tr.field = 'name'
  );
