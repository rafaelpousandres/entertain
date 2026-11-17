-- ============================================================================
-- Demo dataset — capital initial on catalog names and their translations
--
-- The demo TEMPLATE group's ingredient names were stored with a lowercase
-- initial ("yellow onion"), and so were their ca/es/en translations (the
-- backfill preserves the source's initial case). Every account's demo copy
-- inherited them, while names typed in the app start with a capital. This
-- uppercases the FIRST character only, in:
--   1. each account's demo COPIES of the template's ingredients, dishes and
--      drinks, and the copies' name translations;
--   2. the TEMPLATE's own rows and translations (so new accounts are born
--      capitalised — seed_demo clones the template).
--
-- DATA MIGRATION — updates existing rows; creates and deletes nothing.
--
-- WHAT IS LEFT ALONE
--   • Anything that is not a demo copy. A copy is recognised by its
--     deterministic id (_demo_clone_id(group, template id)), not by a flag.
--   • A copy whose value no longer equals the template's value: the user (or a
--     re-translation after a rename) changed it, so it is theirs. Hence copies
--     are processed BEFORE the template rows they are compared against.
--   • Values that do not start with a lowercase letter ("00 flour").
--   • Name snapshots on event / shopping lines (out of scope here).
--
-- One DO block = one transaction: the closing assertion aborts everything if
-- the template is not fully capitalised afterwards.
-- ============================================================================

do $$
declare
  v_template constant uuid := '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52';
  v_n bigint;
  v_total bigint := 0;
  v_left bigint;
begin
  -- Template entities and their name translations, as they are BEFORE any change.
  create temp table _tpl on commit drop as
    select 'ingredient'::public.translation_entity_type as etype, id, name
      from public.ingredients where group_id = v_template
    union all
    select 'dish'::public.translation_entity_type, id, name
      from public.dishes where group_id = v_template
    union all
    select 'drink'::public.translation_entity_type, id, name
      from public.drinks where group_id = v_template;

  create temp table _tpl_tr on commit drop as
    select t.entity_type as etype, t.entity_id as id, t.locale, t.text
      from public.translations t
      join _tpl on _tpl.etype = t.entity_type and _tpl.id = t.entity_id
     where t.field = 'name';

  -- ── 1. Demo copies: translations first (they need the copy's id only) ─────
  update public.translations t
     set text = upper(left(t.text, 1)) || substr(t.text, 2)
    from (
      select 'ingredient'::public.translation_entity_type as etype, c.id, _tpl.id as tpl_id
        from public.ingredients c join _tpl on _tpl.etype = 'ingredient'
         and c.id = public._demo_clone_id(c.group_id, _tpl.id)
       where c.group_id <> v_template
      union all
      select 'dish'::public.translation_entity_type, c.id, _tpl.id
        from public.dishes c join _tpl on _tpl.etype = 'dish'
         and c.id = public._demo_clone_id(c.group_id, _tpl.id)
       where c.group_id <> v_template
      union all
      select 'drink'::public.translation_entity_type, c.id, _tpl.id
        from public.drinks c join _tpl on _tpl.etype = 'drink'
         and c.id = public._demo_clone_id(c.group_id, _tpl.id)
       where c.group_id <> v_template
    ) c
    join _tpl_tr tt on tt.etype = c.etype and tt.id = c.tpl_id
   where t.entity_type = c.etype and t.entity_id = c.id and t.field = 'name'
     and t.locale = tt.locale
     and t.text = tt.text
     and left(t.text, 1) <> upper(left(t.text, 1));
  get diagnostics v_n = row_count; v_total := v_total + v_n;
  raise notice 'demo copies — translations capitalised: %', v_n;

  update public.ingredients c
     set name = upper(left(c.name, 1)) || substr(c.name, 2)
    from _tpl
   where _tpl.etype = 'ingredient' and c.group_id <> v_template
     and c.id = public._demo_clone_id(c.group_id, _tpl.id)
     and c.name = _tpl.name
     and left(c.name, 1) <> upper(left(c.name, 1));
  get diagnostics v_n = row_count; v_total := v_total + v_n;
  raise notice 'demo copies — ingredients capitalised: %', v_n;

  update public.dishes c
     set name = upper(left(c.name, 1)) || substr(c.name, 2)
    from _tpl
   where _tpl.etype = 'dish' and c.group_id <> v_template
     and c.id = public._demo_clone_id(c.group_id, _tpl.id)
     and c.name = _tpl.name
     and left(c.name, 1) <> upper(left(c.name, 1));
  get diagnostics v_n = row_count; v_total := v_total + v_n;
  raise notice 'demo copies — dishes capitalised: %', v_n;

  update public.drinks c
     set name = upper(left(c.name, 1)) || substr(c.name, 2)
    from _tpl
   where _tpl.etype = 'drink' and c.group_id <> v_template
     and c.id = public._demo_clone_id(c.group_id, _tpl.id)
     and c.name = _tpl.name
     and left(c.name, 1) <> upper(left(c.name, 1));
  get diagnostics v_n = row_count; v_total := v_total + v_n;
  raise notice 'demo copies — drinks capitalised: %', v_n;

  -- ── 2. The template itself ───────────────────────────────────────────────
  update public.translations t
     set text = upper(left(t.text, 1)) || substr(t.text, 2)
    from _tpl
   where t.entity_type = _tpl.etype and t.entity_id = _tpl.id and t.field = 'name'
     and left(t.text, 1) <> upper(left(t.text, 1));
  get diagnostics v_n = row_count; v_total := v_total + v_n;
  raise notice 'template — translations capitalised: %', v_n;

  update public.ingredients set name = upper(left(name, 1)) || substr(name, 2)
   where group_id = v_template and left(name, 1) <> upper(left(name, 1));
  get diagnostics v_n = row_count; v_total := v_total + v_n;
  raise notice 'template — ingredients capitalised: %', v_n;

  update public.dishes set name = upper(left(name, 1)) || substr(name, 2)
   where group_id = v_template and left(name, 1) <> upper(left(name, 1));
  get diagnostics v_n = row_count; v_total := v_total + v_n;

  update public.drinks set name = upper(left(name, 1)) || substr(name, 2)
   where group_id = v_template and left(name, 1) <> upper(left(name, 1));
  get diagnostics v_n = row_count; v_total := v_total + v_n;

  raise notice 'TOTAL rows capitalised: %', v_total;

  -- ── Fail closed: the template must be fully capitalised now ──────────────
  select count(*) into v_left from (
    select name as v from public.ingredients where group_id = v_template
    union all select name from public.dishes where group_id = v_template
    union all select name from public.drinks where group_id = v_template
    union all
    select t.text from public.translations t
      join _tpl on _tpl.etype = t.entity_type and _tpl.id = t.entity_id
     where t.field = 'name'
  ) x where left(x.v, 1) <> upper(left(x.v, 1));
  if v_left > 0 then
    raise exception 'demo capitalisation incomplete: % template values still start lowercase', v_left;
  end if;
end;
$$;
