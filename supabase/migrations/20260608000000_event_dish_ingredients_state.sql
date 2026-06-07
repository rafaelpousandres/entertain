-- Specification 007 (Phase 7B) — ingredient state machine.
--
-- Each `event_dish_ingredients` row gains an explicit `state` tracking where
-- the ingredient is in the user's shopping process (data model: a state column
-- on the per-event line, not a dynamic pantry — that is Phase 1). The five
-- states and their meaning (Spec §3.1):
--
--   at_home   — already in the user's pantry / kitchen.
--   to_order  — needs to be ordered or bought.
--   ordered   — a supplier message has been sent for it.
--   received  — delivered or bought, now in the kitchen.
--   missing   — should have been ordered/bought but isn't (late alarm).
--
-- Default (Spec §3.1): `to_order` for new lines, `at_home` for lines whose
-- resolved supplier category is the system Rebost (`code = 'pantry'`). A plain
-- column default can only be a constant, so the conditional pantry default is
-- applied by a BEFORE INSERT trigger: when a line is inserted with the default
-- `to_order` and its category resolves to pantry, the trigger flips it to
-- `at_home`. This keeps the rule in one place regardless of the insert site
-- (bulk copy-on-add or single ad-hoc line) and decouples the client from
-- having to know the pantry category id.

create type public.ingredient_state as enum
  ('at_home', 'to_order', 'ordered', 'received', 'missing');

alter table public.event_dish_ingredients
  add column state public.ingredient_state not null default 'to_order';

-- Conditional pantry default: only acts at creation time, only when the state
-- is still the inserted default `to_order`, so it never overrides a state the
-- application sets explicitly (e.g. a future seeded `ordered`).
create or replace function public.event_dish_ingredient_default_state()
returns trigger
language plpgsql
as $$
begin
  if new.state = 'to_order' and new.supplier_category_id is not null then
    if exists (
      select 1
      from public.supplier_categories sc
      where sc.id = new.supplier_category_id
        and sc.code = 'pantry'
    ) then
      new.state := 'at_home';
    end if;
  end if;
  return new;
end;
$$;

create trigger event_dish_ingredient_default_state
  before insert on public.event_dish_ingredients
  for each row
  execute function public.event_dish_ingredient_default_state();
