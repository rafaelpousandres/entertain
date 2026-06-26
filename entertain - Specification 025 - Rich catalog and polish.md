# Spec 025 — Rich catalog (multilingual + dietary + filter) & polish

Branch: `feat/spec-025-rich-catalog` · One PR · Migration shown before `db push`. AI used for
multilingual **name** backfill only (no AI for dietary). One coherent pass — no atomizing into
several specs.

## Context

This pass makes the catalog "adult" along three axes and sweeps the open polish items so none
linger:

- **Multilingual names** (ingredients, dishes, drinks): each entity stores its name in ca/es/en,
  marking which locale is the **original**. Resolves a latent i18n debt ("i18n from day one") and
  unlocks much better stock-photo search via the English bridge.
- **Dietary attributes** on **ingredients only**, with dishes **deriving** their dietary status
  from their ingredients. Enables a dietary catalog filter.
- **Catalog filter** (dietary + acquisition mode) over the existing dish accordion.
- **Polish swept in**: ingredient photo in the event menu, bilingual photo-search prefill,
  quantity editing when adding drinks.

Beverages keep only the **multilingual name**; their own dietary/attribute set and beverage filter
stay **parked** (separate axis, deferred).

---

## Scope decisions (LOCKED — do not re-derive)

**Multilingual:**
- Applies to **ingredients + dishes + drinks** (all three). Names in **ca/es/en**, always mark the
  **original** locale.
- **Filling on creation:** when an entity is created (AI via dish-assistant 020, or manually by the
  user), all three names are filled. The typed/source locale is the original; the other two are
  AI-translated and marked as derived.
- **Backfill (existing entities):** a one-off AI batch pass fills the missing translations for all
  existing ingredients/dishes/drinks, marking the original. This is the ONLY AI use in this spec.
- **Display:** each user sees the name **in their app locale** (fallback to the original if a
  locale is somehow missing). Never show the three names together.
- **Search:** stock-photo search sends **user locale + English** (English is the quality bridge for
  Pexels), not all three.

**Dietary:**
- Attributes live **only on ingredients**. Three attributes for v1: **vegan, vegetarian,
  gluten-free**.
- **Tri-state** per attribute: every ingredient is explicitly `yes` / `no` / `unknown`. Default on
  creation and for all existing ingredients = **`unknown`** (so "unknown" is the explicit
  "not-yet-classified" state, and the set of unknowns is the to-do list).
- **Rule vegan ⇒ vegetarian** must be structurally guaranteed (a vegan ingredient is always
  vegetarian; the impossible state "vegan but not vegetarian" cannot be represented).
- **Marking is MANUAL** (the user). The AI does **not** fill dietary in the backfill — existing
  ingredients stay `unknown` until the user marks them. The AI **may pre-fill a proposal only when
  it creates a brand-new ingredient** (dish-assistant path), always user-overridable.
- **Dishes derive** their dietary status from their ingredients, **conservatively** (any unknown
  ingredient makes the dish unknown for that axis; see Part B).
- **Purchased dishes** (no ingredients) cannot derive → they may be **marked manually** (same
  tri-state, default `unknown`).

**Filter (v1):** **dietary** (vegan / vegetarian / gluten-free) **+ acquisition mode** (cooked /
bought). Other filter dimensions (per supplier, per dish category) are out of scope this pass.

**Polish swept in:** D1 ingredient photo in event menu · D2 bilingual photo-search prefill · D3
quantity when adding drinks.

**No progress aid** for finding unmarked ingredients (the catalog is small enough).

---

## Part A — Multilingual names

### A.1 Model — storage mechanism is the one plan-mode decision

The **behaviour** is fixed (below); the **storage mechanism** must be confirmed against the real
data model in plan mode:

- **Option (i) — reuse the existing `translations` table** if it cleanly supports
  ingredient/dish/drink name rows (entity_type + entity_id + locale + text). Preferred if it fits
  without contortion.
- **Option (ii) — dedicated per-entity storage** (e.g. a `name_i18n` JSONB `{ca,es,en}` column, or
  three nullable name columns) if reusing `translations` would be forced.

Claude Code decides (i) vs (ii) in plan mode by inspecting the real schema, following the data model
and best practice. Either way, each entity also stores **`name_original_locale`** (`ca`|`es`|`en`)
marking the source locale, and per-locale **`name_source`** (`original` | `ai`) is desirable for
traceability/trust (the original is the reference; AI translations may err). Confirm the cheapest
faithful representation.

Behaviour that must hold regardless of mechanism:
- Every ingredient/dish/drink has a name in **all three** locales (none left incomplete).
- Exactly one locale is the **original**; the other two are derived (AI).
- `selectColumns` / row mappers expose the three names + original marker.

### A.2 Filling on creation

