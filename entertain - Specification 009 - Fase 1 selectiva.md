# Specification 009 — Fase 1 selectiva

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read `CLAUDE.md`, `entertain - Data model.md`, `entertain - Design system.md`,
> and all previous specifications (001 through 008, including their fixes
> rounds) before starting. This is the first specification of Fase 1 — a
> selective subset of the Fase 1 backlog chosen by the project owner based
> on real-world usage of the MVP. The remaining Fase 1 items are
> intentionally deferred to future passes.

---

## 1. Goal

The MVP (Specs 001–007) plus the polish rounds (Spec 008 and its Fixes)
have been in real use. Four new features and one small correction are
ready to be promoted from "future ideas" to "implement now". The
project owner has explicitly chosen this subset; the rest of Fase 1
stays deferred (see §3 for the deferred list).

The five items:

1. **§2.1 — Event duplication.** Allow the user to duplicate an
   existing event as a starting point for a new one, copying menu and
   structural data but resetting ingredient states and orders.
2. **§2.2 — Photos for dishes, ingredients, and events.** Visual
   memory aids — a photo per dish and per ingredient, and a photo
   album per event.
3. **§2.3 — Contact picker for supplier categories.** Replace manual
   entry of phone and email with selection from the device's contacts
   list, with permission handling.
4. **§2.4 — `at_home` available from any supplier category.** Fix
   the gap where `at_home` cannot be selected as a state for
   ingredients belonging to non-Rebost supplier categories. The user
   should be able to mark any ingredient as "I already have it at
   home" regardless of which supplier it would otherwise come from.

---

## 2. Scope — what to fix

### 2.1 Event duplication

**Observed**: a frequent pattern in real use is "the dinner I'm doing
this Saturday is very similar to the one I did three weeks ago — same
menu, mostly same guests". Today the user has to recreate everything
from scratch. The catalog already provides the dishes, but the menu
composition (which dishes, with which servings, which ad-hoc
ingredients) has to be assembled again.

**Fix**: add a "Duplicate event" action that creates a new event with
the same menu structure as the source, but with key fields reset so
that the new event starts in the natural initial state.

**Trigger**: a menu item or icon button on the event detail screen
(e.g. in the AppBar's overflow menu "...") labelled "Duplica" /
"Duplicar" / "Duplicate".

**What gets copied from the source event**:

- The list of dishes in the menu (each `event_dishes` row), with:
  - The same `dish_id` reference to the catalog dish.
  - The same `servings` count (copied as-is).
- All ingredient lines for each dish (each `event_dish_ingredients`
  row), with:
  - The same ingredient reference.
  - The same `quantity` and `reference_servings` (the immutable base,
    per Spec 008 §2.10 model).
  - The same `supplier_category_id` per-line override (if set).
  - The same `prep_note`.
- The event type (`Asseguts` / `Bufet` / `Altre`).
- The number of guests (`guest_count`).

**What gets reset (NOT copied)**:

- The event **date** — the new event has no date set. The user picks
  one when filling in the duplicated event.
- The event **name** — the new event's name defaults to "Copia de
  [original name]" (translated: "Copia de" ca, "Copia de" es, "Copy
  of" en). The user can edit it before saving.
- The **ingredient states**: every line of the duplicated event
  starts in `to_order` (the initial state for non-Rebost categories)
  or `missing` (for Rebost). Even if the source event had everything
  in `at_home`, the duplicate starts fresh as if the user hadn't
  procured anything yet.
- The event **status** (derived per Spec 008 §2.4): naturally falls
  out from the ingredient states above — without ingredients yet
  procured and no date, the new event is `in_preparation`.
- All **orders** for the source event (`orders` and `order_items`
  rows). The new event has zero orders. The user generates new
  orders when needed.
- Any **photos** associated with the source event (per §2.2 below).
  Photos belong to the original event; the duplicate starts photoless.

**Flow**:

1. User taps "Duplica" on the source event's detail screen (in the
   AppBar overflow menu or as a dedicated action).
2. A confirmation dialog appears: "Vols duplicar aquest esdeveniment?
   La còpia tindrà el mateix menú però sense data ni ingredients
   demanats." with options "Duplica" / "Cancel·la".
