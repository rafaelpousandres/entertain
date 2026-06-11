# Specification 010 — Post-Internal-Testing refinements

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read `CLAUDE.md`, `entertain - Data model.md`, and previous
> specifications (001 through 009 including their fixes rounds)
> before starting. This specification consolidates the work
> identified during real-use validation and the first wave of
> Internal Testing on the Pixel 8 Pro. It mixes one structural
> refactor (the polymorphic media table) with a handful of
> targeted fixes and small additions.

---

## 1. Goal

The app is now in Internal Testing at Google Play. Real use has
surfaced six items that should be addressed in a single
coordinated pass. Three are structural (media unification, shopping
aggregation, status column cleanup); three are smaller adjustments
(new unit, user_id visibility, photo carousels at the top of
editors).

The six items are grouped here for one focused round; afterwards
the app will be ready for a wider Internal Testing cohort.

---

## 2. Scope — what to change

### 2.1 Shopping list aggregation of repeated ingredients

**Observed**: when two or more dishes in the same event share an
ingredient, the shopping panel currently shows them as separate
lines. Example: if the menu has "Pasta with onions" needing 1
bunch of spring onions and "Onion soup" needing 2 bunches of
spring onions, the shopping panel displays two separate lines
instead of a single aggregated line.

**Fix**: aggregate repeated ingredients on the shopping panel
under strict equivalence conditions. The underlying data model is
**not modified** — each `event_dish_ingredients` row remains a
separate record. The aggregation is purely a presentation layer
concern.

**Aggregation key**: rows aggregate when **all** of the following
match across two or more rows of the same event:

```
(ingredient_id, unit_id, state, supplier_category_id, prep_note)
```

If any one of the five differs, the rows stay separate.

Rationale per component:
- `ingredient_id`: aggregation only makes sense for the same
  ingredient.
- `unit_id`: 100 g and 1 unit of tomato cannot be summed without
  conversion. Keep them separate.
- `state`: an ingredient that's `received` for one dish and
  `to_order` for another represents two distinct procurement
  situations.
- `supplier_category_id`: per-line supplier override (Spec 008)
  changes the destination supplier — keep rows separate so they
  appear under the right supplier sections.
- `prep_note`: "finely diced" vs "whole" is information the cook
  needs. Aggregating would lose it.

**Aggregated line appearance**:
- Displayed quantity = sum of individual quantities, same unit.
- Numeric formatting follows Spec 007's existing pipeline
  (`_ceilToTwoSigFigs` + reparse-to-12-significant-figures
  formatter).
- Displayed name = ingredient name (snapshot from
  `event_dish_ingredients.ingredient_name`).
- Displayed prep_note, state, supplier: the shared values
  (identical by definition).
- Source dishes (optional): if it adds clarity, display them as a
  subtle subtitle like "from: Pasta with onions, Onion soup". If
  it adds visual noise, omit them. Implementer's call.

**State change on aggregated lines**: changing the state of an
aggregated line (e.g. marking "3 bunches" as `ordered`) must
update **all underlying rows** atomically. Use a single Supabase
update with an `IN (...)` filter on the row IDs, wrapped in a
transaction. Either all rows transition or none do.

**Order text generation**: the "Usa com a llista de la compra"
flow per Spec 007 generates text using the **aggregated**
quantities, not the individual ones. The supplier receives "3
bunches of spring onions", not two lines summing to 3.

**What does NOT change**:
- Data model (no schema changes).
- Menu view: each dish keeps showing its own ingredient lines
  separately. Aggregation is only on the shopping panel.
- The `event_dish_ingredients` rows remain individual rows in the
  database.
- Supplier override (Spec 008) keeps working at the row level.
- Reference_servings scaling (Spec 008 §2.10): each row keeps its
  immutable base quantity. The aggregation sums the **effective
  scaled** quantities at display time, after each row has been
  scaled by its own dish's `servings / reference_servings` ratio.
  It does NOT sum the base quantities.

### 2.2 New unit: "ampolla"

