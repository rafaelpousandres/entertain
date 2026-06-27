-- Spec 026 Part E.1 — one-off sweep of pre-existing orphan translations.
--
-- NOT a migration (kept out of supabase/migrations/ so `db push` never runs it).
-- Run ONCE, by hand, in the SQL editor, AFTER the 026 migrations are pushed.
--
-- Why orphans exist: `translations` is polymorphic (no FK to entity_id). The
-- recent empty-group cleanup hard-deleted ingredients/dishes/drinks via cascade,
-- leaving their translation rows behind. Going forward the AFTER DELETE trigger
-- (migration 20260629000000_hints.sql) prevents new ones; this clears the old.
--
-- Only ingredient/dish/drink translations are swept. System translations
-- (unit, supplier_category, hint) are never touched.

-- 1) PRE-COUNT — run this first and note the number.
select count(*) as orphan_translations
from public.translations t
where t.entity_type in ('ingredient', 'dish', 'drink')
  and not exists (
    select 1 from public.ingredients i
     where t.entity_type = 'ingredient' and i.id = t.entity_id
    union all
    select 1 from public.dishes d
     where t.entity_type = 'dish' and d.id = t.entity_id
    union all
    select 1 from public.drinks dr
     where t.entity_type = 'drink' and dr.id = t.entity_id
  );

-- 2) DELETE — run after confirming the pre-count looks right.
delete from public.translations t
where t.entity_type in ('ingredient', 'dish', 'drink')
  and not exists (
    select 1 from public.ingredients i
     where t.entity_type = 'ingredient' and i.id = t.entity_id
    union all
    select 1 from public.dishes d
     where t.entity_type = 'dish' and d.id = t.entity_id
    union all
    select 1 from public.drinks dr
     where t.entity_type = 'drink' and dr.id = t.entity_id
  );
