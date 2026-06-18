# Specification 016 — Prepared dishes & drinks refinements

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read CLAUDE.md, "entertain - Decisions de disseny.md", Spec 014, and
> Spec 013 before starting. This Spec refines Spec 014 after on-device
> validation: it simplifies the bought-dish model, redefines the drink model,
> fixes two bugs, and adds presentation polish. Spec 014 was just published
> to Internal Testing with no real data yet, so model changes here are safe.

---

## 1. Goal

On-device validation of Spec 014 surfaced a model that was more complex than
needed and two bugs. This Spec:
- **Simplifies prepared (bought) dishes** to reuse the cooked-dish servings
  model (no separate unit/per-unit fields).
- **Redefines drinks** to a units-only model (no servings, no scaling) with a
  predefined **denomination** (bottle, can, jug…).
- **Fixes** the bought-dish-shows-ingredients bug and the drink-photo upload
  bug.
- **Polishes** plurals, name capitalisation, the splash logo, and the order
  time format.

---

## 2. Prepared (bought) dishes — simplify

A bought dish should behave like a cooked dish for servings, differing only in
that it is bought (no ingredients) and has a supplier.

### 2.1 Model
- On `dishes`: **drop `purchase_unit` and `servings_per_unit`**.
  `base_servings` is reused as **servings one unit provides** for a bought
  dish (e.g. Truita = 4 → one truita serves 4). For cooked dishes
  `base_servings` keeps its current meaning. Same column, same concept
  ("servings per base unit").
- On `event_dishes`: the bought-dish copy must remain an **immutable
  snapshot** able to compute units. It needs both the **servings to serve**
  (scales with the event, like cooked) and the **servings-per-unit** snapshot
  taken at add time. Drop `purchase_unit`. Reconcile the existing columns so
  that `units = ceil(servings_to_serve / servings_per_unit)` is computable
  from the snapshot alone (do not read the live catalog dish). Pick the
  cleanest column arrangement and flag it; `servings_per_unit` on
  `event_dishes` is **not** redundant (it is the per-unit snapshot, distinct
  from the to-serve servings), so it may stay there even though it is dropped
  from `dishes`.

### 2.2 Editor
- The bought-dish editor uses the **same "Racions base" stepper (− 4 +)** as
  cooked dishes — no separate "purchase unit" or "servings per unit" fields.
- Supplier category is **preselected to the system "Plats preparats"**
  category, **editable** (a bought dish may be bought elsewhere — supermarket,
  bacallaneria). Not mandatory, not fixed.
- **Hide the "preparation" field** when the dish is bought (it has no meaning
  for a ready-made dish).

### 2.3 Shopping line
- Quantity = `ceil(servings_to_serve / servings_per_unit)` units.
- Display as a count with the dish name (no unit label), consistent with how
  ingredient lines render, e.g. "3 × Canelons" (implementer matches the
  existing line style).

### 2.4 Bought dish inside an event — bug
A bought dish added to an event currently shows an empty "Ingredients"
section with an "add ingredient" button. **Fix**: when the event dish is
bought, do **not** show the ingredients section or the add-ingredient action;
show its bought info instead (supplier / a "Plat preparat" indicator). This
mirrors the editor, which already hides ingredients for bought dishes.

---

## 3. Drinks — units-only model (Model B)

Drinks do **not** have servings and do **not** scale by guests. A drink is
bought in whole **units** of a named **denomination**; the user sets the
quantity directly.

### 3.1 Model
- On `drinks`: **drop `base_servings` and `servings_per_unit`**. Add a
  **denomination** (a code from a predefined list — see §3.3), plus the
  existing `supplier_category_id`. A drink = name + supplier category +
  denomination + photo.
- On `event_drinks`: **drop `servings` and `servings_per_unit`** (and any
  base-servings). Add **`quantity`** (integer, number of units, set manually,
  **no scaling** from guest count; sensible default e.g. 1). Snapshot the
  denomination and supplier category. Keep `state`.

### 3.2 Editor & event
- Drink editor: name, supplier category **preselected to system "Begudes"**
  (editable), denomination picker (§3.3), photo. No servings.
- Adding a drink to an event: the user sets the **quantity of units** (e.g.
  2 ampolles); no guest-based scaling. Editable per event.
- Drinks remain excluded from the food servings/guest ratio (unchanged) and
  have no own count requirement (confirmed with owner).

### 3.3 Denomination — predefined list
A small **predefined, system list** of denominations, each with correct
**singular and plural** in ca/es/en, rendered via ICU plurals in the ARB
files (not free text — avoids Catalan plural edge cases). The drink stores a
**denomination code**; the app renders singular/plural by locale and count.

Initial set (extendable): bottle (ampolla/ampolles), can (llauna/llaunes),
jug/carafe (garrafa/garrafes), unit (unitat/unitats), pack (paquet/paquets),
litre (litre/litres). Implementer proposes the exact codes and the ARB
plural messages; the picker offers them by localised singular.