- **AI path (dish-assistant, Spec 020):** when the assistant creates a dish and its ingredients, it
  now also produces the **three names** for the dish and for each new ingredient, marking the
  source locale as original. Extend the dish-assistant Edge Function prompt + parse to return
  `{ca,es,en}` per created entity.
- **Manual path:** when the user types a name (their locale) and saves a new ingredient / dish /
  drink, fill the other two locales via a **lightweight AI name-translation helper** (reuses the
  AI Edge-Function infra), mark the typed locale as original. This keeps "no entity incomplete".
  - This helper translates a single short name; it is **not** a user-facing premium feature. Decide
    in plan mode whether it draws on an existing quota or runs as a cheap un-metered helper —
    recommendation: **un-metered** (name translation is tiny), but it MUST go through the server
    Edge Function (no client-side AI key), per conventions.
  - Degrade gracefully: if the translation helper fails/offline, save with the typed locale as
    original and the other locales empty/pending (a later backfill can fill them) — never block the
    save.

### A.3 Backfill (existing entities) — one-off AI batch

A one-off maintenance operation (Edge Function or admin-run script, **not** user-facing, run by
Rafael) iterates existing **ingredients + dishes + drinks**, and for each entity whose translations
are missing, fills the two non-original locales via AI and marks the original.

- Reuses the AI infra (Claude Sonnet 4.6 via Edge Function). Idempotent: only fills missing
  locales; never overwrites an existing original or a human-edited name.