**Observed**: real use surfaced that "ampolla" (bottle) is a
common unit for liquid ingredients sold in bottles (wine, olive
oil, vinegar, sauces). Currently the catalog of system units
includes `l`, `ml`, `packet`, `jar`, `tray`, etc., but no
"ampolla".

**Fix**: add a new system unit `ampolla` to the units catalog via
seed migration, following the same pattern as
`20260611010000_seed_units_paquet_llauna.sql`.

**Magnitude**: `package` (same as `packet`, `jar`, `tray`). This
keeps `ampolla` distinct from `l`/`ml` (volume), because in
practice an "ampolla" is an indivisible commercial unit (the user
asks for "1 ampolla", not "750 ml"). If at some point a conversion
layer is introduced, package-to-volume conversion can be added.

**Translations**:
- ca: "ampolla" (display name and code).
- es: "botella".
- en: "bottle".

The unit code in the DB remains `ampolla` (matching the existing
convention of code-in-Catalan for system units like `unitat` →
`unit`, etc.). The display name follows i18n.

Migration name suggestion:
`20260613010000_seed_unit_ampolla.sql`.

### 2.3 Photo carousels uniformized across all three entities

**Observed**: events have a multi-photo carousel (Spec 009), but
dishes and ingredients only have a single photo each (also Spec
009). Real use suggests dishes and ingredients also benefit from
multiple photos (e.g. preparation steps for a dish, identification
photos for ingredients with multiple appearances).

**Fix**: unify the photo experience so all three entity types
(events, dishes, ingredients) use the **same carousel pattern**:

- Photos section is at the **top** of the entity's detail/editor
  screen, **above the title/name field**. This applies to all
  three editors equally. For events this means moving the
  current photos section from between Place and Notes to above
  the title.
- Layout: thumbnails justified to the **left** of the row. If
  only one photo, it sits on the left (not centered, not
  full-width).
- Reorderable via long-press + drag, same UX pattern as the
  current events carousel.
- The **first photo by `position`** is the one shown in catalog
  lists, event cards, menu rows, etc. (same convention as events
  has today).

The carousel widget (currently `EventPhotosSection` per Spec 009)
should be generalized into a reusable `PhotoCarouselSection<T>`
or equivalent that takes the entity type as a parameter, so the
three editors share a single implementation.

### 2.4 Polymorphic media table (replaces event_photos + photo_path columns)

**Observed**: the current schema for photos (Spec 009) is a
hybrid:
- `event_photos` table for events (one-to-many).
- `dishes.photo_path` column for dishes (one-to-one).
- `ingredients.photo_path` column for ingredients (one-to-one).

With §2.3 promoting dishes and ingredients to multi-photo, the
hybrid model no longer fits. The original `Data model.md` had
anticipated this with a polymorphic `media` table — that's the
target architecture now.

**Fix**: introduce a polymorphic `media` table that unifies all
photo storage across the three entity types, and migrate existing
data into it. The old structures (`event_photos`,
`dishes.photo_path`, `ingredients.photo_path`) are dropped after
the data migration.

**New schema**:

```
CREATE TYPE media_entity_type AS ENUM ('event', 'dish', 'ingredient');

CREATE TABLE media (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type     media_entity_type NOT NULL,
  entity_id       UUID NOT NULL,
  path            TEXT NOT NULL,            -- relative path in Storage
  position        INT NOT NULL DEFAULT 0,   -- ordering within carousel
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX media_entity_idx ON media (entity_type, entity_id, position);
```

The `(entity_type, entity_id)` pair acts as the polymorphic
foreign key. There's no native FK constraint (Postgres doesn't
support polymorphic FKs), so referential integrity is enforced
via:
- A trigger that validates `entity_id` exists in the appropriate
  table (`events`, `dishes`, `ingredients`) based on
  `entity_type`.
- Cleanup triggers on `events`, `dishes`, `ingredients` that
  delete the corresponding `media` rows (and Storage blobs) on
  entity delete.

**RLS policy**: a single policy on the `media` table that joins
to the appropriate parent table based on `entity_type` and
verifies the user's group membership:

