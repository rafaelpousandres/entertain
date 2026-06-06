-- Specification 006 — Polish round §2.1: a dedicated preparation field on dishes.
--
-- `dishes.description` is a one-line subtitle / brief identification of the dish
-- and is unsuited for multi-line cooking instructions. This adds a separate,
-- nullable, free-format `preparation` column for the actual recipe. The two are
-- distinct and both kept:
--   * description — one-line short text (unchanged).
--   * preparation — the multi-line recipe / cooking instructions.
--
-- No data migration is needed: the column is new and `description` is preserved
-- unchanged. The recipe is intentionally NOT snapshotted onto `event_dishes`;
-- the per-event dish detail reads it live from the catalog dish via
-- `event_dishes.source_dish_id`, so cooks always see the latest version.
alter table public.dishes
  add column preparation text;
