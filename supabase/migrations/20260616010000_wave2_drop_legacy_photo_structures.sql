-- Spec 011 §2.2 + §2.3 — Wave 2 cleanup of the Spec 010 media migration.
--
-- Spec 010 §2.4 introduced the polymorphic `media` table and backfilled every
-- existing photo into it (Wave 1). The legacy structures were intentionally
-- kept for one full release cycle as rollback markers:
--   * `event_photos`            — the per-event photo album table (Spec 009).
--   * `dishes.photo_path`       — the single-photo column on dishes.
--   * `ingredients.photo_path`  — the single-photo column on ingredients.
-- Plus two orphan enums from an earlier Phase 0 media design, never used by any
-- live table or by the app:
--   * `media_owner_type`
--   * `media_kind`
--
-- Spec 010 is now validated in real-use Internal Testing (photos display
-- correctly from `media`), so these are safe to drop. The app references none of
-- them (verified by grep — only stale comments remained). The Wave 1 backfills
-- already copied the data into `media`, so dropping the sources loses nothing.

BEGIN;

-- §2.2 — drop the legacy photo structures.
DROP TABLE IF EXISTS event_photos;

ALTER TABLE dishes DROP COLUMN IF EXISTS photo_path;
ALTER TABLE ingredients DROP COLUMN IF EXISTS photo_path;

-- §2.3 — drop the orphan enums (no column or code uses them).
DROP TYPE IF EXISTS media_owner_type;
DROP TYPE IF EXISTS media_kind;

COMMIT;