```
CREATE POLICY media_group_access ON media
  FOR ALL
  USING (
    CASE entity_type
      WHEN 'event' THEN entity_id IN (SELECT id FROM events WHERE group_id IN (SELECT group_id FROM memberships WHERE user_id = auth.uid()))
      WHEN 'dish' THEN entity_id IN (SELECT id FROM dishes WHERE group_id IN (SELECT group_id FROM memberships WHERE user_id = auth.uid()))
      WHEN 'ingredient' THEN entity_id IN (SELECT id FROM ingredients WHERE group_id IN (SELECT group_id FROM memberships WHERE user_id = auth.uid()))
    END
  );
```

Don't forget the `GRANT` on `media` to `anon, authenticated` (per
the lesson learned from Spec 009 — Postgres checks table
privileges before RLS, so missing GRANTs cause "permission denied"
errors that look like RLS failures).

**Storage migration**: existing photos live in three buckets
(`event-photos`, `dish-photos`, `ingredient-photos`). Decision:
**keep the existing buckets and paths as-is**, just reference them
from the new `media.path` column. Don't rename or move blobs.
This is much less risky than re-organizing storage. The bucket is
implied by `entity_type`. New uploads going forward use the same
buckets following the same convention.

**Data migration (backfill)**:

```sql
-- Events: migrate event_photos rows to media
INSERT INTO media (entity_type, entity_id, path, position, created_at)
SELECT 'event', event_id, photo_path, position, created_at
FROM event_photos;

-- Dishes: migrate single photo_path to media (position 0)
INSERT INTO media (entity_type, entity_id, path, position, created_at)
SELECT 'dish', id, photo_path, 0, created_at
FROM dishes
WHERE photo_path IS NOT NULL;

-- Ingredients: same pattern
INSERT INTO media (entity_type, entity_id, path, position, created_at)
SELECT 'ingredient', id, photo_path, 0, created_at
FROM ingredients
WHERE photo_path IS NOT NULL;
```

**Cleanup of old structures** (in a separate later migration,
after app code is fully migrated and validated):
- `DROP TABLE event_photos;`
- `ALTER TABLE dishes DROP COLUMN photo_path;`
- `ALTER TABLE ingredients DROP COLUMN photo_path;`

**Important — staging the migration**:

The data migration and the schema cleanup should be in **separate
migration files**, applied in two waves:

1. **Wave 1** (apply now with this Spec):
   - Create `media` table with index, RLS, GRANT, triggers.
   - Backfill data from old structures.
   - Update app code to read/write only from `media`.
   - Old structures (`event_photos`, `photo_path` columns) still
     exist in the DB but are no longer touched by the app.

2. **Wave 2** (apply later, after the new app is stable in
   Internal Testing for at least one full release cycle):
   - Drop `event_photos` table.
   - Drop `photo_path` columns.

This staging protects against rollback: if a critical bug
surfaces in Wave 1, we can roll back the app code while still
having data in the old structures.

**Backward compatibility for testers on older app versions**:
testers that haven't updated yet will keep reading from
`event_photos` and `photo_path`. To prevent them seeing stale
data:
- Option A (chosen): force them to update before they can use the
  app. Set a `minimum_supported_version` in Supabase or in the
  app config; the old app shows a "please update" message. This
  is overkill for our small testing cohort.
- Option B: keep the old structures synced via a trigger for the
  duration of Wave 1, so writes to `media` also write back to the
  old structures. Old app versions continue working with read-old
  / write-old paths.
- Option C: accept temporary inconsistency. Testers see slightly
  outdated photos until they update. Given the small cohort
  (3-5 people) and the short update cycle (next time they open
  Play Store), this is acceptable.

**Decision**: Option C. We accept the brief inconsistency window.
Communicate the update to testers via a release notes message
asking them to update promptly.

### 2.5 User ID visibility in Settings

**Observed**: the privacy policy and the Play Store data safety
declaration mention that users can request deletion of their data
by emailing the developer. But there's no way for a user to
**identify themselves** in the email — the app uses anonymous
authentication and never displays the `user_id` anywhere.

