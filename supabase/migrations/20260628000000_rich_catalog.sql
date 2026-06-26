-- Spec 025 — Rich catalog: dietary attributes + multilingual names (drinks join
-- the existing i18n model). One coherent pass.
--
-- Multilingual names REUSE the existing `translations` table (Spec 020 already
-- writes ingredient/dish name rows there, with `original_locale` on those
-- tables). This migration only closes the drink gap (enum value + original_locale
-- column) and adds the dietary axes; display resolution is client-side (the
-- repository merges `translations` into the display name, like units/categories).

-- ── Dietary enums ──────────────────────────────────────────────────────────
-- `diet_level` is ORDERED on purpose: vegan/vegetarian are levels on one axis,
-- so "vegan ⇒ vegetarian" is structural and "vegan but not vegetarian" cannot be
-- represented (do NOT model them as two booleans). `unknown` is the explicit
-- "not yet classified" state and the default for every existing row.
do $$ begin
  create type public.diet_level as enum ('unknown','none','vegetarian','vegan');
exception when duplicate_object then null; end $$;

-- Independent tri-state for gluten, default unknown.
do $$ begin
  create type public.tri_state as enum ('unknown','yes','no');
exception when duplicate_object then null; end $$;

-- ── Dietary axes on ingredients (primary; user-marked, default unknown) ─────
alter table public.ingredients
  add column if not exists diet        public.diet_level not null default 'unknown',
  add column if not exists gluten_free public.tri_state  not null default 'unknown';

-- ── Manual dietary on dishes (used ONLY when a dish has no ingredients; a dish
-- with ingredients derives its status on read and ignores these). ────────────
alter table public.dishes
  add column if not exists diet        public.diet_level not null default 'unknown',
  add column if not exists gluten_free public.tri_state  not null default 'unknown';

-- ── Multilingual names: drinks join the model used by ingredients/dishes ────
-- ALTER TYPE ADD VALUE must be committed before the value is used; this
-- migration only adds it (never uses it in the same statement batch), mirroring
-- how Spec 020 added 'dish'.
alter type public.translation_entity_type add value if not exists 'drink';

-- Marks the locale a drink's name was originally written in (the other two are
-- AI-derived in `translations`). Nullable; legacy rows inferred at backfill.
alter table public.drinks
  add column if not exists original_locale public.profile_locale;

-- ── service_role grant audit (Spec 025) ────────────────────────────────────
-- The new AI name helpers (`translate-name`, `backfill-name-i18n`) update
-- `drinks.original_locale` and read drink names with the service-role client.
-- service_role checks table privileges before RLS, so it needs an explicit
-- grant. `ingredients`/`dishes`/`translations` were already granted (Spec 020);
-- `drinks` is the only gap found in the audit. Parity grant with dishes/ingredients.
grant select, insert, update, delete on table public.drinks to service_role;
