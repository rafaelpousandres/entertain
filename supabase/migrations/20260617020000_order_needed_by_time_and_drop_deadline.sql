-- Specification 015 — minor polish batch (two order-column changes).
--
-- One file, two clearly-separated changes on `public.orders`:
--
--   §1 (additive): an OPTIONAL time on the needed-by date. `needed_by_date`
--       (a `date`) stays the active field; the new `needed_by_time` (a `time`)
--       is nullable and its nullability IS the flag — null means "date only",
--       a value means "date + time". No extra boolean.
--
--   §4 (destructive, but safe): drop the dead `delivery_deadline` column. It is
--       a Phase 0 leftover (`text`), always null, superseded by
--       `needed_by_date`, and read/written by no application code (verified
--       across lib/ and test/). Dropping an empty column loses no data; shown
--       before push per house rule.
--
-- Deliberately NOT touched: `orders.message_header` / `orders.message_footer`
-- (latent per-order message override) and `ingredients.package_equiv_unit_id`
-- (latent, for the future URL importer) — intentionally empty, not dead.

-- §1 — optional time alongside the needed-by date.
alter table public.orders
  add column needed_by_time time;

-- §4 — remove the dead delivery_deadline column.
alter table public.orders
  drop column delivery_deadline;
