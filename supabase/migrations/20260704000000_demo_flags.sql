-- ============================================================================
-- Spec 033 §A.4 — demo-data markers (M1)
--
-- Adds an `is_demo` flag to every table the onboarding demo dataset seeds, plus
-- a one-shot `demo_seeded_at` stamp on `groups`. The flag is internal
-- traceability only (never shown in the UI), and is what lets "start from
-- scratch" delete EXACTLY the seeded example while preserving anything the user
-- created.
--
-- ADDITIVE / NON-DESTRUCTIVE: every column is added with a default, so no
-- existing row is rewritten and no existing data is touched. Safe to run on a
-- database with live user data.
-- ============================================================================

-- One-shot guard: set the first time a group is seeded with demo data, so the
-- seed runs once per user and never returns after the example is deleted.
alter table public.groups
  add column if not exists demo_seeded_at timestamptz;

-- `is_demo` on every seeded entity. Default false → existing rows are user data.
alter table public.ingredients            add column if not exists is_demo boolean not null default false;
alter table public.dishes                 add column if not exists is_demo boolean not null default false;
alter table public.dish_ingredients       add column if not exists is_demo boolean not null default false;
alter table public.drinks                 add column if not exists is_demo boolean not null default false;
alter table public.events                 add column if not exists is_demo boolean not null default false;
alter table public.event_dishes           add column if not exists is_demo boolean not null default false;
alter table public.event_dish_ingredients add column if not exists is_demo boolean not null default false;
alter table public.event_drinks           add column if not exists is_demo boolean not null default false;
alter table public.event_guests           add column if not exists is_demo boolean not null default false;
alter table public.supplier_categories    add column if not exists is_demo boolean not null default false;
alter table public.group_supplier_settings add column if not exists is_demo boolean not null default false;
alter table public.media                  add column if not exists is_demo boolean not null default false;

-- Partial indexes on the group-scoped tables: the events banner check
-- (`exists demo rows in this group`) and "start from scratch" both filter by
-- (group_id, is_demo). Partial → tiny, only indexes the demo rows.
create index if not exists ingredients_demo_idx             on public.ingredients (group_id)            where is_demo;
create index if not exists dishes_demo_idx                  on public.dishes (group_id)                 where is_demo;
create index if not exists drinks_demo_idx                  on public.drinks (group_id)                 where is_demo;
create index if not exists events_demo_idx                  on public.events (group_id)                 where is_demo;
create index if not exists event_guests_demo_idx            on public.event_guests (group_id)           where is_demo;
create index if not exists supplier_categories_demo_idx     on public.supplier_categories (group_id)    where is_demo;
create index if not exists group_supplier_settings_demo_idx on public.group_supplier_settings (group_id) where is_demo;

-- Child tables (no group_id): index the demo rows for the FK-ordered cleanup.
create index if not exists dish_ingredients_demo_idx        on public.dish_ingredients (dish_id)              where is_demo;
create index if not exists event_dishes_demo_idx            on public.event_dishes (event_id)                where is_demo;
create index if not exists event_dish_ingredients_demo_idx  on public.event_dish_ingredients (event_dish_id) where is_demo;
create index if not exists event_drinks_demo_idx            on public.event_drinks (event_id)                where is_demo;
create index if not exists media_demo_idx                   on public.media (entity_type, entity_id)         where is_demo;
