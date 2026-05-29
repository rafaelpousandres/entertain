# Specification 004 — Dishes and ingredients (MVP screen group 2)

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read `CLAUDE.md`, `entertain - Data model.md`, and `entertain - Design system.md`
> before starting. This specification is the only scope for this assignment; do
> not pull work forward from later screen groups or phases.

---

## 1. Goal

Build the **Dishes and ingredients** screen group of the MVP — the second of the
three MVP groups. Together with the Event group already delivered in
Specification 003, this completes the path from "create an event" to "the event
has a menu of dishes built from reusable ingredients". The shopping list and
WhatsApp message belong to the next group and are out of scope here.

The five screens are:
1. **Dish catalog** — the list of reusable dishes, grouped by category.
2. **Dish editor** — create or edit a dish: name, category, base servings,
   description, and its line items (ingredients).
3. **Ingredient line editor** — the screen that edits a single ingredient line
   within a dish.
4. **Ingredient catalog** — the list of reusable ingredients, with their default
   unit and supplier category.
5. **Add dish to menu** — picker invoked from the event detail screen to choose
   a dish from the catalog and add it to the event's menu, materialising the
   "copy on add" snapshot decision from the data model.

This group ends with the user able to build their dish catalog, build their
ingredient catalog, add dishes to events, and edit the per-event copy of each
dish's ingredient lines without affecting the catalog.

---

## 2. Lifecycle of this assignment — phased delivery

This is a larger assignment than Specifications 002 or 003. To control risk it
is delivered in **two phases on the same branch**, with a checkpoint between
them:

- **Phase 2A — Catalogs and editors**: screens 1, 2, 3, and 4 above. At the end
  of Phase 2A, the project owner validates on device that the dish and ingredient
  catalogs are usable end to end (creating, editing and deleting dishes and
  ingredients, editing ingredient lines within dishes). The event detail / menu
  screen from Specification 003 stays as it was — still empty-menu state.
- **Phase 2B — Add dish to event menu**: screen 5. Wires the catalog to the
  event detail / menu screen of Specification 003, materialising `event_dishes`
  and `event_dish_ingredients` with the copy-on-add behaviour. After this phase
  the menu in the event detail screen is populated and editable per event.

Both phases live on the **same feature branch** (suggested name
`feat/spec-004-dishes-ingredients`) and end in **a single pull request** against
`main`. Phase 2A is a checkpoint commit on that branch, not a separate PR. The
PR is opened (or marked ready for review) only after Phase 2B is also complete.

Between Phase 2A and Phase 2B, the implementer pauses and notifies the project
owner; the owner validates 2A on device and only then is 2B started.

---

## 3. Scope — what to do

### 3.1 General

- All five screens build on top of the existing app: the Supabase client and
  anonymous-session bootstrap from Specification 002 (now including the
  `GRANT` migration), the design system / theme, the i18n setup, Riverpod, and
  go_router.
- Reuse the UI toolkit delivered in Specification 003 (primary and secondary
  buttons, icon circle, collapsible section header, form field and tile,
  segmented choice, stepper). Add new components only if a genuinely new
  pattern is needed; if so, add it to `lib/ui/` consistently with the existing
  toolkit and the design system.
- All user-visible strings go through i18n (intl + ARB) per `CLAUDE.md` — no
  hardcoded string literals. Extend the existing ca/es/en ARB files; Catalan
  is the display language for the MVP.
- All data access goes through the corresponding Phase 0 tables with RLS in
  force. Catalog entities are group-scoped: resolve the current user's group
  from their membership and read / write within it.

### 3.2 Ingredient catalog (screen 4) — Phase 2A

- A screen listing the user's group ingredients. Each row shows the ingredient
  name, its default unit (via `default_unit_id`), and its default supplier
  category (via `default_supplier_category_id`) when set.
- A clear empty state, a primary "New ingredient" action, and a tap-to-edit
  interaction on each row.
- An ingredient editor (entered via "New ingredient" or by tapping a row) with
  these fields:
  - **Name** (`name`) — text. Required.
  - **Default unit** (`default_unit_id`) — a single choice from the `units`
    table. Required. Use a selector that respects the design system; the unit
    catalog is system-content and translated, so the displayed label must come
    from `translations` in the current locale (Catalan in the MVP).
  - **Default supplier category** (`default_supplier_category_id`) — a single
    choice from `supplier_categories`. Optional. Same translation rules.
  - **Preparation description** (`prep_description`) — optional, multi-line.
  - The optional package-equivalence pair (`package_equiv_value` and
    `package_equiv_unit_id`) is **out of scope for this assignment** — see §4.
- Save inserts or updates the ingredient within the user's group.
- Edit mode offers delete (soft delete, `deleted_at`), with the same overflow
  menu + destructive confirmation pattern used for events in Specification 003.

### 3.3 Dish catalog (screen 1) — Phase 2A

- A screen listing the user's group dishes, **grouped by `category`** using the
  collapsible section-header component from the design system (category icon,
  label, count). Each dish row shows the dish name and a chevron.
- A clear empty state, a primary "New dish" action, and a tap-to-edit
  interaction on each row.

