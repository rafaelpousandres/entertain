-- Specification 016 — prepared dishes & drinks refinements.
--
-- On-device validation of Spec 014 surfaced a model more complex than needed
-- and two bugs. Spec 014 was just published to Internal Testing with no real
-- data yet, so the column drops/adds below are safe (only test drinks may need
-- recreating). This migration MIXES drops and adds across four tables and also
-- fixes the media policy/trigger that Spec 014 forgot to extend for drinks.
--
-- Summary:
--   1. dishes        — drop purchase_unit, servings_per_unit. base_servings is
--                      reused as "servings one unit provides" for bought dishes.
--   2. event_dishes  — drop purchase_unit. Keep `servings` (to-serve, scales
--                      with the event) AND `servings_per_unit` (the per-unit
--                      snapshot taken at add time): both are needed so
--                      units = ceil(servings / servings_per_unit) is computable
--                      from the snapshot alone, without reading the live dish.
--                      servings_per_unit is NOT redundant here — on `dishes`
--                      the per-unit value lives in base_servings, but the event
--                      copy must freeze it independently (immutability).
--   3. drinks        — units-only model: drop base_servings, servings_per_unit,
--                      purchase_unit; add `denomination` (a code). A drink is
--                      name + supplier category + denomination + photo.
--   4. event_drinks  — units-only snapshot: drop servings, servings_per_unit,
--                      purchase_unit; add `quantity` (manual unit count, NO
--                      guest scaling) and snapshot `denomination`.
--   5. media         — fix the drink-photo bug: Spec 014 added the 'drink' enum
--                      value but never extended media_group_access (RLS) or
--                      media_validate_entity() (trigger), so a drink media row
--                      INSERT hit a CASE with no 'drink' branch (→ NULL →
--                      rejected). Recreate both with a 'drink' branch.

-- 1. dishes: drop the two bought-dish unit fields ------------------------
-- base_servings now doubles as "servings one bought unit provides" (Truita=4 →
-- one truita serves 4). Same column, same concept for cooked and bought.
alter table public.dishes
  drop column if exists purchase_unit,
  drop column if exists servings_per_unit;

-- 2. event_dishes: drop purchase_unit; keep servings + servings_per_unit --
alter table public.event_dishes
  drop column if exists purchase_unit;

-- 3. drinks: units-only model -------------------------------------------
alter table public.drinks
  drop column if exists base_servings,
  drop column if exists servings_per_unit,
  drop column if exists purchase_unit,
  add column if not exists denomination text not null default 'bottle';

-- 4. event_drinks: units-only snapshot (manual quantity, no scaling) ------
alter table public.event_drinks
  drop column if exists servings,
  drop column if exists servings_per_unit,
  drop column if exists purchase_unit,
  add column if not exists quantity     integer not null default 1,
  add column if not exists denomination text    not null default 'bottle';

-- 5. media: add the missing 'drink' branch to the RLS policy + trigger ----
-- The 'drink' enum value already exists (added by 20260617030000). Only the
-- consumers were missed. This block touches public.media only (NOT
-- storage.objects), so `supabase db push` has the privilege — no dashboard step.

drop policy if exists media_group_access on public.media;
create policy media_group_access on public.media
  for all to authenticated
  using (
    case entity_type
      when 'event' then exists (
        select 1 from public.events e
        where e.id = media.entity_id and public.is_group_member(e.group_id)
      )
      when 'dish' then exists (
        select 1 from public.dishes d
        where d.id = media.entity_id and public.is_group_member(d.group_id)
      )
      when 'ingredient' then exists (
        select 1 from public.ingredients i
        where i.id = media.entity_id and public.is_group_member(i.group_id)
      )
      when 'drink' then exists (
        select 1 from public.drinks dr
        where dr.id = media.entity_id and public.is_group_member(dr.group_id)
      )
    end
  )
  with check (
    case entity_type
      when 'event' then exists (
        select 1 from public.events e
        where e.id = media.entity_id and public.is_group_member(e.group_id)
      )
      when 'dish' then exists (
        select 1 from public.dishes d
        where d.id = media.entity_id and public.is_group_member(d.group_id)
      )
      when 'ingredient' then exists (
        select 1 from public.ingredients i
        where i.id = media.entity_id and public.is_group_member(i.group_id)
      )
      when 'drink' then exists (
        select 1 from public.drinks dr
        where dr.id = media.entity_id and public.is_group_member(dr.group_id)
      )
    end
  );

create or replace function public.media_validate_entity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (
    case new.entity_type
      when 'event' then exists (select 1 from public.events where id = new.entity_id)
      when 'dish' then exists (select 1 from public.dishes where id = new.entity_id)
      when 'ingredient' then exists (select 1 from public.ingredients where id = new.entity_id)
      when 'drink' then exists (select 1 from public.drinks where id = new.entity_id)
    end
  ) then
    raise exception 'media.entity_id % does not reference an existing %',
      new.entity_id, new.entity_type;
  end if;
  return new;
end;
$$;

-- Cleanup-on-delete safety net for drinks (mirrors dishes/ingredients). Drinks
-- are soft-deleted by the app, so this fires only on a genuine hard DELETE.
drop trigger if exists trg_media_cleanup_drinks on public.drinks;
create trigger trg_media_cleanup_drinks
  after delete on public.drinks
  for each row execute function public.media_cleanup_for_entity('drink');
