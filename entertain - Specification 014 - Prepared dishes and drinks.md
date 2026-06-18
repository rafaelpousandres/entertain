# Specification 014 — Prepared dishes and drinks

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read CLAUDE.md, the Data model, "entertain - Decisions de disseny.md", and
> Spec 013 (supplier selection — this Spec reuses its supplier-resolution
> mechanism) before starting. This Spec adds two non-cooked menu item types:
> **prepared dishes** (bought, not broken into ingredients) and **drinks**
> (a new separate catalog). Both are the "degenerate case" of a recipe:
> a single purchase line instead of a list of ingredients.

---

## 1. Goal and context

Today a dish is always cooked from ingredients. Real use needs two more
kinds of menu item:

- **Prepared dish (bought)**: a dish you buy ready-made from a supplier
  (cannelloni from the deli, a cake from the bakery). It is **not** broken
  into ingredients — it is itself one purchase line.
- **Drink**: wine, beer, soft drinks. Also a single non-decomposable
  purchase line, but conceptually separate from food — entered in its own
  catalog and its own menu section.

Both share the same shape (non-decomposable item + supplier + servings) and
both reuse Spec 013's supplier model (a supplier category with one or more
suppliers, resolved at order time). The shopping flow already groups
everything by supplier; prepared dishes and drinks just add more lines.

**Design decisions already taken** (see Decisions doc):
- Prepared vs cooked is an **attribute of the dish** (`acquisition_mode`),
  stored from day one, so the two can be unified later without migration.
- Drinks live in a **separate catalog/table**, entered separately from
  dishes (matches the real mental flow: food and drink are planned apart).
- Both scale by **servings** like cooked dishes. Purchase **unit is
  optional**: if defined (with servings-per-unit), the app computes units to
  buy; if not, it shows scaled servings and the user judges quantity.

---

## 2. Scope

### 2.1 Dish acquisition mode (cooked / bought)

Add to `dishes`:
- `acquisition_mode` — enum (`cooked` | `bought`), `NOT NULL DEFAULT 'cooked'`.
- `supplier_category_id` — uuid nullable FK → `supplier_categories`, used
  only when `bought`.
- `purchase_unit` — text nullable (e.g. "safata", "unitat"), used only when
  `bought`.
- `servings_per_unit` — numeric nullable, used only when `bought` (how many
  servings one purchase unit provides).