### 3.4 Dish editor (screen 2) — Phase 2A

- One screen used for both creating a new dish and editing an existing one.
  Fields, each mapped to the `dishes` table:
  - **Name** (`name`) — text. Required.
  - **Category** (`category`) — single choice from the dish category enum
    (aperitif / starter / main / dessert / drink / other). Required.
  - **Base servings** (`base_servings`) — integer with a stepper, default `4`.
  - **Description** (`description`) — optional, multi-line.
- Below the dish fields, a **list of ingredient lines** (`dish_ingredients` for
  this dish). Each line shows the ingredient name, quantity and unit, and the
  per-line preparation note when set. Lines are ordered by `sort_order`.
- The list has a primary "Add ingredient" action that opens the Ingredient
  line editor (screen 3). Tapping an existing line opens the same editor in
  edit mode. Deleting a line is allowed from the line editor.
- Save inserts or updates the dish and its lines within the user's group.
- Edit mode offers delete (soft delete, `deleted_at`), with the same overflow
  menu + destructive confirmation pattern used elsewhere.

### 3.5 Ingredient line editor (screen 3) — Phase 2A

- A screen that edits one row of `dish_ingredients` belonging to the dish being
  edited. Fields:
  - **Ingredient** (`ingredient_id`) — pick one from the ingredient catalog.
    Required. The picker must allow creating a new ingredient on the fly when
    the desired one is not in the catalog yet (this is the low-friction path
    that makes data entry tolerable; see §6).
  - **Quantity** (`quantity`) — numeric.
  - **Unit** (`unit_id`) — single choice from the units family allowed by the
    chosen ingredient (see §3.6). Defaults to the ingredient's
    `default_unit_id`.
  - **Preparation note** (`prep_note`) — optional, multi-line. Overrides the
    ingredient's base `prep_description` for this dish.
- The line carries no supplier assignment: in the catalog, the supplier is the
  ingredient's `default_supplier_category_id`; per-event overrides happen on
  `event_dish_ingredients`, not here.
- Save inserts or updates the line within the dish; delete removes the line
  from the dish.

### 3.6 Units behaviour across catalog screens

- Each ingredient has a single unit, or a convertible family (mass: g/kg;
  volume: ml/l), via `default_unit_id`. The line editor must restrict the
  selectable units for a given line to that ingredient's family — never let a
  user enter, say, "200 ml" of an ingredient whose default unit is grams.
- Package units (`unit` magnitude `package`, e.g. `manat`, `pot`, `safata`) are
  valid as an ingredient's default; in that case the line accepts only that
  unit. The optional conversion `package_equiv_value` / `package_equiv_unit_id`
  is **not configurable in this assignment** — see §4.

### 3.7 Add dish to event menu (screen 5) — Phase 2B

- Reached from the Event detail / menu screen of Specification 003 (which until
  now showed an empty-menu state). Add a primary "Add dish" action on that
  screen, opening this picker.
- The picker shows the user's dish catalog, grouped by `category` exactly as in
  the Dish catalog screen. Tapping a dish adds it to the event's menu.
- **Copy on add** — when a dish is added:
  - A row is inserted in `event_dishes` for this `(event_id, source_dish_id)`,
    with a snapshot of the dish `name` into `dish_name` and `category` into
    `category`, and `servings` defaulting to the event's `guest_count`.
  - For each row of `dish_ingredients` belonging to the source dish, a
    corresponding row is inserted into `event_dish_ingredients`, copying
    `ingredient_id`, `ingredient_name` (snapshot of the current ingredient
    name), `quantity`, `unit_id`, `prep_note`, and `sort_order`. The
    `supplier_category_id` of each copy is initialised from the ingredient's
    `default_supplier_category_id` (snapshot) and is intended to be
    overridable later from the event menu detail (out of scope here).
  - The catalog rows are **not modified**. Subsequent edits to the catalog dish
    or its lines must not propagate to events that already used it.
- After the dish is added, return to the Event detail / menu screen, which now
  shows the new dish under its category section in the menu.
- Editing the per-event copy of a dish (its `event_dish_ingredients`) and
  removing a dish from an event's menu are part of this group as the minimum
  needed to make the menu usable; see §3.8.

### 3.8 Editing the per-event menu — Phase 2B

- From the Event detail / menu screen, tapping an `event_dish` row opens a
  small per-event dish detail showing the snapshot fields and its ingredient
  lines (the rows in `event_dish_ingredients`). Each line is tappable and
  opens an editor analogous to the catalog ingredient line editor, but
  operating on `event_dish_ingredients` instead of `dish_ingredients`. The
  fields on the per-event line are the same as in the catalog plus
  `supplier_category_id`, which can be overridden here (default is the
  snapshot value from when the dish was added).
- The per-event dish detail offers removing the dish from the menu (physical
  delete of the `event_dish` and its `event_dish_ingredients`, since these are
  per-event copies and not catalog data; the data model marks them without
  `deleted_at`).
- Reordering dishes within an event and the dish servings stepper are
  **out of scope** — see §4.

### 3.9 Navigation and state

