-- Specification 009 §2.2 — photos for dishes and ingredients.
--
-- Each catalog dish and each catalog ingredient gains an optional "main"
-- photo, stored in Supabase Storage (buckets created in
-- 20260612030000_create_photo_storage_buckets.sql). The row only holds the
-- relative object path inside the bucket; the bytes live in Storage.
--
-- Naming convention (Spec §2.2.1): the object is named after the owning row's
-- id — `{dish_id}.jpg` in `dish-photos`, `{ingredient_id}.jpg` in
-- `ingredient-photos` — so the path is fully derivable from the id and the
-- column merely records "a photo exists" (non-null) versus "no photo yet"
-- (null). Diverges deliberately from the data model's polymorphic `media`
-- table: for three entities with fixed cardinalities a per-row path is simpler
-- (Spec 009 §2.2.6).

alter table public.dishes
  add column photo_path text;

alter table public.ingredients
  add column photo_path text;
