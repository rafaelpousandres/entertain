-- Spec 011 §2.11 — "extra" ingredients in the shopping panel.
--
-- Extras are items the cook adds to a supplier's order that are not part of any
-- dish (e.g. "since I'm calling the greengrocer, also order spinach for the
-- week"). They are held on an automatically-created, per-event phantom
-- `event_dishes` row marked with this flag, reusing the existing
-- `event_dish_ingredients` mechanism. The phantom dish is hidden from the Menu
-- tab and excluded from the event status / supplier counters; the flag is how
-- every read distinguishes it from a real menu dish.
--
-- Non-destructive: a new boolean column defaulting to FALSE, so every existing
-- row keeps its current (real-dish) meaning.

ALTER TABLE event_dishes
  ADD COLUMN is_extras BOOLEAN NOT NULL DEFAULT FALSE;
