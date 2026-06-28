-- Spec 030 §E — deprecate the "Begudes" (system code 'beverages') supplier
-- category. A drink is a product *type*, not a *place you buy at*; new drinks now
-- default to "Supermercat" (code 'supermarket') in the app. This migration brings
-- existing data in line: it reassigns EVERY row that points to the system
-- 'beverages' category to the system 'supermarket' category — across all eight
-- FK columns — then removes 'beverages' (its translations first; nothing left
-- dangling). Reassign-before-delete matters: the delete rules are SET NULL for
-- most tables (which would orphan the drinks/ingredients to "no supplier") and
-- RESTRICT for event_dish_ingredients/orders (which would block the delete).
--
-- Both categories are system rows (is_system = true, group_id null). Idempotent:
-- a no-op once 'beverages' is gone.

do $$
declare
  bev uuid := (
    select id from public.supplier_categories
    where code = 'beverages' and group_id is null
  );
  sup uuid := (
    select id from public.supplier_categories
    where code = 'supermarket' and group_id is null
  );
begin
  if bev is null then
    return;  -- already deprecated on this database
  end if;
  if sup is null then
    raise exception 'supermarket category missing; cannot migrate beverages';
  end if;

  -- Reassign every reference (most are 0 today; included for completeness so no
  -- entity is ever left dangling and a fresh DB converges to the same state).
  update public.drinks                set supplier_category_id = sup where supplier_category_id = bev;
  update public.event_drinks          set supplier_category_id = sup where supplier_category_id = bev;
  update public.dishes                set supplier_category_id = sup where supplier_category_id = bev;
  update public.event_dishes          set supplier_category_id = sup where supplier_category_id = bev;
  update public.event_dish_ingredients set supplier_category_id = sup where supplier_category_id = bev;
  update public.ingredients           set default_supplier_category_id = sup where default_supplier_category_id = bev;
  update public.group_supplier_settings set supplier_category_id = sup where supplier_category_id = bev;
  update public.orders                set supplier_category_id = sup where supplier_category_id = bev;

  -- Remove the category and its ca/es/en names (no trigger covers
  -- supplier_category translations on the system path, so delete them explicitly).
  delete from public.translations
   where entity_type = 'supplier_category' and entity_id = bev;
  delete from public.supplier_categories where id = bev;
end $$;
