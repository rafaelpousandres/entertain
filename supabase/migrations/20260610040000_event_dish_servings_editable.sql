-- Specification 008 — §2.10: editable servings per event-dish, with ingredient
-- quantities that scale to the servings.
--
-- `event_dishes.servings` already exists and has no constraint preventing
-- updates, so it is editable as-is — no change needed there.
--
-- What is missing is a stable *reference* for scaling. The model decided with
-- the project owner is "immutable base + scale on display":
--
--   * `event_dish_ingredients.quantity` stays the immutable base quantity —
--     the master recipe quantity for an inherited line, or the quantity the
--     user typed for an ad-hoc line at the servings in force when they added it.
--   * `reference_servings` records the servings that base quantity is expressed
--     for (the master dish's `base_servings` for inherited lines; the event
--     dish's `servings` at creation for ad-hoc lines).
--
-- The effective quantity shown everywhere (dish detail, shopping panel, order
-- snapshot, line editor) is then computed at read time as
--     ceil_to_scale(quantity / reference_servings * event_dishes.servings)
-- so changing the servings rescales every line losslessly with no write, and a
-- round-trip (e.g. 4 → 6 → 4) returns the exact original values.
--
-- Backfill: set every existing line's reference to its own event-dish's current
-- servings, so the effective quantity equals the stored quantity (factor 1) and
-- nothing the user already entered changes on upgrade. New copies and new
-- ad-hoc lines set the reference explicitly from the application.
alter table public.event_dish_ingredients
  add column reference_servings integer;

update public.event_dish_ingredients edi
set reference_servings = ed.servings
from public.event_dishes ed
where edi.event_dish_id = ed.id
  and edi.reference_servings is null;