3. On confirm, a new event is created with the rules above, and the
   user is navigated to the new event's detail screen — open in
   edit mode on the name and date fields so they can complete the
   essentials quickly.
4. The new event appears in the events list under "En preparació"
   (since it has no procured ingredients).

Translations for the new strings:

- "Duplica" (ca) / "Duplicar" (es) / "Duplicate" (en).
- "Copia de" (ca) / "Copia de" (es) / "Copy of" (en).
- "Vols duplicar aquest esdeveniment? La còpia tindrà el mateix menú
  però sense data ni ingredients demanats." (ca + es + en
  translations).

No new database tables. The operation is implemented as a
transactional batch INSERT that copies the relevant rows with the
reset rules applied.

### 2.2 Photos for dishes, ingredients, and events

**Observed**: today the app is entirely text-based. A user organising
their fifth or sixth Catalan stew won't remember which one was the
good version just from the name. Photos of dishes help recall. Photos
of ingredients help identify weird-named items at the supplier (e.g.
"what does *llampuga* look like again?"). And photos of events serve
as a personal record of what you actually pulled off.

**Fix**: add photo upload and display for three entities, with
different cardinalities:

- **Catalog dish**: **one photo** (the "main" photo of the dish).
- **Catalog ingredient**: **one photo** (the "main" photo).
- **Event**: **multiple photos** (an album, presented as a carousel).

#### 2.2.1 Storage

Photos are stored in **Supabase Storage**, in the same Supabase
project as the database, **EU region (Frankfurt)** — consistent with
the existing data residency policy.

Create three buckets:

- `dish-photos` — one photo per dish, named `{dish_id}.jpg`.
- `ingredient-photos` — one photo per ingredient, named
  `{ingredient_id}.jpg`.
- `event-photos` — multiple photos per event, named
  `{event_id}/{photo_id}.jpg`.

All buckets are **private** by default. Access is gated through
Supabase's RLS-style row-level security so only members of the
relevant group can read/write.

Bucket-level RLS policies:
- `dish-photos`: SELECT and INSERT/UPDATE/DELETE allowed if the dish
  belongs to a group the requesting user is a member of.
- `ingredient-photos`: same rule, on `ingredients.group_id`.
- `event-photos`: same rule, on `events.group_id`.

#### 2.2.2 Compression on upload

To keep within the Supabase free tier (1 GB Storage included), all
photos are compressed on upload:

- **Format**: JPEG (good compression, universal compatibility).
- **Max dimension**: 1600 px on the longest side (resize before
  upload).
- **Quality**: 85% (good balance of quality and size).
- **Target size**: ≤ 500 KB per photo after compression. Photos that
  exceed this even after compression are still accepted (no hard
  block), but the compression step ensures most photos are well
  below.

Use a Flutter image compression package such as
`flutter_image_compress` or equivalent. The implementer chooses the
right library; the criterion is reliable compression on Android.

#### 2.2.3 Thumbnails

For inline display (event cards, dish list rows, ingredient rows),
the photo appears as a small **thumbnail**:

- **Size**: 80×80 px (rendered).
- **Source**: the same full-resolution JPEG is fetched and displayed
  scaled down. We do **not** generate separate thumbnail files at
  upload time (deferred — adds complexity for marginal benefit on a
  small user base).
- **Cached**: the Flutter image cache handles repeated views without
  re-fetching.

Optimisation note (out of scope for this spec, deferred): later we
can use Supabase's image transformation service or generate
thumbnails at upload to save bandwidth on slow connections. For
now, the same JPEG is reused.

#### 2.2.4 Upload UI

For each entity:

- A **camera/photo icon** is added to the entity's editor screen
  (dish editor, ingredient editor, event detail/editor).
- When the entity has no photo yet, the icon is shown as a circular
  placeholder with a camera glyph (e.g. `Icons.add_a_photo`).
- When the entity has a photo, the icon shows the photo as a thumbnail.
- Tapping the icon opens a sheet with options:
  - **"Fes una foto"** / **"Hacer una foto"** / **"Take a photo"** —
    opens the device camera.
  - **"Tria de la galeria"** / **"Elegir de galería"** / **"Pick
    from gallery"** — opens the device gallery.
  - **"Treu la foto"** / **"Quitar foto"** / **"Remove photo"** —
    only shown if a photo already exists.
