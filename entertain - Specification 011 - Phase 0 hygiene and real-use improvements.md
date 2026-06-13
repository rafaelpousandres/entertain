# Specification 011 — Phase 0 hygiene + real-use improvements

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read `CLAUDE.md`, `entertain - Data model.md`, and all
> previous specifications (001 through 010 including their
> fixes rounds) before starting. This spec is a coordinated
> round combining hygiene cleanup (Phase 0 — items deferred
> from Spec 010) and improvements driven by real-use feedback
> collected from initial Internal Testing.
>
> The Spec is large in scope but most items are independent.
> Suggested implementation order is at the end (§5).

---

## 1. Goal

The Spec 010 release is now live in Internal Testing and has been
used in real events. Feedback collected during real use has
surfaced several improvements to the shopping panel and event
navigation that significantly affect daily ergonomics. In
parallel, several hygiene items were deferred from Spec 010
(documented as out of scope at the time) and should now be
cleaned up.

This Spec consolidates eleven items in two blocks:

**Block A — Phase 0 hygiene** (items 2.1 through 2.6): cleanup
of structures left behind by the Spec 010 migration, plus a
dedicated /delete-data page, plus two UX guards that affect the
edit-discard flow universally.

**Block B — Real-use improvements** (items 2.7 through 2.11):
five changes to the event detail and shopping panel that came
from actual use of the app for planning real events.

---

## 2. Scope — what to change

### 2.1 Dedicated /delete-data page on GitHub Pages

**Observed**: the current data deletion flow relies on the user
emailing the developer with their user_id (visible in Settings
per Spec 010 §2.5). For production release on either Google Play
or Apple App Store, both stores may require a dedicated public
web page describing the data deletion process, separate from the
privacy policy.

**Fix**: create a new public page at
`https://rafaelpousandres.github.io/entertain/delete-data/`
following the same structure as the existing privacy policy
page.

**Content** (template — final wording to be reviewed by project
owner):

```
Account and data deletion — Entertain

Entertain ("the app") allows users to permanently delete their
account and all associated data. This page describes the deletion
process.

How to request deletion

To request the deletion of your account and all your data:
1. Open the Entertain app on your device.
2. Go to Settings > Privacy & data.
3. Tap the "Copy" button next to your account ID. This copies
   your unique identifier (a UUID) to the clipboard.
4. Send an email to rafael.pous@gmail.com with the subject
   "Data deletion request" and paste your account ID in the
   email body.
5. We will process your request within 30 days and reply by
   email confirming the deletion.

What is deleted

All of the following data associated with your account is
permanently deleted:
- All events you created or contributed to.
- All dishes and ingredients in your group's catalogs.
- All photos uploaded by you (stored in Supabase Storage).
- All supplier configuration in your group.
- Your authentication identity in Supabase Auth.

What is retained

No data is retained after a deletion request is processed,
unless required by law (we do not currently have such legal
requirements).

If you need clarification before submitting a request, contact
us at the email above.

Last updated: [date]
```

**Implementation note**: the GitHub Pages site already exists
(privacy policy is there). Add a new directory `delete-data/`
with an `index.html`. Style consistent with the privacy page.
Update the Privacy Policy page to link to the new delete-data
page in a "Data deletion" section. Update Settings (Spec 010
§2.5) to also link to the public page (in addition to the
email instructions already shown).

### 2.2 Wave 2 cleanup — drop legacy photo structures

**Observed**: Spec 010 introduced the polymorphic `media` table
and migrated all existing photos into it (Wave 1). The legacy
structures (`event_photos` table, `dishes.photo_path` column,
`ingredients.photo_path` column) were intentionally kept as
forward markers during one full release cycle for rollback
safety. Now that Spec 010 has been validated in real use, these
legacy structures are no longer needed.

**Fix**: drop the legacy structures in a single migration:

```sql
-- 20260616010000_wave2_drop_legacy_photo_structures.sql

BEGIN;

DROP TABLE IF EXISTS event_photos;

ALTER TABLE dishes DROP COLUMN IF EXISTS photo_path;
ALTER TABLE ingredients DROP COLUMN IF EXISTS photo_path;

COMMIT;
```

Before applying:
1. Verify nothing in the app code references these structures.
   Should be clean after Spec 010, but worth a final grep.
