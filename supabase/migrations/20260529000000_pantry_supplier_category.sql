-- Phase 0 (fast-follow) — add the system "pantry" supplier category.
--
-- Product decision (screen group 2 / 3): per-event ingredient lines can be
-- reassigned to "pantry" on `event_dish_ingredients.supplier_category_id`
-- to mean "already at home, don't buy". The shopping-list logic of screen
-- group 3 will ignore lines assigned to this category. It is system content
-- (group_id null, is_system true) so it reads like the other built-in
-- categories and shows up in the ingredient editor and the per-event
-- supplier selector.
--
-- Follows the seed pattern of 20260525000900_system_content.sql: the row
-- in supplier_categories carries only `code`; the display name lives in the
-- translations table for ca/es/en.

insert into public.supplier_categories (group_id, code, is_system) values
  (null, 'pantry', true);

insert into public.translations (entity_type, entity_id, locale, field, text)
select 'supplier_category'::public.translation_entity_type,
       sc.id,
       t.locale::public.profile_locale,
       'name',
       t.text
from public.supplier_categories sc
join (values
  ('pantry', 'ca', 'Rebost'),
  ('pantry', 'es', 'Despensa'),
  ('pantry', 'en', 'Pantry')
) as t(code, locale, text) on t.code = sc.code
where sc.group_id is null;