- Wire the new screens with go_router:
  - From the Event group home, surface entries into the Dish catalog and the
    Ingredient catalog. Pick a coherent navigation model and flag the choice
    (e.g. tabs in the home, a secondary screen reached from settings later,
    or simple top-level routes accessible from a small drawer / overflow on
    the home). Keep it minimal: a bottom navigation bar is acceptable but not
    required; the goal is reachability, not navigation richness.
  - Dish catalog ↔ Dish editor ↔ Ingredient line editor. Ingredient catalog ↔
    Ingredient editor. Event detail → Add dish picker → Event detail. Event
    detail → per-event dish detail → per-event line editor.
- Manage screen state and data with Riverpod, consistent with how the app is
  already structured. Reuse and extend the providers / repository layer added
  in Specification 003.

---

## 4. Out of scope

Explicitly **not** part of this assignment:
- Editing `package_equiv_value` and `package_equiv_unit_id` on ingredients (the
  optional package-to-mass/volume conversion). The columns exist in the schema
  and may be populated later from a settings screen; the catalog UI here
  ignores them.
- Adding to / editing the catalog of `units` and `supplier_categories` —
  these are system content seeded in Specification 002 and read-only from the
  client.
- The shopping list (generating `orders` and `order_items`), the WhatsApp
  message screen, settings, and signature (all of screen group 3).
- Reordering dishes within an event's menu (`event_dishes.sort_order` is set
  on add but not edited).
- Per-event-dish servings adjustment (`event_dishes.servings` is initialised
  from `events.guest_count` on add but not edited from the UI). The buffet
  rationing distinction in the data model is captured but not yet usable here.
- Media (photos) for dishes, ingredients, events. Phase 0.x.
- Quantity scaling (Phase 1) and total-food verification (Phase 1).
- Real authentication UI — the anonymous session from Specification 002 is
  what these screens run on.

---

## 5. Acceptance criteria

The assignment is complete when the project owner can verify all of the
following on the Android device:

**Phase 2A — Catalogs and editors:**

1. The Ingredient catalog opens, shows an empty state when empty, and lets the
   user create / edit / delete ingredients with name, default unit, default
   supplier category, and preparation description. Unit and supplier-category
   labels appear translated in Catalan. Deletion is soft (`deleted_at`).
2. The Dish catalog opens, shows an empty state when empty, and lets the user
   create / edit / delete dishes with name, category, base servings, and
   description. The catalog is grouped by category with collapsible headers
   and a category count. Deletion is soft.
3. From a dish editor, the user can add ingredient lines, edit their quantity,
   unit, and preparation note, and remove them. The unit selector is
   restricted to the chosen ingredient's family. The "add new ingredient"
   path inside the picker works without leaving the dish editor flow.
4. The Event detail / menu screen from Specification 003 still shows the
   empty-menu state — Phase 2A does not yet wire the menu.
5. All Phase 2A screens follow the design system and reuse the UI toolkit
   from Specification 003. No hardcoded user-facing strings.
6. The Phase 2A work is committed to the feature branch and pushed; **the PR
   is not yet opened**.

**Phase 2B — Add dish to event menu:**

7. The Event detail / menu screen now has an "Add dish" primary action that
   opens the catalog picker.
8. Adding a dish to an event creates the corresponding `event_dishes` row with
   `dish_name`, `category` and `servings` snapshots, and one
   `event_dish_ingredients` row per `dish_ingredients` line of the source dish,
   with `ingredient_name`, quantity, unit, prep note, sort order, and
   `supplier_category_id` snapshots.
9. Editing the catalog dish or any of its lines **after** it has been added to
   an event does not change the event's copy.
10. From the event detail, the user can open a per-event dish, edit any of its
    ingredient lines (including overriding `supplier_category_id`), and remove
    the dish from the event's menu (physical delete of the per-event rows).
11. All Phase 2B screens follow the design system. No hardcoded user-facing
    strings.
12. The full work is on a single feature branch with a single pull request
    against `main`, opened only at the end of Phase 2B, leaving `main`
    shippable per `CLAUDE.md`.

---

## 6. Notes for the implementer

- This group is where the project owner manually enters his own dishes and
  ingredients from his Excel data. Keep the create / edit flows fast and
  low-friction: sensible defaults, only the truly required fields enforced,
  forgiving validation, and a quick path from a dish editor to creating a new
  ingredient on the fly without losing the dish being edited.
- The data model is the source of truth for structure. If a field, relationship
  or copy-on-add detail does not translate cleanly to a screen, stop and flag
  it on claude.ai rather than improvising a structural change. In particular,
  the copy-on-add behaviour of §3.7 is delicate and worth verifying step by
  step against `entertain - Data model.md` §3.3.
- The PR description should reflect the two-phase structure and list the two
  sets of acceptance criteria separately so validation is unambiguous.
- Keep scope to this screen group. Do not pull shopping-list, WhatsApp, or
  settings work forward; do not add reordering, servings adjustment, photos,
  or the package-equivalence editor.
- At the boundary between Phase 2A and Phase 2B, pause and notify the project
  owner with a short summary of what is testable in 2A. Do not proceed to 2B
  until the owner confirms.