- Original-locale inference for legacy rows: assume the existing single name is in the **group's /
  app default locale** (confirm: Entertain's existing rows are effectively Catalan) and mark `ca`
  (or the detected locale) as original; the helper fills es/en. If unsure per row, mark the assumed
  locale as original and proceed — names are user-editable afterwards.
- **No dietary in backfill.** This pass touches names only.

### A.4 Display & search resolution

- **Display:** a single resolver `localizedEntityName(entity, appLocale)` → name in `appLocale`,
  falling back to the original locale if absent. Used everywhere a catalog name renders
  (catalog lists, event menu rows, pickers).
- **Photo search:** the Pexels search term becomes **user-locale name + English name** (see D2).
  This is where the English bridge pays off ("baked cod" instead of "bacallà a la llauna").

---

## Part B — Dietary attributes (ingredients → derived dishes)

### B.1 Model (ingredients)

Two independent axes, both defaulting to the explicit unknown:

- **`diet`** — ordered enum `diet_level { unknown, none, vegetarian, vegan }`, default `unknown`.
  - `unknown` = not classified yet.
  - `none` = explicitly **not** vegetarian (contains meat/fish).
  - `vegetarian` = vegetarian but not vegan (e.g. dairy/egg).
  - `vegan` = vegan.
  - Because vegan/vegetarian are **levels on one ordered axis**, `vegan ⇒ vegetarian` is
    structurally guaranteed and "vegan but not vegetarian" is unrepresentable. (Do NOT model vegan
    and vegetarian as two separate booleans — that allows the impossible state.)
- **`gluten_free`** — tri-state enum `tri_state { unknown, yes, no }`, default `unknown`,
  independent of `diet`.

### B.2 Marking (manual)

- Ingredient editor gains a dietary section: a control for `diet` (Unknown / Not vegetarian /
  Vegetarian / Vegan) and a tri-state for `gluten_free` (Unknown / Gluten-free / Contains gluten).
- All existing ingredients are `unknown` on both axes after migration; the user marks them over
  time. No bulk tool, no progress aid (catalog is small).
- AI may **propose** values only when it creates a new ingredient (dish-assistant path); always
  overridable, and clearly a proposal (never silently authoritative).

### B.3 Derivation (dishes)

A dish's dietary status is **computed**, not stored, when it **has ingredients**; conservative with
unknowns. Precedence per axis:

- **diet:**
  1. if **any** ingredient `diet = none` → dish `none` (certain: a non-veg ingredient settles it,
     even amid unknowns).
  2. else if **any** ingredient `diet = unknown` → dish `unknown`.
  3. else if **all** ingredients `vegan` → dish `vegan`.
  4. else → dish `vegetarian`.
- **gluten_free:**
  1. if **any** ingredient `gluten_free = no` → dish `no`.
  2. else if **any** `unknown` → dish `unknown`.
  3. else (all `yes`) → dish `yes`.

Expose this as a pure, tested helper `deriveDishDiet(List<IngredientDiet>)` /
`deriveDishGlutenFree(...)`. The dish never stores a derived value (always computed on read) to
avoid staleness when ingredients change.

### B.4 Purchased dishes (no ingredients)

A dish with **no** ingredients cannot derive → it carries **manual** dietary fields (`diet`,
`gluten_free`, same enums, default `unknown`), editable in the dish editor **only when the dish has
no ingredients**. Resolution rule for a dish's effective dietary status:
- has ingredients → **derived** (B.3), manual fields ignored.
- no ingredients → **manual** fields (default `unknown`).

---

## Part C — Catalog filter

Over the existing dish catalog accordion, add a compact filter bar:

- **Dietary chips:** Vegan · Vegetarian · Gluten-free (multi-select; AND semantics across chips).
  - "Vegan" matches dishes whose effective `diet = vegan`.
  - "Vegetarian" matches `vegetarian` **or** `vegan` (since vegan ⇒ vegetarian).
  - "Gluten-free" matches `gluten_free = yes`.
  - **Unknown never matches a positive filter** (conservative: we only show what we can vouch for).
- **Acquisition mode:** Cooked / Bought (single-select or two chips). Confirm in plan mode how the
  model distinguishes cooked vs bought (has ingredients vs none, or an explicit field) and filter
  accordingly.
- Filters narrow what the existing accordion shows; empty result shows a neutral "no dishes match"
  state. Extensible later to ingredient/drink catalogs, but v1 is the **dish** catalog.

Pure, tested helpers: `dishMatchesDietary(dish, selectedChips)`, `dishMatchesAcquisition(dish,
mode)`.

---

## Part D — Polish (swept in)

### D1 — Ingredient photo in the event menu

Ingredient rows in the event menu (`event_dish_detail_screen`, `_LineRow`) don't show the
ingredient photo, while the catalog and dish rows do. The render simply doesn't exist on the
ingredient row.

- **Fix (option A from backlog):** replicate the dish pattern in the same menu — watch
  `entityCoverPathsProvider(MediaEntityType.ingredient)` and pass
  `coverPaths[line.ingredientId]` to a `RowPhotoThumb(bucket: 'ingredient-photos')` inside
  `_LineRow`, conditional. `line.ingredientId` already comes in the query. No model/DB change;
  degrade cleanly when `ingredientId` is null (like dishes with null `sourceDishId`).

### D2 — Bilingual photo-search prefill

When opening the Pexels search from a dish/ingredient/drink, prefill the search field with the
entity name in **local locale + English** (now that the English name exists from Part A). This is
the real-value version of the simple prefill shipped in 021 (B6).

- Compose the prefill as `"<name in user locale> <name in en>"` (dedupe if identical). This both
  prefills and improves results.
- Connects to the dish-assistant photo-query-in-English improvement (021 B2/B3): the English bridge
  is now a stored name, not a per-call guess.

### D3 — Quantity when adding drinks (parity with dishes)

Adding a drink to an event menu — especially via "create new drink" — inserts straight into the
menu at quantity 1, with no per-event edit step, unlike dishes (which let you adjust the per-event
copy). Bring drinks to parity.

- Confirm in plan mode whether an `event_drinks` per-event copy table exists analogous to
  `event_dishes`; if not, decide the model before the UI.
- Two facets: (a) general — expose editing the per-event drink copy (quantity) when adding;
  (b) "create new" path — route through the same edit step instead of dropping straight in.

---

## Data — migration

`supabase/migrations/<timestamp>_rich_catalog.sql` — **proposed**; confirm column/table names
against the real schema in plan mode before `db push`. Illustrative shape:

```sql
-- Dietary enums
do $$ begin
  create type diet_level as enum ('unknown','none','vegetarian','vegan');
exception when duplicate_object then null; end $$;
do $$ begin
  create type tri_state as enum ('unknown','yes','no');
exception when duplicate_object then null; end $$;

-- Ingredients: dietary axes (default unknown for all existing rows)
alter table public.ingredients
  add column if not exists diet diet_level not null default 'unknown',
  add column if not exists gluten_free tri_state not null default 'unknown';

-- Purchased-dish manual dietary (used only when a dish has no ingredients)
alter table public.dishes
  add column if not exists diet diet_level not null default 'unknown',
  add column if not exists gluten_free tri_state not null default 'unknown';

-- Multilingual names: mechanism per plan-mode decision (translations table reuse vs dedicated).
-- If dedicated columns route is chosen, e.g.:
--   alter table public.ingredients add column if not exists name_i18n jsonb;        -- {ca,es,en}
--   alter table public.ingredients add column if not exists name_original_locale text;
--   (same for dishes, drinks)
-- If translations-table route is chosen, no column changes here beyond name_original_locale.
```

**service_role grant audit (explicit):** any table the AI Edge Functions (dish-assistant, the new
name-translation helper, the backfill) **read or write** with `service_role` needs an explicit
grant in this migration — Postgres checks table privileges before RLS, so tables granted only to
`anon`/`authenticated` fail silently for `service_role`. Enumerate every table the AI paths touch
(ingredients, dishes, drinks, and the translations table if used) and grant `service_role`
accordingly. Confirm against the real Edge-Function access in plan mode.

---

## Client — data layer

- **`diet.dart` / dietary enums** mirroring `dish_category.dart`: `DietLevel { unknown, none,
  vegetarian, vegan }`, `TriState { unknown, yes, no }`, with wire parse/encode + labels + icons +
  render order.
- **Pure dietary helpers (tested):** `deriveDishDiet(...)`, `deriveDishGlutenFree(...)`,
  `effectiveDishDiet(dish)` (derived if has ingredients, else manual), `dishMatchesDietary(...)`,
  `dishMatchesAcquisition(...)`.
- **Multilingual helpers (tested):** `localizedEntityName(entity, appLocale)` (with original-locale
  fallback), `photoSearchTerm(entity, appLocale)` (local + English, deduped).
- **Model + repository:** extend ingredient/dish/drink models with the three names + original
  marker and (ingredients/dishes) the dietary fields; extend `selectColumns`/`fromRow`; add
  repository methods to read/write names and dietary attributes. Providers invalidated on mutation
  as per existing patterns.
- **AI integration:** extend dish-assistant Edge Function (names + optional dietary proposal on
  create); add the name-translation helper Edge Function (manual-create path); the one-off backfill
  operation. All server-side; no client AI key.

## Client — UI

- **Ingredient editor:** dietary section (`diet` control + `gluten_free` tri-state); names are
  shown/edited in the app locale (the original marker is internal — do not surface a 3-language
  editor in v1 unless trivial; editing the displayed name updates that locale and keeps the
  original marker).
- **Dish editor:** when the dish has **no** ingredients, show manual dietary controls; when it has
  ingredients, show the **derived** status read-only (e.g. a small "Vegan (derived)" badge), so the
  user understands it comes from ingredients.
- **Catalog (dish accordion):** add the filter bar (dietary chips + acquisition); show effective
  dietary badges on dish rows where useful (concise, not noisy).
- **Event menu (`_LineRow`):** D1 ingredient thumbnail.
- **Photo search screen:** D2 bilingual prefill.
- **Drink add flow:** D3 per-event quantity edit / route through edit step.

## i18n (ca/es/en) — `lib/l10n/app_{ca,es,en}.arb`

Dietary labels (vegan/vegetarian/gluten-free, and the tri-state/level option labels), "derived"
badge text, filter bar labels (dietary chips, cooked/bought), any new editor labels. Run
`flutter gen-l10n`; add `@` placeholder metadata for parametrized keys.

## Tests (faked, mirror existing catalog/menu tests)

- enum wire round-trips (`DietLevel`, `TriState`).
- `deriveDishDiet` / `deriveDishGlutenFree`: the four/three precedence branches, including the
  conservative-unknown and dominant-`none`/`no` cases.
- `effectiveDishDiet`: ingredients → derived; no ingredients → manual.
- `dishMatchesDietary`: vegan filter matches vegan only; vegetarian matches vegetarian+vegan;
  gluten-free matches yes only; unknown matches no positive filter.
- `dishMatchesAcquisition`: cooked vs bought.
- `localizedEntityName`: returns the app-locale name; falls back to original when missing.
- `photoSearchTerm`: local + English, deduped when identical.
- widget: catalog filter narrows the list; ingredient dietary edit persists; menu ingredient row
  shows a thumbnail when a cover exists (faked provider).

## Verification

1. `flutter gen-l10n` + `flutter analyze` + `flutter test` green.
2. Show the migration; on approval `supabase db push`.
3. Run the **one-off multilingual backfill** against the real project; spot-check that existing
   ingredients/dishes/drinks gained es/en names with the original marked, and that the backfill is
   idempotent (a second run changes nothing).
4. On the Pixel 8 Pro:
   - Names display in the app locale; switching app language shows the other locale.
   - Mark a few ingredients' dietary attributes; a dish made of them shows the correct **derived**
     status; introducing one `unknown` ingredient flips the dish to `unknown`; one `none` ingredient
     flips it to non-vegetarian.
   - A purchased dish (no ingredients) takes a **manual** dietary value.
   - Catalog **dietary filter** + **cooked/bought** narrow correctly; unknown dishes don't appear
     under a positive dietary filter.
   - D1: ingredient rows in the event menu show photos. D2: photo search prefills local+English.
     D3: adding a drink lets you set quantity (parity with dishes).

## Out of scope (this pass)

- **Beverage** dietary/attribute set and beverage filter (parked).
- Filter dimensions beyond dietary + acquisition (per supplier, per dish category).
- Dietary attributes on dishes as first-class manual data when they HAVE ingredients (always
  derived in that case).
- Guest dietary restrictions ↔ menu validation (future; ties to 023 guests + wizard 022).
- Any AI use for dietary backfill (dietary is manual; only names are AI-backfilled).