- Camera and gallery permissions are requested at first use of the
  respective option. If denied, show a non-blocking message
  explaining the user can grant the permission in system settings.
- For events (multiple photos), the icon opens the carousel view
  (see §2.2.5) which has its own "+" button to add more photos.

#### 2.2.5 Carousel view for event photos

When an event has at least one photo, the event detail screen shows
a small thumbnail row (horizontal scroll) of all photos. Tapping any
thumbnail opens a **full-screen carousel viewer**:

- Photos displayed at full screen, with horizontal swipe between
  them.
- Pinch-to-zoom on individual photos (use a standard Flutter package
  like `photo_view`).
- A "delete" icon in the top-right of the viewer allows removing the
  current photo (with confirmation).
- A "+" / "add" icon allows adding a new photo to the event from
  within the carousel.
- Back arrow / system back returns to the event detail screen.

For dishes and ingredients (single photo), tapping the thumbnail
opens a similar viewer but with only one photo and no carousel
navigation.

#### 2.2.6 Schema

Add three new columns / tables:

- `dishes.photo_path TEXT` (nullable) — relative path in the
  `dish-photos` bucket (e.g. `{dish_id}.jpg`). Nullable means no
  photo yet.
- `ingredients.photo_path TEXT` (nullable) — same convention for
  ingredients.
- A new table **`event_photos`**:
  ```
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid()
  event_id     UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE
  photo_path   TEXT NOT NULL
  position     INT NOT NULL DEFAULT 0  -- ordering within the carousel
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
  ```
  with an index on `(event_id, position)` for ordering.

Order semantics for `event_photos`: ascending `position`, then
ascending `created_at` as tiebreaker. When a new photo is added,
`position` defaults to the current count of photos in the event (so
it goes to the end).

#### 2.2.7 Cleanup on deletion

When the parent entity is deleted, photos are deleted too:

- Deleting a dish: also delete `{dish_id}.jpg` from `dish-photos`.
- Deleting an ingredient: also delete `{ingredient_id}.jpg` from
  `ingredient-photos`.
- Deleting an event: cascade deletes `event_photos` rows (via
  `ON DELETE CASCADE`); also delete all blobs under
  `{event_id}/` from `event-photos`.

These cleanup operations happen in the same transaction or
sequentially right after the row deletion. If the blob deletion
fails (network error, etc.), log and continue — the user-visible
delete operation still succeeds; orphan blobs can be cleaned up by
a future background job (not in scope).

Migrations:
- `20260612010000_add_photo_path_to_dishes_and_ingredients.sql`
- `20260612020000_create_event_photos_table.sql`
- `20260612030000_create_photo_storage_buckets.sql` (also defines
  RLS policies, executed via Supabase SQL editor with admin
  privileges if the regular migration role can't manage buckets).

### 2.3 Contact picker for supplier categories

**Observed**: when configuring a supplier (Settings > Proveïdors >
[category]), the user manually types the phone number and email
address. This is error-prone (typing on a phone with autocorrect
mangling phone numbers and emails) and redundant — the user almost
certainly already has the supplier in their phone contacts.

**Fix**: add a "Tria del contactes" / "Elegir de contactos" / "Pick
from contacts" button next to the phone and email fields on the
supplier category detail screen. Tapping it:

1. **Requests permission** (Android `READ_CONTACTS`) at first use.
   If the user denies, show a non-blocking message: "Per fer servir
   aquesta opció, has d'autoritzar l'accés als contactes a la
   configuració del telèfon."
2. **Opens the device's contact picker** (use a Flutter package such
   as `flutter_contacts` or `contacts_service` — implementer
   chooses).
3. The user picks one contact.
4. The app extracts:
   - The contact's **display name** → autofills the "Nom" field of
     the supplier (introduced in Spec 008 §2.3).
   - The contact's **phone number(s)** → autofills the phone field.
   - The contact's **email(s)** → autofills the email field.
