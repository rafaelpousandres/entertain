-- Specification 010 §2.4 — backfill `media` from `event_photos` (Wave 1).
--
-- One media row per existing event-photo album entry, preserving its path,
-- carousel position and created_at (the tiebreaker for equal positions). The
-- source `event_photos` table is left intact for now; Wave 2 drops it after a
-- validated release cycle.
--
-- Idempotent: skips event photos already mirrored into media (same entity +
-- path), so a re-run never duplicates.

insert into public.media (entity_type, entity_id, path, position, created_at)
select 'event', ep.event_id, ep.photo_path, ep.position, ep.created_at
from public.event_photos ep
where not exists (
  select 1 from public.media m
  where m.entity_type = 'event'
    and m.entity_id = ep.event_id
    and m.path = ep.photo_path
);
