-- Phase 0 — menu catalog: units, supplier_categories, ingredients, dishes,
-- and the per-event instance tables that snapshot a dish into an event.
--
-- supplier_categories is defined here (rather than with orders) because
-- ingredients reference it through default_supplier_category_id.

-- units ------------------------------------------------------------------
-- System catalog. Names are translated through the translations table.
create table public.units (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  magnitude   public.unit_magnitude not null,
  base_factor numeric,
  is_system   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create trigger trg_units_updated_at
  before update on public.units
  for each row execute function public.set_updated_at();

-- supplier_categories ----------------------------------------------------
-- System content has group_id null and is_system = true; per-group
-- categories carry a group_id and live alongside the system rows.
create table public.supplier_categories (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid references public.groups(id) on delete cascade,
  code       text not null,
  is_system  boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- A given code is unique within its group, and unique across system rows.
-- Postgres treats NULLs as distinct in unique indexes by default, so two
-- partial indexes encode the two scopes cleanly.
create unique index supplier_categories_system_code_idx
  on public.supplier_categories (code)
  where group_id is null;

create unique index supplier_categories_group_code_idx
  on public.supplier_categories (group_id, code)
  where group_id is not null;

create index supplier_categories_group_id_idx
  on public.supplier_categories (group_id);

create trigger trg_supplier_categories_updated_at
  before update on public.supplier_categories
  for each row execute function public.set_updated_at();

-- ingredients ------------------------------------------------------------
-- Soft-delete via deleted_at because catalog rows are referenced from
-- event-level snapshots and hard-deleting would orphan those references.
create table public.ingredients (
  id                            uuid primary key default gen_random_uuid(),
  group_id                      uuid references public.groups(id) on delete cascade,
  name                          text not null,
  default_unit_id               uuid not null references public.units(id) on delete restrict,
  default_supplier_category_id  uuid references public.supplier_categories(id) on delete set null,
  prep_description              text,
  package_equiv_value           numeric,
  package_equiv_unit_id         uuid references public.units(id) on delete set null,
  is_system                     boolean not null default false,
  created_at                    timestamptz not null default now(),
  updated_at                    timestamptz not null default now(),
  deleted_at                    timestamptz
);

create index ingredients_group_id_idx                      on public.ingredients (group_id);
create index ingredients_default_unit_id_idx               on public.ingredients (default_unit_id);
create index ingredients_default_supplier_category_id_idx  on public.ingredients (default_supplier_category_id);
create index ingredients_package_equiv_unit_id_idx         on public.ingredients (package_equiv_unit_id);

create trigger trg_ingredients_updated_at
  before update on public.ingredients
  for each row execute function public.set_updated_at();

-- dishes ------------------------------------------------------------------
create table public.dishes (
  id            uuid primary key default gen_random_uuid(),
  group_id      uuid not null references public.groups(id) on delete cascade,
  name          text not null,
  category      public.dish_category not null,
  base_servings integer not null default 4,
  description   text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);

create index dishes_group_id_idx on public.dishes (group_id);

create trigger trg_dishes_updated_at
  before update on public.dishes
  for each row execute function public.set_updated_at();

-- dish_ingredients (canonical recipe lines) ------------------------------
create table public.dish_ingredients (
  id            uuid primary key default gen_random_uuid(),
  dish_id       uuid not null references public.dishes(id)      on delete cascade,
  ingredient_id uuid not null references public.ingredients(id) on delete restrict,
  quantity      numeric not null,
  unit_id       uuid not null references public.units(id)       on delete restrict,
  prep_note     text,
  sort_order    integer not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index dish_ingredients_dish_id_idx       on public.dish_ingredients (dish_id);
create index dish_ingredients_ingredient_id_idx on public.dish_ingredients (ingredient_id);
create index dish_ingredients_unit_id_idx       on public.dish_ingredients (unit_id);

create trigger trg_dish_ingredients_updated_at
  before update on public.dish_ingredients
  for each row execute function public.set_updated_at();

-- event_dishes (snapshot of a dish into an event) -----------------------
-- source_dish_id is origin-only with no cascade: deleting the catalog dish
-- must not erase the menu of a past event.
create table public.event_dishes (
  id             uuid primary key default gen_random_uuid(),
  event_id       uuid not null references public.events(id) on delete cascade,
  source_dish_id uuid references public.dishes(id)         on delete set null,
  dish_name      text not null,
  category       public.dish_category not null,
  servings       integer not null,
  sort_order     integer not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index event_dishes_event_id_idx        on public.event_dishes (event_id);
create index event_dishes_source_dish_id_idx  on public.event_dishes (source_dish_id);

create trigger trg_event_dishes_updated_at
  before update on public.event_dishes
  for each row execute function public.set_updated_at();

-- event_dish_ingredients (editable copy of recipe lines) ----------------
create table public.event_dish_ingredients (
  id                    uuid primary key default gen_random_uuid(),
  event_dish_id         uuid not null references public.event_dishes(id) on delete cascade,
  ingredient_id         uuid references public.ingredients(id)           on delete set null,
  ingredient_name       text not null,
  quantity              numeric not null,
  unit_id               uuid not null references public.units(id)        on delete restrict,
  prep_note             text,
  supplier_category_id  uuid references public.supplier_categories(id)    on delete restrict,
  sort_order            integer not null default 0,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create index event_dish_ingredients_event_dish_id_idx        on public.event_dish_ingredients (event_dish_id);
create index event_dish_ingredients_ingredient_id_idx        on public.event_dish_ingredients (ingredient_id);
create index event_dish_ingredients_unit_id_idx              on public.event_dish_ingredients (unit_id);
create index event_dish_ingredients_supplier_category_id_idx on public.event_dish_ingredients (supplier_category_id);

create trigger trg_event_dish_ingredients_updated_at
  before update on public.event_dish_ingredients
  for each row execute function public.set_updated_at();