5. **If the contact has multiple phones or emails**, a dialog
   appears asking the user to pick one of each:
   - "Aquest contacte té diversos telèfons. Quin vols fer servir?"
     with the list as radio buttons.
   - Same for emails.
6. The user reviews the autofilled values and can edit any of them
   before saving (the AppBar check icon, per Spec 008 §2.3 standard).

Permission handling:
- The permission request is **only triggered** when the user explicitly
  taps the contact picker button — not at app launch.
- If the user has previously denied with "don't ask again", show a
  message explaining how to enable the permission in system settings,
  with a deep link to the app's settings page if Flutter supports it
  (`app_settings` package or similar).

Translations:
- "Tria del contactes" / "Elegir de contactos" / "Pick from contacts".
- "Aquest contacte té diversos telèfons. Quin vols fer servir?"
- "Aquest contacte té diversos correus electrònics. Quin vols fer
  servir?"
- Permission denied messages (ca/es/en).

Android manifest: add the `READ_CONTACTS` permission to
`android/app/src/main/AndroidManifest.xml`. iOS not in scope for
this round.

No schema changes — the picked values just fill the existing fields.

### 2.4 `at_home` available from any supplier category

**Observed**: today, when changing the state of an ingredient that
belongs to a regular supplier category (Peixateria, Verduleria,
etc.), the available state options are the four "procurement" states
(`to_order`, `ordered`, `received`, `missing`) — but **`at_home` is
missing from the menu**. The user can't say "I already have this
fish at home from another time" without manually changing the
ingredient's category to Rebost, which is conceptually wrong.

**Fix**: add `at_home` as an always-available state option in the
ingredient state picker, regardless of the ingredient's supplier
category.

The state picker (wherever it's rendered — typically the shopping
panel and the line editor) shows the five states for non-Rebost
categories:

- Per demanar (`to_order`)
- Falta (`missing`)
- Retrassat (derived: `ordered` + past `needed_by_date`)
- Demanat (`ordered`)
- Rebut (`received`)
- **A casa (`at_home`) ← new addition for non-Rebost categories**

For Rebost, the picker continues to show only:

- A casa (`at_home`)
- Falta (`missing`)

(Rebost stays binary, per Spec 007.)

**Behavioural notes**:

- Marking an ingredient as `at_home` from any category means "I
  already have it; no procurement needed". It contributes to the
  event's "Ready" status calculation just like `received` does
  (per Spec 008 §2.4 derivation).
- The transition matrix (which states can go to which) for non-Rebost
  categories: continue to allow any state to transition to any other
  state at user discretion (free matrix, per Spec 007). `at_home`
  is just added as a possible destination from any state.
- No schema change. The `ingredient_state` enum already includes
  `at_home` for the Rebost case; we just stop hiding it in the UI
  for non-Rebost categories.

This is a UI-only fix in the state picker widget. The visual
treatment of `at_home` (icon, colour) follows the existing
convention from Spec 007 round 2 — green / "have it" colour token.

---

## 3. Out of scope (Fase 1 items explicitly deferred)

The following Fase 1 items have been explicitly deferred from this
round and will be addressed in future specifications:

- Rebost as dynamic stock with quantities (today's binary `at_home`/
  `missing` model is retained).
- Full menu preview screen.
- Quantity scaling by event format (seated vs buffet vs other).
- Cooking schedule / preparation timeline.
- Verification that menu servings match guest count.
- Sharing a group with another user (multi-user collaboration).

The following item has been moved to Fase 2:

- **Importing dish recipes from a URL** (web scraping / JSON-LD /
  AI-based extraction). Requires a proxy backend for AI calls and
  significantly more design. Tracked for Fase 2 along with premium
  model, conversational AI assistant, e-commerce integrations, and
  iOS port.

---

## 4. Acceptance criteria

The assignment is complete when the project owner can verify all of
the following on the Android device:

### §2.1 Event duplication

1. From an event detail screen, an overflow menu item or action
   "Duplica" is available.
2. Tapping it shows a confirmation dialog. On confirm:
   - A new event is created with the same menu structure (dishes,
     servings, ingredient lines including quantities,
     reference_servings, prep_notes, and per-line supplier
     overrides).
   - The new event's name defaults to "Copia de [original name]".
   - The new event has no date.
   - All ingredients are in their initial state (`to_order` for
     non-Rebost, `missing` for Rebost).
   - No orders are copied.
   - No photos are copied.