Without the user_id, neither the user nor the developer can
identify which data to delete in a deletion request.

**Fix**: add a section in Settings showing the user's
authenticated `user_id` (the UUID from Supabase Auth), with a
**copy-to-clipboard** button next to it.

**Location**: Settings screen, near the bottom in a section
labelled "Privacy & data" (or equivalent translated). Format:

```
Privacy & data
─────────────────────────────────────
Your account ID
[3ab3ebe9-6418-...]                [Copy]

Use this ID when requesting data
deletion. Email: rafael.pous@gmail.com
```

The user_id is exposed only on this Settings panel. It's not
displayed anywhere else.

**Implementation note**: read `Supabase.instance.client.auth.currentUser?.id`
and display it. The copy button uses the standard
`Clipboard.setData(ClipboardData(text: userId))` from the
services package.

Translations for the new strings: ca, es, en.

### 2.6 Cleanup of unused `events.status` column

**Observed**: the column `events.status` exists in the schema
(see `events` table inspection during the Spec 009 dataset work)
with values like `planning`, `confirmed`, `done`. Since Spec 008
§2.4, event status (`in_preparation` / `ready` / `past`) is
derived at the UI layer from event date and ingredient states.
The persisted `events.status` column is no longer read or written
by the app.

**Fix**: drop the column to keep the schema clean.

Migration:

```sql
ALTER TABLE events DROP COLUMN status;
```

This requires a confirmation step before running, since dropping a
column is irreversible (data loss if any code still uses it).
Before the drop:
1. Search the codebase for any remaining references to
   `events.status` (should be none — Spec 008 removed them).
2. Verify with the project owner that no other app or
   consumer (none expected) reads this column.

Migration name suggestion:
`20260613020000_drop_events_status.sql`.

---

## 3. Out of scope (aparked items)

The following potential improvements have been identified during
real-use validation but are intentionally NOT in this spec. They
are documented here so they're tracked for future consideration:

- **Singular/plural agreement in shopping list text**: when an
  ingredient has quantity > 1, the text currently says "16 gamba
  vermella" instead of grammatically correct "16 gambes
  vermelles". Fixing this requires either a `name_plural` column
  per ingredient, or a more advanced i18n pipeline with
  pluralization rules per language. **Decision: parked** until
  multiple users complain or until an i18n pass becomes
  worthwhile.

- **Migration of plugins to Built-in Kotlin**: the build emits a
  warning about plugins using Kotlin Gradle Plugin (KGP) that
  future Flutter versions will reject. Not blocking now.

- **Dedicated `/delete-data` page on GitHub Pages**: a more
  formal data deletion flow with a public web form. Current
  implementation (privacy policy URL + email + user_id in
  Settings) is sufficient for the current Internal Testing scale.

- **Tab-switch unsaved-changes guard at Settings**: Settings is a
  tabbed pane with shared route; `PopScope` doesn't intercept tab
  switches. Workaround in Spec 008 was the AppBar save button;
  the cross-tab dialog is parked.

- **Fase 1 features still ahead**: pantry as dynamic stock with
  quantities; full menu preview screen; quantity scaling by event
  format; cooking schedule / preparation timeline; verification of
  servings vs guest count; sharing a group with other users.

- **Fase 2 features**: importing recipes from URL; premium model;
  conversational AI assistant; e-commerce integrations; iOS port.

---

## 4. Acceptance criteria

The assignment is complete when the project owner can verify all of
the following on the Android device:

### §2.1 Shopping aggregation

1. An event with two dishes that share an ingredient (same
   ingredient, same unit, same state, same supplier, same
   prep_note) shows a single aggregated line in the shopping
   panel with the summed quantity.
2. The same scenario with different units shows two separate
   lines.
3. The same scenario with different states shows two separate
   lines.
4. The same scenario with different prep_notes shows two separate
   lines.
5. The same scenario with different per-line supplier overrides
   shows two separate lines in different supplier sections.
6. Changing the state of an aggregated line transitions all
   underlying rows atomically.
7. The "Usa com a llista de la compra" text uses the aggregated
   quantities.