`base_servings` already exists and is reused (the dish's default servings).

Dish editor: a **toggle** at the top — *Cuinat a casa* / *Comprat fet*.
- **Cuinat** (default): the existing editor — ingredients with quantities,
  base servings. Unchanged.
- **Comprat**: hide the ingredients section; show instead **supplier
  category** (picker), **base servings**, optional **purchase unit** +
  **servings per unit**, plus photo and preparation as today. No ingredients.

Switching the toggle on an existing dish: keep it simple for MVP — switching
to *bought* hides (does not delete) ingredient lines; switching back shows
them again. Flag if this proves messy; deleting ingredients on switch is not
desired (no data loss).

### 2.2 Drinks catalog (new)

New table `drinks` (per group, parallel to a prepared dish):
- `id`, `group_id`, `name`, `base_servings` (int), `supplier_category_id`
  (uuid nullable FK), `purchase_unit` (text nullable), `servings_per_unit`
  (numeric nullable), `created_at`, `updated_at`, `deleted_at`.
- Photos via the existing `media` table (entityType `drink`).
- No ingredients, no acquisition_mode (a drink is always "bought").

New **Begudes** catalog screen, parallel to Plats and Ingredients
(accordion grouped by supplier category, consistent with Spec 012). Add to
the app's main navigation. **Navigation layout**: adding a 5th destination
(Events, Plats, Begudes, Ingredients, Settings) may crowd the bottom nav —
the implementer proposes the layout in the plan (e.g. bottom nav vs a
combined catalogs area). Flag for confirmation.

### 2.3 Adding prepared dishes and drinks to an event

- **Prepared dishes** are dishes, so they are added to the event's **Menu**
  like any dish (they appear under their course category). They carry their
  `acquisition_mode`; a bought dish added to an event is an **immutable
  copy** like cooked dishes (snapshot of mode, supplier category, unit,
  servings-per-unit).
- **Drinks** are added in a **separate "Begudes" section** of the event Menu
  (or its own area), with its own "Afegeix beguda" button. Food and drink
  are entered separately. The implementer proposes where the Begudes section
  sits relative to the dish course sections; flag in plan.

New event-side table `event_drinks` (parallel to `event_dishes`): the drink
copied into the event, with its scaled servings (snapshot).

**Scaling**:
- Prepared dishes follow the same format rule as cooked dishes (seated →
  scale servings to guest count; buffet → keep base servings; adjustable).
- Drinks scale to **guest count by default** (everyone drinks; the
  seated/buffet distinction is a food concept), adjustable per event.

### 2.4 Servings totals and the food guideline

- The Menu food totals (Spec 012 §2.6: dishes · servings · servings/guest,
  and the 3–5 guideline) count **both cooked and bought dishes** — both are
  food. Bought dishes contribute their scaled servings.
- **Drinks are excluded** from the food serving totals (a drink serving is
  not "enough food"). Drinks may have their own small summary (e.g. total
  drink servings or units), but they do not feed the 3–5 food ratio.

### 2.5 Shopping: prepared dishes and drinks as purchase lines

Prepared dishes and drinks flow into the Shopping tab as **single lines**,
grouped by supplier exactly like ingredients, and use Spec 013's supplier
selection (the line's supplier category resolves to a concrete supplier at
order time).

**Quantity on the line** (the model A "optional unit" decision):
- If the item has `purchase_unit` + `servings_per_unit`: the line shows
  **units** = `ceil(scaled_servings / servings_per_unit)`, e.g. "3 safates ·
  Canelons" or "2 ampolles · Vi negre".
- If it has no unit defined: the line shows **scaled servings**, e.g.
  "Canelons · 12 racions" — the user judges how much to ask the supplier.

A prepared dish / drink line is **one line per item** (it does not explode
into ingredients). Aggregation key stays consistent with the rule
(item + unit + preparation); two different prepared dishes never merge.

Include prepared-dish and drink lines in the supplier message and the
"use as shopping list" output, after the ingredient lines, grouped by the
same supplier.

### 2.6 System categories

Create two new **system** supplier categories (available to all groups, like
butcher/fishmonger): **"Plats preparats"** and **"Begudes"**. They behave
like any category: the user can add one or more suppliers to them and set a
default (Spec 013). Users may also use any other category for prepared
dishes / drinks; these two are sensible defaults, not a constraint.

---

## 3. Out of scope

- Unifying the cooked and bought versions of the same dish into one entity
  ("this dish, 2 ways"): the model stores `acquisition_mode` to allow it
  later, but the MVP treats them as separate dishes. Not now.
- Per-ingredient supplier (Spec 013 §3 stands).
- Drink-specific attributes beyond the above (alcohol flag, volume, pairing):
  not now.
- Format-based drink heuristics beyond servings/guest: not now.

---

## 4. Acceptance criteria

1. Migration adds `acquisition_mode`, `supplier_category_id`,
   `purchase_unit`, `servings_per_unit` to `dishes`; creates `drinks` and
   `event_drinks`; creates the two system categories. Additive; shown before
   push.
2. Dish editor toggle cooked/bought; bought hides ingredients and shows
   supplier category + servings + optional unit/servings-per-unit; cooked
   unchanged; switching does not delete ingredient data.
3. Begudes catalog exists, accordion by supplier category, add/edit/delete a
   drink with supplier category, servings, optional unit/servings-per-unit,
   photo.
4. A prepared dish added to an event's menu scales like a cooked dish and is
   an immutable copy; a drink is added in its own section and scales to
   guests by default, adjustable.
5. Food serving totals include cooked + bought dishes; drinks excluded.
6. Shopping shows prepared dishes and drinks as single lines grouped by
   supplier; with unit defined → units via ceil; without → scaled servings;
   included in the supplier message and shopping-list output; supplier
   selection (Spec 013) applies.
7. Two system categories "Plats preparats" and "Begudes" available.
8. All new strings ca/es/en. flutter analyze clean; flutter test passes;
   new tests for: bought-dish unit computation (ceil, with/without unit),
   drink scaling to guests, food-totals excluding drinks, prepared/drink
   lines flowing into shopping grouped by supplier.

---

## 5. Notes for the implementer

- **Explore + plan first** (no Plan mode required, but present the plan
  before coding): report how the current dish editor, the event Menu
  rendering, the catalogs navigation, and the shopping aggregation are
  structured, and propose: (a) the navigation layout for a 5th catalog
  (Begudes), (b) where the event-Menu Begudes section sits, (c) whether
  `drinks` truly needs its own table vs an `event_drinks` mirror — confirm
  the parallel-to-event_dishes approach.
- **Reuse**: Spec 013's `supplier_resolution.dart` for resolving the line's
  supplier; the accordion + SectionHeader (Spec 012); the media/photo flow;
  the servings/locale formatting; the immutable event-copy pattern from
  cooked dishes.
- The prepared dish and the drink are the **same shape** (non-decomposable +
  supplier category + servings + optional unit). Consider a shared
  representation for the shopping line so both flow through one code path.
- Migration is additive (new columns, new tables, new system categories) —
  destructive-migration stop does not apply, but show the migration before
  push per house rule. Seeding system categories must be idempotent and
  per-the-existing-pattern for `is_system` categories.
- Data model doc (claude.ai) to be updated after: new columns on dishes,
  new tables drinks / event_drinks, two new system categories. Note in PR.

Branch: `feat/spec-014-prepared-dishes-and-drinks`.

Stop and ask the owner if:
- The navigation layout for a 5th catalog needs a product decision (bottom
  nav crowding).
- The event-Menu Begudes section placement is ambiguous.
- Switching acquisition mode on a dish with existing ingredients/usage turns
  out to have tricky edge cases (event copies already made, etc.).
