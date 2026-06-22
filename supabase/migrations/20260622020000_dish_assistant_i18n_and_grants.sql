-- Specification 020 — AI dish assistant: catalog i18n (ingredients + dishes) and
-- the service-role write grants the dish-assistant Edge Function needs.
--
-- Entirely additive: one new enum value, two nullable columns, four grants.
-- The `dish_assistant` quota reuses the generic Spec 019 quota tables/RPCs with a
-- new `quota_key` — no schema change for the quota itself.
--
-- This Spec only *stores* the multilingual names (ca/es/en) and marks which one
-- is the original; locale-aware *display* (and backfilling existing rows) is a
-- separate effort (Spec 021). The app keeps showing ingredients.name / dishes.name
-- (the original) until then.

-- 1. Dishes become a translatable entity (§4). The translation rows for a dish
--    name use entity_type = 'dish', field = 'name'. Ingredients already are a
--    member of this enum. Adding the value in its own migration (and not using it
--    here) keeps it safe on PG12+ where a new enum value can't be used in the
--    same transaction that adds it.
alter type public.translation_entity_type add value if not exists 'dish';

-- 2. Original-language mark for AI-created catalog entries (§4): the locale the
--    source/user actually wrote, vs. the AI-derived translations. Nullable —
--    legacy, user-created, and system rows stay null. One fact per entity, so it
--    lives on the entity, not on each translation row.
alter table public.ingredients
  add column original_locale public.profile_locale;
alter table public.dishes
  add column original_locale public.profile_locale;

-- 3. Service-role write grants (the media lesson from Spec 019). The dish-assistant
--    Edge Function creates ingredients, dishes, dish_ingredients, and translation
--    rows as the service role. The service role has BYPASSRLS but Postgres still
--    checks *table privileges* first — and these tables grant DML only to
--    anon/authenticated (translations is SELECT-only for clients), never to
--    service_role. Without these grants the function's inserts fail with
--    "permission denied for table ...". Grant the same four DML verbs the table
--    already gives the app roles; RLS is irrelevant to the service role.
grant select, insert, update, delete on table public.translations     to service_role;
grant select, insert, update, delete on table public.ingredients      to service_role;
grant select, insert, update, delete on table public.dishes           to service_role;
grant select, insert, update, delete on table public.dish_ingredients to service_role;