8. The menu view continues showing each dish's ingredients
   separately (per dish).

### §2.2 New unit ampolla

9. The unit selector for ingredients shows "ampolla" / "botella" /
   "bottle" as an available option.
10. Existing ingredients aren't affected.

### §2.3 Photo carousels at the top of editors

11. Event editor: the photo carousel is at the top of the screen,
    above the title field.
12. Dish editor: same — carousel at top, above the name field.
13. Ingredient editor: same.
14. All three carousels have identical UX: thumbnails justified
    left, reorderable via long-press + drag, single-photo case
    appears as a single thumbnail on the left.

### §2.4 Media polymorphic table

15. The `media` table exists with correct schema, indexes, RLS,
    GRANT.
16. Existing photos (events + dishes + ingredients) appear
    correctly in the app after the migration (no broken
    references, no missing photos).
17. New photo uploads write to `media` only (verified via direct
    DB inspection).
18. Old structures (`event_photos`, `dishes.photo_path`,
    `ingredients.photo_path`) still exist in the DB but are no
    longer touched by the app (Wave 1 stops here; Wave 2 drops
    them later).
19. RLS works correctly: users can't access photos of groups they
    don't belong to.

### §2.5 User ID visibility

20. Settings screen has a "Privacy & data" section with the
    user_id visible and a copy button.
21. Copy button copies the user_id to the clipboard.
22. The displayed user_id matches the authenticated user's UUID.

### §2.6 Drop events.status

23. The `status` column no longer exists on the `events` table.
24. No regression in event status display or behavior (since
    status was already derived at UI layer per Spec 008).

### General

25. All affected screens follow the design system and the
    EditScaffold pattern (Spec 008 Fixes).
26. All migrations apply cleanly to the remote Supabase project.
27. All existing flows continue to work without regression.
28. flutter analyze: clean. All existing tests pass. New tests
    for §2.1 (aggregation logic) and §2.4 (media model + RLS) are
    added.
29. The work is committed to a new branch
    `feat/spec-010-post-internal-testing` with a clean PR
    description listing all six items.

---

## 5. Notes for the implementer

- This is a coordinated round of six items. Suggested order:
  - §2.6 first (smallest, isolated — drop unused column).
  - §2.2 next (seed migration only).
  - §2.5 next (UI-only Settings addition).
  - §2.1 next (presentation-layer fix in shopping panel).
  - §2.4 next (the big structural piece — media table).
  - §2.3 last (depends on §2.4 — generalize the carousel widget
    across all three entity editors).
- Stop and ask the project owner before improvising on these
  ambiguities:
  - §2.4: whether to enforce polymorphic referential integrity
    with triggers (recommended), or rely on application-level
    cleanup only (simpler but less safe).
  - §2.4: storage paths — confirm that keeping the old paths
    (`event-photos/...`, `dish-photos/...`,
    `ingredient-photos/...`) referenced from a unified `media`
    table is acceptable, vs. reorganizing into a single bucket
    structure.
  - §2.3: where exactly to place the carousel relative to the
    AppBar — directly below the AppBar, or with some padding /
    visual separator.
- Migrations to apply remotely with `supabase db push`:
  - `20260613010000_seed_unit_ampolla.sql`
  - `20260613020000_drop_events_status.sql`
  - `20260613030000_create_media_table.sql` (table, indexes,
    RLS, GRANT, triggers)
  - `20260613040000_backfill_media_from_event_photos.sql`
  - `20260613050000_backfill_media_from_dish_photo_paths.sql`
  - `20260613060000_backfill_media_from_ingredient_photo_paths.sql`
- The old structures (`event_photos`, `photo_path` columns) are
  intentionally NOT dropped in this Spec. They get dropped in a
  later Wave 2 migration (after one full release cycle of
  validation).
- The `Data model.md` should be updated in this PR to reflect the
  new `media` table and the deprecation of `event_photos` and
  `photo_path` columns. Mention that Wave 2 will drop them
  later.
- The PR description should reference each of the six items by
  its §2.x number with a short summary.