### 3.4 Shopping line
- Display as "{quantity} {denomination plural} de {name}", e.g.
  "2 ampolles de Vi negre", "2 llaunes de Cervesa". Use the ICU plural for the
  denomination. Included in the supplier message and shopping list, grouped by
  supplier (Spec 013 selection applies).

---

## 4. Drink photo upload — bug

Photos upload fine for prepared dishes but **fail for drinks**. The database
side is verified correct (bucket `drink-photos` exists; policy
`drink_photos_group_access` exists). The bug is in the **app upload path**:
investigate how a drink photo is uploaded — the target bucket, the object
path, and the `MediaEntityType.drink` routing — and make it match what the
policy expects (`{drink_id}.jpg` or `{drink_id}/{photo_id}.jpg` under
`drink-photos`). Compare against the working prepared-dish photo flow.

---

## 4b. Catalog consistency (Begudes follows Plats/Ingredients)

The new Begudes catalog and its add flow must follow the same accordion and
add-form conventions already established for Plats and Ingredients:

- **Special categories last**: in the Begudes accordion, the **Rebost**
  (pantry) category — and any "Sense categoria" group — sort to the **end** of
  the list, not interleaved (same as the Ingredients catalog). Rebost applies
  to drinks too (drinks you already have at home), with the same special
  treatment it gets elsewhere (e.g. no "Cap proveïdor" wording — see Spec 015;
  its supplier config stays hidden).
- **Preselect the open category on add**: pressing "Afegeix beguda" (and,
  consistently, "Afegeix ingredient") preselects the category of the open
  accordion section as an editable default, exactly as Plats/Ingredients do
  (PR #41). All-collapsed → first category. Rebost is not preselected as a
  buy-from supplier for items that are purchased (it means "already at home").

Apply the same ordering/preselection helpers used by the Ingredients catalog
so the three catalogs stay consistent.

## 5. Presentation polish

### 5.1 Plurals
Denomination plurals via ICU (§3.3). Audit other count strings touched here
for correct ca/es/en plural agreement.

### 5.2 Name capitalisation
Item names (drinks, and prepared-dish lines where applicable) should display
**capitalised consistently with how ingredient names are shown**. Apply the
same display rule used for ingredients.

### 5.3 Splash logo
Two issues on the native splash, both about the logo:
- The **native splash logo is cropped** (outer chairs cut off): Android 12+
  forces the splash icon inside a circle, so the artwork must sit inside the
  safe zone — **regenerate the native splash with more padding** (smaller
  artwork within the canvas) so nothing is clipped.
- The **size jump**: the large native logo then the smaller in-app overlay
  logo appear in sequence. Match the two sizes so the transition is
  continuous (native → overlay should look like one logo).

### 5.4 Order time format
The optional order time currently shows "13:00". Show it as **"13:00h"**
(append the hour mark), in the supplier message and wherever the time renders,
for ca/es/en.

---

## 6. Acceptance criteria

1. Migration: drops `purchase_unit`/`servings_per_unit` from `dishes` (and
   reconciles `event_dishes`); restructures `drinks`/`event_drinks` to the
   units-only model (denomination + quantity); shown before push. Tables were
   empty / only test data, so this is safe (note: existing test drinks may
   need recreating).
2. Bought-dish editor uses the cooked-dish servings stepper; no unit/per-unit
   fields; supplier preselected "Plats preparats" (editable); preparation
   hidden when bought.
3. Bought dish in an event shows no ingredients section / add-ingredient
   action.
4. Drink model: denomination (predefined, correct plurals) + manual unit
   quantity, no servings/scaling; supplier preselected "Begudes" (editable).
5. Shopping: bought dish → "N × name"; drink → "{n} {denomination-plural} de
   {name}"; both grouped by supplier with Spec 013 selection; in the message.
6. Drink photos upload successfully.
7. Begudes accordion sorts Rebost / "Sense categoria" last; "Afegeix beguda"
   preselects the open category (editable), consistent with Plats/Ingredients.
8. Names capitalised like ingredients; order time shows "13:00h"; native
   splash logo not clipped and continuous in size with the overlay.
9. flutter analyze clean; flutter test passes; tests updated for: bought-dish
   units = ceil(servings / servings_per_unit); drink quantity is manual (no
   scaling); denomination plural rendering.

---

## 7. Notes for the implementer

- Present the plan and the migration before any push. The migration mixes
  drops and adds across four tables; keep it one clearly-commented file.
- Reuse Spec 013 `supplier_resolution.dart`, the shopping pipeline, the
  media/photo flow, and the existing ICU/i18n setup.
- Flag the `event_dishes` column reconciliation (§2.1) — it is the one
  non-obvious model call (snapshot servings-per-unit vs to-serve servings).
- Data model doc (claude.ai) to update after: dropped/added columns, drink
  model change, denomination list. Note in PR.

Branch: `feat/spec-016-prepared-drinks-refinements`.
