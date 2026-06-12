-- Specification 010 §2.4 — backfill `media` from `ingredients.photo_path`
-- (Wave 1).
--
-- Each ingredient with a single main photo becomes one media row at position 0,
-- keeping the existing object path (`{ingredient_id}.jpg` in the
-- `ingredient-photos` bucket). The `ingredients.photo_path` column is left
-- intact for now; Wave 2 drops it after a validated release cycle.
--
-- Idempotent: skips ingredients already mirrored into media (same entity +
-- path).

insert into public.media (entity_type, entity_id, path, position, created_at)
select 'ingredient', i.id, i.photo_path, 0, i.created_at
from public.ingredients i
where i.photo_path is not null
  and not exists (
    select 1 from public.media m
    where m.entity_type = 'ingredient'
      and m.entity_id = i.id
      and m.path = i.photo_path
  );
