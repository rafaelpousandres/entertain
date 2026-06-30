-- ============================================================================
-- Spec 033 §A.3/§A.5 — demo dataset clone + clear (M3)
--
-- Two SECURITY DEFINER RPCs the authenticated client calls:
--   • seed_demo(locale)  — clones the canonical demo TEMPLATE group into the
--     caller's group (new ids, is_demo=true, event titles/locations localised,
--     catalog translations copied, media rows referencing the shared read-only
--     demo/ blobs). One-shot, guarded by groups.demo_seeded_at.
--   • clear_demo_data()  — deletes EXACTLY the demo rows of the caller's group
--     (FK-safe), preserving anything the user created. Returns the user-owned
--     blob paths to purge (the shared demo/ assets are left untouched).
--
-- NON-DESTRUCTIVE to existing data: only adds two functions. seed_demo writes
-- only into the caller's own (brand-new) group; it never mutates the template
-- or any other group.
-- ============================================================================

-- Deterministic clone id: same (group, source id) → same uuid, so FK references
-- remap by recomputation (no mapping tables) and a guarded re-run can't collide.
create or replace function public._demo_clone_id(p_group uuid, p_old uuid)
returns uuid language sql immutable as $$
  select md5(p_group::text || ':' || p_old::text)::uuid
$$;

-- Remap a supplier_category_id: template CUSTOM categories (group-scoped) are
-- cloned, so point at the clone; SYSTEM categories (group_id null) and nulls are
-- shared/global and kept as-is.
create or replace function public._demo_remap_sc(p_group uuid, p_template uuid, p_sc uuid)
returns uuid language sql stable as $$
  select case
    when p_sc is null then null
    when exists (select 1 from public.supplier_categories sc
                 where sc.id = p_sc and sc.group_id = p_template)
      then public._demo_clone_id(p_group, p_sc)
    else p_sc
  end
$$;

create or replace function public.seed_demo(p_locale text default 'en')
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_template constant uuid := '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52';
  v_group uuid;
  v_locale public.profile_locale;
begin
  select m.group_id into v_group
  from public.memberships m
  where m.user_id = auth.uid()
  limit 1;
  if v_group is null then
    raise exception 'seed_demo: no membership for caller';
  end if;

  -- Never seed the template itself; one-shot per group.
  if v_group = v_template then return; end if;
  perform 1 from public.groups g where g.id = v_group and g.demo_seeded_at is not null;
  if found then return; end if;

  v_locale := case when p_locale in ('ca','es','en')
                   then p_locale::public.profile_locale else 'en'::public.profile_locale end;

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
         ed.dish_name, ed.category, ed.servings, ed.sort_order, ed.is_extras,
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
         edi.ingredient_name, edi.quantity, edi.unit_id, edi.prep_note,
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
         edk.drink_name,
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

  -- ── Media: reference the shared read-only demo blobs (demo/{templateId}.jpg) ──
  insert into public.media
    (entity_type, entity_id, path, position, source_provider, source_author, source_url, source_ref, is_demo)
  select me.entity_type, public._demo_clone_id(v_group, me.entity_id),
         'demo/' || me.entity_id::text || '.jpg', me.position,
         me.source_provider, me.source_author, me.source_url, me.source_ref, true
  from public.media me
  where (me.entity_type = 'ingredient' and me.entity_id in (select id from public.ingredients where group_id = v_template and deleted_at is null))
     or (me.entity_type = 'dish'       and me.entity_id in (select id from public.dishes      where group_id = v_template and deleted_at is null))
     or (me.entity_type = 'drink'      and me.entity_id in (select id from public.drinks      where group_id = v_template))
     or (me.entity_type = 'event'      and me.entity_id in (select id from public.events      where group_id = v_template and deleted_at is null));

  update public.groups set demo_seeded_at = now() where id = v_group;
end;
$$;

-- Helper: does a demo media row belong to one of this group's demo entities?
create or replace function public._demo_owns_media(p_group uuid, p_type public.media_entity_type, p_entity uuid)
returns boolean language sql stable as $$
  select case p_type
    when 'ingredient' then exists (select 1 from public.ingredients where id = p_entity and group_id = p_group and is_demo)
    when 'dish'       then exists (select 1 from public.dishes      where id = p_entity and group_id = p_group and is_demo)
    when 'drink'      then exists (select 1 from public.drinks      where id = p_entity and group_id = p_group and is_demo)
    when 'event'      then exists (select 1 from public.events      where id = p_entity and group_id = p_group and is_demo)
  end
$$;

create or replace function public.clear_demo_data()
returns table(bucket text, path text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group uuid;
begin
  select m.group_id into v_group
  from public.memberships m
  where m.user_id = auth.uid()
  limit 1;
  if v_group is null then
    raise exception 'clear_demo_data: no membership for caller';
  end if;

  -- User-owned blobs to purge: demo media the user REPLACED with their own photo
  -- (path no longer under the shared demo/ prefix). The shared demo/ assets are
  -- left in Storage for other users.
  create temp table _purge on commit drop as
  select case m.entity_type
           when 'ingredient' then 'ingredient-photos'
           when 'dish'       then 'dish-photos'
           when 'drink'      then 'drink-photos'
           when 'event'      then 'event-photos'
         end as bucket,
         m.path as path
  from public.media m
  where m.is_demo and m.path not like 'demo/%' and _demo_owns_media(v_group, m.entity_type, m.entity_id);

  -- Delete the demo media rows (shared demo/ blobs are never touched).
  delete from public.media m
  where m.is_demo and _demo_owns_media(v_group, m.entity_type, m.entity_id);

  -- Entities, FK-safe (children first). Hard delete: gone for good.
  delete from public.event_dish_ingredients edi
  where edi.is_demo and edi.event_dish_id in (
    select ed.id from public.event_dishes ed
    join public.events e on e.id = ed.event_id where e.group_id = v_group);
  delete from public.event_drinks ek
  where ek.is_demo and ek.event_id in (select id from public.events where group_id = v_group);
  delete from public.event_guests where is_demo and group_id = v_group;
  delete from public.event_dishes ed
  where ed.is_demo and ed.event_id in (select id from public.events where group_id = v_group);
  delete from public.events where is_demo and group_id = v_group;
  delete from public.dish_ingredients di
  where di.is_demo and di.dish_id in (select id from public.dishes where group_id = v_group);
  delete from public.dishes where is_demo and group_id = v_group;
  delete from public.drinks where is_demo and group_id = v_group;
  delete from public.group_supplier_settings where is_demo and group_id = v_group;
  delete from public.supplier_categories where is_demo and group_id = v_group;
  delete from public.ingredients where is_demo and group_id = v_group;
  -- Cloned name translations are removed by the Spec 026 orphan-translations
  -- trigger when their catalog entity is deleted above.

  return query select p.bucket, p.path from _purge p;
end;
$$;

revoke all on function public.seed_demo(text) from public;
revoke all on function public.clear_demo_data() from public;
grant execute on function public.seed_demo(text) to authenticated;
grant execute on function public.clear_demo_data() to authenticated;
