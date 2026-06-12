-- Specification 010 §2.4 — backfill `media` from `dishes.photo_path` (Wave 1).
--
-- Each dish with a single main photo becomes one media row at position 0,
-- keeping the existing object path (`{dish_id}.jpg` in the `dish-photos`
-- bucket). The `dishes.photo_path` column is left intact for now; Wave 2 drops
-- it after a validated release cycle.
--
-- Idempotent: skips dishes already mirrored into media (same entity + path).

insert into public.media (entity_type, entity_id, path, position, created_at)
select 'dish', d.id, d.photo_path, 0, d.created_at
from public.dishes d
where d.photo_path is not null
  and not exists (
    select 1 from public.media m
    where m.entity_type = 'dish'
      and m.entity_id = d.id
      and m.path = d.photo_path
  );