2. The Spec 010 backfills are no-ops now (data is already in
   `media`), so dropping the sources is safe.

After applying:
- The schema is clean.
- The `Data model.md` should be updated to remove the
  deprecation markers for these structures (they no longer
  exist).

### 2.3 Drop orphan enums media_owner_type and media_kind

**Observed**: Spec 010 §2.4 noted that two enums
(`media_owner_type` and `media_kind`) remained from an earlier
Phase 0 design of the `media` table. They were left as forward
markers but are not used by any current table or code.

**Fix**: drop the orphan enums in the same Wave 2 migration as
§2.2:

```sql
DROP TYPE IF EXISTS media_owner_type;
DROP TYPE IF EXISTS media_kind;
```

Combined with §2.2 in a single migration file for atomicity.

### 2.4 Cleanup of test events accumulated in the database

**Observed**: during Spec 010 validation and the multiple
Play Store install cycles, several test events were created
in the project owner's group (`5fe643a0-6d0d-4e7e-87eb-1f77cb571548`)
with names like "VAL-010 marker", "Test marker", etc. These
are leftovers from validation and should be removed.

**Fix**: a manual SQL cleanup, not a migration. The project
owner runs the cleanup query at the Supabase SQL Editor before
this Spec is merged:

```sql
-- Identify test events
SELECT id, title, created_at
FROM events
WHERE group_id = '5fe643a0-6d0d-4e7e-87eb-1f77cb571548'
  AND (
    title ILIKE '%test%'
    OR title ILIKE '%val-%'
    OR title ILIKE '%marker%'
    OR title ILIKE '%prova%'
  )
ORDER BY created_at;

-- After review, delete the matching events
DELETE FROM events
WHERE id IN (...);
```

Cascade deletes via FK constraints handle the cleanup of
`event_dishes`, `event_dish_ingredients`, and `media` rows
associated with these events. The project owner verifies before
running.

This is **not** committed code — it's a one-time cleanup. Note
the steps in the PR description so it's traceable.

### 2.5 Tab-switch unsaved-changes guard (universal)

**Observed**: in panels with multiple tabs sharing the same
route (Settings, possibly the event detail Event/Menu/Shopping
tabs), the `PopScope` guard does not intercept tab switches.
The user can edit a field in one tab, switch to another tab
without saving, and the changes are silently lost.

This is a longstanding limitation noted in Spec 008 Fixes and
re-noted at Spec 010 planning. It's now time to address it
universally.

**Fix**: introduce a reusable `DirtyTabsScaffold` widget that
wraps a `TabBar` + `TabBarView` and intercepts tab switches.
When the user attempts to switch tabs while the current tab
has unsaved changes, the standard "Unsaved changes" dialog is
shown (same as for the back button).

**Behavior**:
- If the user confirms "Discard", the tab switches, the dirty
  state is cleared.
- If the user cancels, the user stays on the current tab.

**Where it applies**:
- **Settings**: the existing tabs (whatever they are) must use
  the new wrapper.
- **Other multi-tab panels**: search the codebase for
  `TabBar` + editor pattern. Each match should be wrapped.

**The Event detail panel (Event / Menu / Shopping)** is a
special case: switching between Event, Menu, and Shopping does
**not** lose data (the same event is loaded across all three
tabs; each tab presents a different facet). Verify during
implementation whether the dirty signal applies there — likely
not, because tabs share state. Document the finding in the
PR description.

**Implementation note**: the standard Flutter pattern is to
intercept via a `TabController.addListener(() {...})` that
checks the current tab's dirty state. If dirty, prevent the
switch and show the dialog.

### 2.6 Photo dirty signal — Option B (approximate rollback)

**Observed**: per Spec 009 Fixes, the dirty signal now fires
when a photo is changed in the dish or ingredient editor. But
the photo itself is **persisted to Supabase Storage immediately**
on upload, before the user presses save. So when the user
presses "Discard" on the unsaved-changes dialog, the photo
remains persisted — only the other field changes are
discarded. This is a subtle UX inconsistency.

**Fix — Option B (approximate rollback)**: when the user
presses "Discard", revert the photo changes made during the
editing session.

**Behavior**:
- **If the user added a new photo** that didn't exist before:
  delete the new media row and storage blob.
