-- ============================================================================
-- Demo events — name copies on the event lines in the account's language
--
-- PROBLEM
--   Each line of a demo event keeps a COPY of the name of its dish, ingredient
--   or drink (event_dishes.dish_name, event_dish_ingredients.ingredient_name,
--   event_drinks.drink_name). seed_demo copied them verbatim from the English
--   template, so a Catalan or Spanish account sees its demo events in English,
--   and the ingredient copies start with a lowercase letter in every account.
--
-- WHAT THIS DOES
--   1. DATA: rewrites those copies, for existing accounts, to the account's
--      language, using the template's existing name translations, with a
--      capital initial.
--   2. FUNCTION: seed_demo's internal clone (_seed_demo_into) now writes the
--      copies already translated, through the new helper _demo_line_name, so
--      new accounts are born right.
--
-- WHAT IS LEFT ALONE
--   • Any line whose copy is no longer identical to the template's (the user
--     edited it), and any line the user added: it is theirs.
--   • Accounts whose language cannot be established (see _acc below).
--   • The template itself, the catalog (names and translations), order items,
--     and every non-demo row.
--   • A line whose source has no translation in the account's language.
--
-- DATA MIGRATION + one function replaced + one function added. No table,
-- column or policy changes. Creates and deletes no rows.
-- Rollback: supabase/rollbacks/20261118000200_demo_event_names_localize_rollback.sql
-- ============================================================================

