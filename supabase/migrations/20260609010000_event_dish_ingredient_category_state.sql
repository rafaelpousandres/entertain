-- Specification 007 — Fixes §2.5: adjust an ingredient line's state when its
-- supplier category changes to or from the system Rebost (`code = 'pantry'`).
--
-- The per-event line editor lets the user re-assign `supplier_category_id`.
-- Moving a line into the pantry should make it a pantry staple ("A casa");
-- moving it out should put it back in the ordering flow ("Per demanar"). A
-- `missing` line keeps its alarm in both directions (the staple/order is still
-- needed regardless of category).
--
-- This is a BEFORE UPDATE trigger, mirroring the BEFORE INSERT default-state
-- trigger from Phase 7B (20260608000000): it keeps the category→state rule in
-- one place, independent of the call site, so the client editor needs no
-- knowledge of the pantry category id.

create or replace function public.event_dish_ingredient_category_state()
returns trigger
language plpgsql
as $$
declare
  new_is_pantry boolean := false;
begin
  -- Only act when the category actually changes; a plain field edit (quantity,
  -- prep note, …) must never disturb the state.
  if new.supplier_category_id is distinct from old.supplier_category_id then
    if new.supplier_category_id is not null then
      select exists (
        select 1
        from public.supplier_categories sc
        where sc.id = new.supplier_category_id
          and sc.code = 'pantry'
      ) into new_is_pantry;
    end if;

    if new_is_pantry then
      -- Into the pantry: an active-ordering state becomes "at home"; a missing
      -- staple stays flagged.
      if new.state in ('to_order', 'ordered', 'received') then
        new.state := 'at_home';
      end if;
    else
      -- Out of the pantry (another category or none): a pantry staple re-enters
      -- the ordering flow; a missing line stays flagged.
      if new.state = 'at_home' then
        new.state := 'to_order';
      end if;
    end if;
  end if;
  return new;
end;
$$;

create trigger event_dish_ingredient_category_state
  before update on public.event_dish_ingredients
  for each row
  execute function public.event_dish_ingredient_category_state();