- **If the user replaced an existing photo**: delete the new
  media row and storage blob; restore the previous one (which
  was kept buffered, not yet deleted, until save).
- **If the user deleted a photo**: restore it from the buffered
  pre-edit state.
- **If the user reordered photos**: restore the original order.

**Tracking the buffer**:
- On entering the editor, snapshot the current `media` rows
  for the entity.
- All photo changes during the session apply to the backend
  immediately (current behavior preserved), but the buffer
  tracks "what was originally there" and "what changed".
- On Save: clear the buffer (changes are confirmed).
- On Discard: replay the changes in reverse to restore the
  original state, then clear the buffer.

**Scope of the rollback** — approximate, not transactional:
- The rollback happens at the application layer, not via
  database transactions or Storage atomicity.
- If the app crashes mid-edit, partial changes remain
  persisted. **Acceptable**: the rare app-crash scenario is
  not protected.
- The rollback can fail partially (e.g. a network error
  during the reverse upload). In that case, show a non-fatal
  warning to the user: "Some photo changes couldn't be
  reverted. Please check the editor." and let them resolve
  manually.

**Why not Option C (defer all photo persistence to save)**:
this would be the architecturally clean solution but requires
significant refactoring of the photo upload flow (the
multi-photo case, the storage path generation, the async
upload progress, etc.). Option B is pragmatic.

### 2.7 Persistent active tab per event

**Observed**: when the user opens an event, the app always
lands on the Event tab. But in real use, users spend most
time on the Menu tab (during planning) and on the Shopping
tab (during purchasing). Always landing on Event creates
unnecessary friction.

**Fix**: each event remembers its last active tab. When
reopened, it lands on the remembered tab.

**Default for new events**: **Menu** (not Event), since menu
planning is the most common starting point.

**Persistence**:
- Local persistence via `SharedPreferences` (or equivalent).
- Key format: `event_last_tab:{event_id}` → `"event"` |
  `"menu"` | `"shopping"`.
- Saved on every tab switch.
- Read on event open; if no value exists, default to `"menu"`.

**Across sessions**: persists across app restarts (this is the
purpose of `SharedPreferences`).

**Across devices**: does NOT persist across devices. If the
user installs the app on a second device, last-tab memory
resets. **Acceptable** for now; this is a UX convenience, not
critical state.

**Edge cases**:
- If an event is deleted, the `event_last_tab:{event_id}` key
  becomes orphan in SharedPreferences. **Acceptable** — it
  doesn't grow unbounded in practice, and orphan keys are
  harmless.

### 2.8 Accordion-collapsed shopping panel

**Observed**: when the user opens the Shopping tab of an
event, all supplier sections are expanded by default. With
multiple suppliers (4-6 typical), this produces a long scroll
and visual noise.

**Fix**: change the shopping panel to an accordion pattern.

**Behavior**:
- On open: **all supplier sections are collapsed**.
- Tapping a supplier header expands that section AND
  collapses all other open sections (only one open at a time).
- Tapping the expanded header again collapses it.
- The expand/collapse state is **not persisted**. Each entry
  into the Shopping panel starts with all sections collapsed.

**Visual indicator**: the supplier header has a chevron icon
(down when collapsed, up when expanded) to signal
expandability, consistent with Material 3 conventions.

### 2.9 Status counters on supplier headers

**Observed**: the supplier headers in the shopping panel show
the supplier name and icon. With the accordion pattern (§2.8),
the user needs a quick way to see "what's the status of this
supplier" without expanding the section.

**Fix**: add three colored counters on the supplier header,
visible whether collapsed or expanded.

**Counter colors and semantics**:
- **Red**: count of ingredients in `to_order` + `missing`
  states (the user still has to act).
- **Yellow**: count of ingredients in `ordered` state
  (waiting for the supplier to deliver).
- **Green**: count of ingredients in `received` + `at_home`
  states (resolved).

The three counters sum to the total number of managed
ingredients for that supplier in the event.

**Format**:
- A small colored circle (red/yellow/green) followed by the
  number on its right.
- Three counters side by side: 🔴 5 🟡 2 🟢 3
- **Zero values hidden**: if a color has zero ingredients,
  neither the circle nor the number is shown.