-- The name a demo event line must carry: the template entity's name translation
-- in the given language (for English, falling back to the entity's own name),
-- with a capital initial. Returns p_fallback when there is nothing to translate
-- from (no source entity, or no translation in that language).
create or replace function public._demo_line_name(
  p_type public.translation_entity_type,
  p_entity uuid,
  p_locale public.profile_locale,
  p_fallback text
)
returns text
language sql
stable
set search_path = public
as $$
  select coalesce(
    (select upper(left(x.v, 1)) || substr(x.v, 2)
       from (
         select coalesce(
           (select t.text from public.translations t
             where t.entity_type = p_type and t.entity_id = p_entity
               and t.field = 'name' and t.locale = p_locale),
           case when p_locale = 'en' then
             case p_type
               when 'dish'       then (select d.name from public.dishes d where d.id = p_entity)
               when 'ingredient' then (select i.name from public.ingredients i where i.id = p_entity)
               when 'drink'      then (select k.name from public.drinks k where k.id = p_entity)
             end
           end
         ) as v
       ) x
      where x.v is not null and x.v <> ''),
    p_fallback)
$$;

revoke all on function public._demo_line_name(public.translation_entity_type, uuid, public.profile_locale, text) from public;

-- New accounts: the clone writes the event-line name copies already translated.
-- Identical to the 20260704000200 definition except for the three name copies.
create or replace function public._seed_demo_into(v_group uuid, v_template uuid, v_locale public.profile_locale)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- ── Suppliers (custom categories + their order-channel settings) ──────────
  insert into public.supplier_categories (id, group_id, code, is_system, name, is_demo)
  select public._demo_clone_id(v_group, sc.id), v_group, sc.code, false, sc.name, true
  from public.supplier_categories sc
  where sc.group_id = v_template;

  insert into public.group_supplier_settings
    (group_id, supplier_category_id, channel, channel_address, phone_address,
     email_address, supplier_name, is_default, is_demo)
  select v_group,
         public._demo_remap_sc(v_group, v_template, gss.supplier_category_id),
         gss.channel, gss.channel_address, gss.phone_address, gss.email_address,
         gss.supplier_name, gss.is_default, true
  from public.group_supplier_settings gss
  where gss.group_id = v_template;

  -- ── Catalog: ingredients, dishes (+ recipes), drinks ─────────────────────
  insert into public.ingredients
    (id, group_id, name, default_unit_id, default_supplier_category_id, prep_description,
     package_equiv_value, package_equiv_unit_id, is_system, original_locale, diet, gluten_free, is_demo)
  select public._demo_clone_id(v_group, i.id), v_group, i.name, i.default_unit_id,
         public._demo_remap_sc(v_group, v_template, i.default_supplier_category_id),
         i.prep_description, i.package_equiv_value, i.package_equiv_unit_id,
         false, i.original_locale, i.diet, i.gluten_free, true
  from public.ingredients i
  where i.group_id = v_template and i.deleted_at is null;

  insert into public.dishes
    (id, group_id, name, category, base_servings, description, preparation, acquisition_mode,
     supplier_category_id, original_locale, diet, gluten_free, is_demo)
  select public._demo_clone_id(v_group, d.id), v_group, d.name, d.category, d.base_servings,
         d.description, d.preparation, d.acquisition_mode,
         public._demo_remap_sc(v_group, v_template, d.supplier_category_id),
         d.original_locale, d.diet, d.gluten_free, true
  from public.dishes d
  where d.group_id = v_template and d.deleted_at is null;

  insert into public.dish_ingredients
    (dish_id, ingredient_id, quantity, unit_id, prep_note, sort_order, is_demo)
  select public._demo_clone_id(v_group, di.dish_id),
         public._demo_clone_id(v_group, di.ingredient_id),
         di.quantity, di.unit_id, di.prep_note, di.sort_order, true
  from public.dish_ingredients di
  join public.dishes d on d.id = di.dish_id
  where d.group_id = v_template and d.deleted_at is null;

  insert into public.drinks
    (id, group_id, name, supplier_category_id, denomination, original_locale, is_demo)
  select public._demo_clone_id(v_group, dr.id), v_group, dr.name,
         public._demo_remap_sc(v_group, v_template, dr.supplier_category_id),
         dr.denomination, dr.original_locale, true
  from public.drinks dr
  where dr.group_id = v_template;

  -- ── Events (localised title/location; future event date refreshed) ───────
  -- The dish / ingredient / drink NAME COPIES on the event lines are written in
  -- the account's language (_demo_line_name), so a new account is born translated.
  insert into public.events
    (id, group_id, title, type, format, event_date, event_time, location_name, address,
     latitude, longitude, guest_count, notes, invitation_text, demo_key, is_demo)
  select public._demo_clone_id(v_group, e.id), v_group,
         coalesce(i18.title, e.title), e.type, e.format,
         case when e.demo_key = 'summer' then current_date + 7 else e.event_date end,
         e.event_time, coalesce(i18.location_name, e.location_name),
         e.address, e.latitude, e.longitude, e.guest_count, e.notes, e.invitation_text,
         e.demo_key, true
  from public.events e
  left join public.demo_event_i18n i18
    on i18.demo_key = e.demo_key and i18.locale = v_locale
  where e.group_id = v_template and e.deleted_at is null;

  insert into public.event_dishes
    (id, event_id, source_dish_id, dish_name, category, servings, sort_order, is_extras,
     acquisition_mode, supplier_category_id, servings_per_unit, state, is_demo)
  select public._demo_clone_id(v_group, ed.id),
         public._demo_clone_id(v_group, ed.event_id),
         case when ed.source_dish_id is null then null
              else public._demo_clone_id(v_group, ed.source_dish_id) end,
         public._demo_line_name('dish', ed.source_dish_id, v_locale, ed.dish_name),
         ed.category, ed.servings, ed.sort_order, ed.is_extras,
         ed.acquisition_mode,
         public._demo_remap_sc(v_group, v_template, ed.supplier_category_id),
         ed.servings_per_unit, ed.state, true
  from public.event_dishes ed
  join public.events e on e.id = ed.event_id
  where e.group_id = v_template and e.deleted_at is null;

  insert into public.event_dish_ingredients
    (event_dish_id, ingredient_id, ingredient_name, quantity, unit_id, prep_note,
     supplier_category_id, sort_order, state, reference_servings, is_demo)
  select public._demo_clone_id(v_group, edi.event_dish_id),
         case when edi.ingredient_id is null then null
              else public._demo_clone_id(v_group, edi.ingredient_id) end,
         public._demo_line_name('ingredient', edi.ingredient_id, v_locale, edi.ingredient_name),
         edi.quantity, edi.unit_id, edi.prep_note,
         public._demo_remap_sc(v_group, v_template, edi.supplier_category_id),
         edi.sort_order, edi.state, edi.reference_servings, true
  from public.event_dish_ingredients edi
  join public.event_dishes ed on ed.id = edi.event_dish_id
  join public.events e on e.id = ed.event_id
  where e.group_id = v_template and e.deleted_at is null;

  insert into public.event_drinks
    (event_id, source_drink_id, drink_name, supplier_category_id, state, sort_order,
     quantity, denomination, is_demo)
  select public._demo_clone_id(v_group, edk.event_id),
         case when edk.source_drink_id is null then null
              else public._demo_clone_id(v_group, edk.source_drink_id) end,
         public._demo_line_name('drink', edk.source_drink_id, v_locale, edk.drink_name),
         public._demo_remap_sc(v_group, v_template, edk.supplier_category_id),
         edk.state, edk.sort_order, edk.quantity, edk.denomination, true
  from public.event_drinks edk
  join public.events e on e.id = edk.event_id
  where e.group_id = v_template and e.deleted_at is null;

  insert into public.event_guests
    (event_id, group_id, name, phone, email, state, invited_at,
     diet_vegetarian, diet_vegan, diet_gluten_free, is_demo)
  select public._demo_clone_id(v_group, g.event_id), v_group, g.name, g.phone, g.email,
         g.state, g.invited_at, g.diet_vegetarian, g.diet_vegan, g.diet_gluten_free, true
  from public.event_guests g
  join public.events e on e.id = g.event_id
  where e.group_id = v_template and e.deleted_at is null;

  -- ── Catalog name translations (so the clone shows in the phone language) ──
  insert into public.translations (entity_type, entity_id, locale, field, text)
  select t.entity_type, public._demo_clone_id(v_group, t.entity_id), t.locale, t.field, t.text
  from public.translations t
  where (t.entity_type = 'ingredient' and t.entity_id in (select id from public.ingredients where group_id = v_template and deleted_at is null))
     or (t.entity_type = 'dish'       and t.entity_id in (select id from public.dishes      where group_id = v_template and deleted_at is null))
     or (t.entity_type = 'drink'      and t.entity_id in (select id from public.drinks      where group_id = v_template));

  -- ── Media: reference the shared read-only demo blobs (demo/{mediaRowId}.jpg) ──
  -- Keyed by the template MEDIA ROW id (not entity id): some entities have a
  -- multi-photo carousel, so the blob must be unique per photo.
  insert into public.media
    (entity_type, entity_id, path, position, source_provider, source_author, source_url, source_ref, is_demo)
  select me.entity_type, public._demo_clone_id(v_group, me.entity_id),
         'demo/' || me.id::text || '.jpg', me.position,
         me.source_provider, me.source_author, me.source_url, me.source_ref, true
  from public.media me
  where (me.entity_type = 'ingredient' and me.entity_id in (select id from public.ingredients where group_id = v_template and deleted_at is null))
     or (me.entity_type = 'dish'       and me.entity_id in (select id from public.dishes      where group_id = v_template and deleted_at is null))
     or (me.entity_type = 'drink'      and me.entity_id in (select id from public.drinks      where group_id = v_template))
     or (me.entity_type = 'event'      and me.entity_id in (select id from public.events      where group_id = v_template and deleted_at is null));

end;
$$;

revoke all on function public._seed_demo_into(uuid, uuid, public.profile_locale) from public;

-- ── Existing accounts ───────────────────────────────────────────────────────
-- One DO block = one transaction: the closing assertion aborts everything if
-- any line that should have been rewritten is still pending.
do $$
declare
  v_template constant uuid := '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52';
  v_n bigint;
  v_total bigint := 0;
  v_left bigint;
begin
  -- Accounts and their language. The language is the one the account was
  -- seeded in: the demo event titles were written in it at creation time
  -- (profiles.locale is a never-updated default, so it cannot be used). An
  -- account whose demo events are all gone or renamed has no known language
  -- and is left alone; so is one whose events disagree.
  create temp table _acc on commit drop as
    select x.group_id, (x.locs[1])::public.profile_locale as locale
    from (
      select ce.group_id, array_agg(distinct i.locale::text) as locs
        from public.events ce
        join public.events te on te.group_id = v_template and te.demo_key is not null
         and ce.id = public._demo_clone_id(ce.group_id, te.id)
        join public.demo_event_i18n i on i.demo_key = te.demo_key and i.title = ce.title
       where ce.is_demo and ce.group_id <> v_template
       group by ce.group_id
    ) x
    where cardinality(x.locs) = 1;

  -- Template event lines (the values every copy started from).
  create temp table _tpl_ed on commit drop as
    select ed.id, ed.source_dish_id, ed.dish_name
      from public.event_dishes ed
      join public.events e on e.id = ed.event_id
     where e.group_id = v_template;

  -- ── Dishes: a copy has the deterministic id of its template line ─────────
  update public.event_dishes c
     set dish_name = public._demo_line_name('dish', t.source_dish_id, a.locale, null)
    from _acc a cross join _tpl_ed t
   where c.id = public._demo_clone_id(a.group_id, t.id)
     and c.is_demo
     and c.dish_name = t.dish_name
     and public._demo_line_name('dish', t.source_dish_id, a.locale, null) is not null
     and public._demo_line_name('dish', t.source_dish_id, a.locale, null) <> c.dish_name;
  get diagnostics v_n = row_count; v_total := v_total + v_n;
  raise notice 'demo event lines — dish names rewritten: %', v_n;

  -- ── Ingredients: no deterministic id, so a copy is the demo line of the
  --    cloned dish line that points at the cloned ingredient ─────────────────
  update public.event_dish_ingredients c
     set ingredient_name = p.new_name
    from (
      select distinct a.group_id, t.id as tpl_ed_id, ti.ingredient_id, ti.ingredient_name,
             public._demo_line_name('ingredient', ti.ingredient_id, a.locale, null) as new_name
        from _acc a cross join _tpl_ed t
        join public.event_dish_ingredients ti on ti.event_dish_id = t.id
       where ti.ingredient_id is not null
    ) p
   where c.event_dish_id = public._demo_clone_id(p.group_id, p.tpl_ed_id)
     and c.ingredient_id = public._demo_clone_id(p.group_id, p.ingredient_id)
     and c.is_demo
     and c.ingredient_name = p.ingredient_name
     and p.new_name is not null
     and p.new_name <> c.ingredient_name;
  get diagnostics v_n = row_count; v_total := v_total + v_n;
  raise notice 'demo event lines — ingredient names rewritten: %', v_n;

  -- ── Drinks: same identification, through the cloned event and drink ───────
  update public.event_drinks c
     set drink_name = p.new_name
    from (
      select distinct a.group_id, te.id as tpl_event_id, tk.source_drink_id, tk.drink_name,
             public._demo_line_name('drink', tk.source_drink_id, a.locale, null) as new_name
        from _acc a
        join public.events te on te.group_id = v_template
        join public.event_drinks tk on tk.event_id = te.id
       where tk.source_drink_id is not null
    ) p
   where c.event_id = public._demo_clone_id(p.group_id, p.tpl_event_id)
     and c.source_drink_id = public._demo_clone_id(p.group_id, p.source_drink_id)
     and c.is_demo
     and c.drink_name = p.drink_name
     and p.new_name is not null
     and p.new_name <> c.drink_name;
  get diagnostics v_n = row_count; v_total := v_total + v_n;
  raise notice 'demo event lines — drink names rewritten: %', v_n;

  raise notice 'TOTAL demo event line names rewritten: % (accounts with a known language: %)',
    v_total, (select count(*) from _acc);

  -- ── Fail closed: nothing identical to the template may still be pending ───
  select
    (select count(*) from public.event_dishes c, _acc a, _tpl_ed t
      where c.id = public._demo_clone_id(a.group_id, t.id) and c.is_demo
        and c.dish_name = t.dish_name
        and public._demo_line_name('dish', t.source_dish_id, a.locale, null) is not null
        and public._demo_line_name('dish', t.source_dish_id, a.locale, null) <> c.dish_name)
    +
    (select count(*) from public.event_dish_ingredients c, _acc a, _tpl_ed t,
            public.event_dish_ingredients ti
      where ti.event_dish_id = t.id and ti.ingredient_id is not null
        and c.event_dish_id = public._demo_clone_id(a.group_id, t.id)
        and c.ingredient_id = public._demo_clone_id(a.group_id, ti.ingredient_id)
        and c.is_demo and c.ingredient_name = ti.ingredient_name
        and public._demo_line_name('ingredient', ti.ingredient_id, a.locale, null) is not null
        and public._demo_line_name('ingredient', ti.ingredient_id, a.locale, null) <> c.ingredient_name)
    +
    (select count(*) from public.event_drinks c, _acc a, public.events te, public.event_drinks tk
      where te.group_id = v_template and tk.event_id = te.id and tk.source_drink_id is not null
        and c.event_id = public._demo_clone_id(a.group_id, te.id)
        and c.source_drink_id = public._demo_clone_id(a.group_id, tk.source_drink_id)
        and c.is_demo and c.drink_name = tk.drink_name
        and public._demo_line_name('drink', tk.source_drink_id, a.locale, null) is not null
        and public._demo_line_name('drink', tk.source_drink_id, a.locale, null) <> c.drink_name)
    into v_left;
  if v_left > 0 then
    raise exception 'demo event names: % lines identical to the template are still untranslated', v_left;
  end if;
end;
$$;