3. The user is navigated to the new event's detail screen, with the
   name and date fields ready to be edited.
4. The new event appears in the "En preparació" section of the
   events list.

### §2.2 Photos

5. The dish editor and ingredient editor each have a photo icon
   that, when no photo is set, shows a camera placeholder. Tapping
   it offers "Take a photo" / "Pick from gallery". After upload, the
   icon shows the photo as an 80×80 thumbnail.
6. The thumbnail is tappable and opens a full-screen viewer with
   pinch-to-zoom and a remove option.
7. The event detail screen has a thumbnail row showing all the
   event's photos (in `position` order). Tapping any thumbnail opens
   a full-screen carousel with horizontal swipe between photos,
   pinch-to-zoom, and add/remove actions.
8. Photos are compressed before upload to ≤ 500 KB JPEG, max 1600 px
   on the longest side. Photos are stored in Supabase Storage in
   the EU region.
9. Photos are private — only accessible by members of the owning
   group (verified by attempting access with no auth or wrong group).
10. Deleting a dish, ingredient, or event also deletes the
    associated photo blobs from Storage.

### §2.3 Contact picker

11. The supplier category detail screen has a "Pick from contacts"
    button. Tapping it requests the `READ_CONTACTS` permission at
    first use.
12. After granting permission, the device's contact picker opens.
    Picking a contact autofills the Nom, phone, and email fields.
13. If the picked contact has multiple phones or emails, a dialog
    asks the user to pick one of each.
14. Denied or revoked permission shows a graceful message; the user
    can still type fields manually.

### §2.4 `at_home` universal

15. In the state picker for any non-Rebost ingredient, the option
    "A casa" is now available alongside the four procurement states
    plus the derived "Retrassat".
16. Selecting "A casa" for a non-Rebost ingredient persists the
    state. The ingredient is treated as having no procurement need
    (contributes to event "Ready" status like `received` does).
17. Rebost remains binary (only "A casa" and "Falta").

### General

18. All affected screens follow the design system, the EditScaffold
    pattern (Spec 008 Fixes), and have no hardcoded user-facing
    strings.
19. All migrations apply cleanly to the remote Supabase project.
20. All existing flows continue to work without regression.
21. The work is committed to a new branch `feat/spec-009-fase-1` with
    a clean PR description listing the four items.

---

## 5. Notes for the implementer

- The four items are largely independent and can be implemented in
  parallel or in sequence. Suggested order:
  - §2.4 first (smallest, no model change).
  - §2.1 next (transactional batch INSERT, no new external systems).
  - §2.3 next (involves Android permissions, contact picker library).
  - §2.2 last (most substantial — Supabase Storage, compression,
    new UI patterns).
- Stop and ask the project owner before improvising on these
  ambiguities:
  - **§2.2**: which Flutter image compression and image picker
    libraries to use (there are several reasonable choices). Confirm
    once before adding the dependency.
  - **§2.2**: whether to use Supabase's `image transformation`
    feature (available on Pro Plan) for on-the-fly thumbnails versus
    the simple "fetch and downscale client-side" approach (chosen as
    default here). Confirm if you'd prefer the Pro path.
  - **§2.3**: which Flutter contacts library to use. The two
    common choices have different API surfaces.
- Migrations to apply remotely with `supabase db push`:
  - `20260612010000_add_photo_path_to_dishes_and_ingredients.sql`
  - `20260612020000_create_event_photos_table.sql`
  - `20260612030000_create_photo_storage_buckets.sql`
- The photo upload UI should reuse the existing `EditScaffold`
  pattern where applicable.
- For Supabase Storage bucket creation, the migration may need to be
  applied via the Supabase dashboard SQL editor if the migration
  role lacks bucket-management privileges. Confirm during
  implementation.
- The PR description should reference each of the four items by its
  §2.x number, with a short summary and checkbox state. Photos and
  contact picker each warrant a brief paragraph in the PR
  description explaining the chosen library and permission flow.
