-- Spec 022 (AI menu wizard) — service_role SELECT grants for the tables the
-- `menu-wizard` Edge Function READS via the service-role client.
--
-- menu-wizard is read-only on the DB: its single `propose` action loads the
-- event's planning params, the current menu names (to complement it in
-- "completa" mode), and the group's dish/drink catalogs. service_role has
-- BYPASSRLS, but
-- Postgres checks table privileges *before* RLS — so a missing grant fails with
-- "permission denied for table …", which the client often swallows into a
-- silent fallback. These five tables were created before Spec 019 and only ever
-- granted to anon/authenticated; the function never touched them until now.
--
-- House rule (CLAUDE.md): every new table a function touches needs its explicit
-- service_role grant. Audit result for 022 — already granted in 019/020:
--   ingredients, units, supplier_categories, translations, dishes,
--   dish_ingredients, media, quota_entitlements, quota_usage.
-- Missing — granted here, exactly the four the function reads (it complements
-- the menu from dish/drink NAMES, so it never reads event_dish_ingredients):
--   events, event_dishes, event_drinks, drinks.
--
-- SELECT only — propose never writes. New dishes/menu items are persisted on
-- accept by the existing dish-assistant `save` (already granted) and the
-- client's addDishToEvent/addDrinkToEvent (under the user's RLS), not here.

grant select on table public.events       to service_role;
grant select on table public.event_dishes to service_role;
grant select on table public.event_drinks to service_role;
grant select on table public.drinks       to service_role;