**Visual consistency**: this matches but is more compact than
the event-level summary at the top of the Shopping tab,
which keeps the existing five-state breakdown ("12 to order
· 8 ordered · 5 received · 5 at home · 0 missing"). The
event summary stays unchanged; the new compact counters
appear only on supplier headers.

**Extra ingredients (§2.11)**: **not counted** in any of the
three counters. The counters represent only "managed
ingredients" (those that derive from dishes). Extra
ingredients are out-of-scope for status tracking.

### 2.10 Supplier icon background and ring color

**Observed**: the supplier icon at the left of each
section header is currently always the same pale green
background. After §2.9, the most informative visual cue is
the highest-priority counter color.

**Fix**: tint the supplier icon based on the highest-priority
status:

- **At least one red counter > 0**: pale red background +
  red ring around the icon.
- **Else, at least one yellow counter > 0**: pale yellow
  background + yellow ring.
- **Else** (all green or no managed ingredients): pale green
  background + green ring (matches current default).

**Color palette**:
- Use the design system's existing red/yellow/green tokens
  for both the pale background and the normal ring.
- If the design system doesn't have explicit "pale" variants,
  derive them programmatically (e.g. `Color.withOpacity(0.15)`)
  for backgrounds, full-saturation for rings.

**Visual coherence**: the colors are consistent with the
counter colors (§2.9). Red ring + 🔴 5 reads naturally as a
"5 actions pending" signal.

**Edge case**: if a supplier has zero managed ingredients
(only extras, or just configured but no use), the icon stays
pale green (default). This is the rare case and the safest
default.

### 2.11 Extra ingredients in the shopping panel

**Observed**: real use has surfaced that when ordering from
a supplier (e.g. the greengrocer), the cook wants to take
advantage of the order to ask for other items — items that
are NOT for the current event, but that the cook needs
anyway. Example: "since I'm calling the greengrocer for
tomatoes for Sunday's dinner, let me also order spinach for
the week and lemons for tea".

**Fix**: allow adding "extra" ingredients to the shopping
panel that are not associated with any dish.

**Data model — Option C (phantom dish per event)**:

Each event has an automatically-created phantom dish (created
lazily on first use) whose category is a new value or whose
behavior is marked via a flag. The phantom dish:
- Holds the extra ingredients via the existing
  `event_dish_ingredients` mechanism.
- Is **not displayed** in the Menu tab of the event.
- Is **not counted** in the event status summary or
  supplier counters (per §2.9).
- Has a special `is_extras: true` flag (boolean column added
  to `event_dishes`) OR a reserved name like `__extras__`
  that the UI filters out.

**Recommended approach**: add a boolean column `is_extras`
to `event_dishes`:

```sql
ALTER TABLE event_dishes
  ADD COLUMN is_extras BOOLEAN NOT NULL DEFAULT FALSE;
```

The UI filters `is_extras = TRUE` rows from the Menu view and
treats them specially in the Shopping view.

**Extra ingredients table**: reuses
`event_dish_ingredients`. The rows for extras have:
- `event_dish_id` pointing to the phantom dish.
- `state`: irrelevant. The shopping panel treats extras as
  "no state".
- `supplier_category_id`: required (the extra is associated
  with a supplier so it can be added to that supplier's
  order).
- All other fields (quantity, unit, ingredient_id, etc.) work
  identically to a dish ingredient.

**UI behavior**:
- **Shopping panel**: extras appear within their assigned
  supplier section, after the managed ingredients, marked
  with a small "Extra" badge (neutral gray color, no
  state-derived color). The badge label is "Extra" (or its
  translation).
- **Menu panel**: extras do not appear. The phantom dish is
  invisible.
- **Status counters (§2.9)**: extras are not counted.
- **Supplier icon background (§2.10)**: extras don't influence
  the priority calculation.
- **Sending order to supplier**: when the user generates the
  message via "Usa com a llista de la compra" (Spec 007),
  extras for that supplier are included in the message, listed
  after the managed ingredients. Same applies to the
  copy-to-clipboard list. The supplier should see all items
  to order in one message.

**Adding an extra**:
- A button "+ Add extra" appears at the end of each supplier
  section in the Shopping panel.
- Tapping the button opens an ingredient picker dialog (same
  UX as adding an ingredient to a dish):
  - Search/select ingredient from the catalog.
  - Specify quantity.
  - Specify unit (selectable from compatible units, default
    is the ingredient's default unit).
  - Specify supplier (defaults to the supplier whose section
    the "+ Add extra" button was tapped from).
- On confirm: a new `event_dish_ingredients` row is created
  for the phantom dish.

**Removing an extra**:
- Each extra in the shopping panel has a delete affordance
  (swipe-to-delete or a small "×" button on the row, follow
  the design system convention used elsewhere).
- On delete: the `event_dish_ingredients` row is removed. If
  the phantom dish has no more extras after the deletion,
  the phantom dish itself is **kept** (it will be reused next
  time an extra is added). It's a lightweight container; no
  cleanup needed.

**Editing an extra**:
- Tapping the extra row in the shopping panel opens the same
  ingredient editor used for dish ingredients (per the dish
  editor flow).

**Past events**: extras remain visible in past events as
part of the historical record. They do not auto-clear or
hide after the event date.

**Database migration**:

```sql
-- 20260616020000_event_dishes_is_extras.sql
ALTER TABLE event_dishes
  ADD COLUMN is_extras BOOLEAN NOT NULL DEFAULT FALSE;
```

**App code changes**:
- `Event` model: add a method/getter `extrasDish` returning
  the phantom dish (or null if none yet exists).
- `EventsRepository`: lazy-create the phantom dish on first
  extra add.
- `EventShoppingPanel` widget: filter the phantom dish from
  the menu, render extras as a separate section within each
  supplier.
- `EventMenuTab` widget: filter the phantom dish out.
- `SupplierMessageScreen` (per Spec 007): include extras in
  the generated message.
- Shopping aggregation logic (per Spec 010 §2.1): **does not
  aggregate** extras with managed ingredients (they're a
  different conceptual category — the badge "Extra" must
  remain visible).

---

## 3. Out of scope (parked items)

Same items as in Spec 010 §3 remain parked, except for those
addressed in this Spec. Reaffirming:

- **Singular/plural agreement in shopping list text**: still
  parked, moved to Phase 1.
- **Plugin migration to Built-in Kotlin**: still parked, moved
  to Phase 1.
- **AAB size reduction**: still parked.
- **Phase 1 features**: pantry as dynamic stock, full menu
  preview, quantity scaling by event format, cooking schedule
  / preparation timeline, verification of servings vs guest
  count, sharing a group with other users, recurring events.
- **Phase 2 features**: iOS port (in active discussion),
  recipe import from URL, premium model, AI assistant,
  e-commerce integrations, push notifications.

---

## 4. Acceptance criteria

The assignment is complete when the project owner can verify
all of the following on the Android device:

### §2.1 /delete-data page

1. The page is live at `https://rafaelpousandres.github.io/entertain/delete-data/`.
2. The privacy policy links to it.
3. The Settings > Privacy & data section also links to it (in
   addition to the existing email instructions).

### §2.2 Wave 2 cleanup

4. The `event_photos` table no longer exists.
5. The `dishes.photo_path` and `ingredients.photo_path`
   columns no longer exist.
6. All photos still display correctly across the app
   (no regression).

### §2.3 Orphan enums

7. The `media_owner_type` and `media_kind` enums no longer
   exist in the database.

### §2.4 Test events cleanup

8. The project owner's events list contains only real events
   (no "test", "marker", "VAL-", or "prova" titles remaining).

### §2.5 Universal tab guard

9. Editing a field in a Settings tab and attempting to switch
   to another tab shows the "Unsaved changes" dialog.
10. Confirming "Discard" switches the tab and clears the dirty
    state.
11. Cancelling stays on the current tab.
12. The same behavior applies to any other multi-tab panel
    with editable content (verified during implementation).
13. The Event detail tabs (Event/Menu/Shopping) do NOT trigger
    the guard, since switching there doesn't lose data.

### §2.6 Photo dirty rollback

14. Adding a photo and then pressing back + Discard removes
    the new photo (verified in DB and Storage).
15. Replacing a photo and then pressing back + Discard
    restores the original photo.
16. Deleting a photo and then pressing back + Discard
    restores the deleted photo.
17. Reordering photos and then pressing back + Discard
    restores the original order.
18. If a rollback fails mid-way, a non-fatal warning is shown
    to the user.

### §2.7 Persistent active tab

19. Opening a new event lands on the Menu tab.
20. Switching to Shopping in an event, closing the event,
    and reopening it lands on the Shopping tab.
21. The behavior persists across app restarts.
22. Deleting an event and creating a new one with the same
    title does not "inherit" the previous event's last tab
    (each event has its own).

### §2.8 Accordion shopping panel

23. Opening the Shopping tab shows all supplier sections
    collapsed.
24. Tapping a supplier header expands that section.
25. Tapping another supplier header expands it and collapses
    the previous one (only one open at a time).
26. Closing the Shopping tab and reopening it restores the
    all-collapsed state.

### §2.9 Status counters on supplier headers

27. Each supplier header shows 0 to 3 colored counters
    (red/yellow/green) with the corresponding ingredient
    count.
28. Zero counters are hidden (no "🔴 0" displayed).
29. Counter colors map: red = `to_order` + `missing`, yellow
    = `ordered`, green = `received` + `at_home`.
30. Extras are not counted (per §2.11).

### §2.10 Supplier icon background and ring

31. The supplier icon background is pale red / yellow / green
    based on priority (red > yellow > green).
32. A normal-saturation ring of the same color surrounds the
    icon.
33. Suppliers with no managed ingredients have pale green
    (default).

### §2.11 Extra ingredients

34. Adding an extra ingredient via the "+ Add extra" button
    creates a phantom dish (if not yet existing) and adds the
    ingredient there.
35. The extra appears in the shopping panel under the
    selected supplier with a gray "Extra" badge.
36. The extra does NOT appear in the Menu tab.
37. The extra does NOT affect supplier counters (per §2.9).
38. The extra IS included in the supplier message generated
    by "Usa com a llista de la compra".
39. Removing an extra works (swipe or delete button).
40. Editing an extra opens the same ingredient editor as for
    dish ingredients.
41. Past events still display extras.

### General

42. flutter analyze: clean. All existing tests pass. New
    tests cover:
    - Tab-switch guard logic (§2.5).
    - Photo rollback (§2.6) — at least add + discard, replace +
      discard.
    - Persistent tab (§2.7) — read/write SharedPreferences.
    - Accordion logic (§2.8).
    - Status counter calculation (§2.9), including extra
      exclusion.
    - Extras flow (§2.11) — add, remove, message generation.
43. All migrations apply cleanly to the remote Supabase
    project.
44. The Data model.md is updated to reflect §2.2, §2.3, and
    §2.11.

---

## 5. Notes for the implementer

**Suggested implementation order**, from smallest to largest:

1. §2.1 — Delete-data page (HTML + GitHub Pages, no app code).
2. §2.3 — Drop orphan enums (single migration line).
3. §2.2 — Wave 2 cleanup (combined with §2.3 in one
   migration).
4. §2.4 — Cleanup of test events (manual SQL, not committed
   code).
5. §2.7 — Persistent active tab (SharedPreferences read/write).
6. §2.8 — Accordion shopping panel (UI-only change).
7. §2.9 — Status counters (UI-only addition).
8. §2.10 — Supplier icon tinting (UI-only addition, depends on
   §2.9 having the data ready).
9. §2.5 — Universal tab guard (introduces new widget,
   refactors a few places).
10. §2.6 — Photo dirty rollback (the most complex item,
    involves snapshotting + reverse application of changes).
11. §2.11 — Extra ingredients (a database migration + multiple
    UI changes; saved for last because it touches many places).

**Stop and ask the project owner** if you encounter:
- §2.5: an unexpected multi-tab panel that wasn't anticipated.
- §2.6: rollback failure handling — exact wording of the
  non-fatal warning, or a different recovery flow.
- §2.11: the exact UX of "+ Add extra" — whether the button
  goes at the end of each supplier section, or there's a
  single global "+ Add extra" with a supplier picker.

**Migrations to apply remotely with `supabase db push`**:
- `20260616010000_wave2_drop_legacy_photo_structures.sql`
  (combined §2.2 + §2.3).
- `20260616020000_event_dishes_is_extras.sql` (§2.11).

**Update the Data model.md** to reflect:
- Removal of `event_photos` table and `photo_path` columns.
- Removal of orphan enums.
- New `is_extras` boolean on `event_dishes`.

**Branch name**: `feat/spec-011-phase-0-hygiene-and-real-use-improvements`.
