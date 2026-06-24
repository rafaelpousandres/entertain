# Specification 024 — Minor corrections + beverage consolidation

> Build assignment for Claude Code. Read CLAUDE.md, "entertain - Data model.md",
> and the backlog. This is a **polish pass**: a batch of small, accumulated
> corrections done together to avoid spending separate Internal Testing cycles on
> each (same approach as Spec 021). It also includes a small **data-model
> consolidation** (deprecating the `dish_category` value `drink`).
>
> No schema-destructive changes. Any migration/Edge-Function change shown before
> push/deploy. One PR. Branch: `feat/spec-024-minor-corrections`.

---

## Part A — Usability polish

### A1. Events screen: accordion + "Passat" → "Passats"
The **Events** screen (home) currently lets both groups — **En preparació** and
**Passat** — be open at the same time. Apply the existing **accordion pattern**
(all collapsed by default, **one open at a time**) used elsewhere (Menu /
catalogs, Spec 011 §2.8), so opening one group collapses the other.

- Same component/behaviour as the Menu and catalog accordions — don't reinvent;
  reuse.
- Fix the group label literal **"Passat" → "Passats"** (plural). i18n ca/es/en:
  ensure the past-events group header reads correctly in the three languages
  (ca: "Passats", es: "Pasados", en: "Past").

### A2. Delete suppliers from the app
The suppliers catalog offers **no delete affordance** (no overflow, no swipe),
unlike dishes/ingredients. Add a way to delete a supplier (at minimum, to remove
test data), consistent with how dishes/ingredients are deleted.

- **Investigate the model first (plan mode):** confirm whether `suppliers` is a
  catalog table with **soft-delete** (`deleted_at`) — if so, mirror the
  dishes/ingredients delete path exactly (set `deleted_at`, list filters
  `deleted_at IS NULL`). If `suppliers` has **no** `deleted_at`, surface that:
  deletion would be physical and must account for the `orders.supplier_id` FK
  (and its `ON DELETE` action). **Do not invent a physical-delete + FK-handling
  design silently** — if the model isn't a clean soft-delete mirror, **stop and
  report** before implementing; this may then be split out of this pass.
- UI: same affordance pattern as the dish/ingredient catalogs (overflow or swipe
  — match what those use).
- i18n ca/es/en for any new strings (delete action, confirm dialog).

---

## Part B — Beverage consolidation (deprecate `dish_category` = `drink`)

### Context (read before implementing)
Beverages have moved from being a **dish category** to being their **own entity**
(`drinks` / `event_drinks`). The enum `dish_category` still contains the value
**`drink`** (alongside `aperitif`, `starter`, `main`, `dessert`, `other`). That
value is now a **vestige**: nothing new should be created with it, and the menu
should not present a plat-category "Begudes" section duplicating the real drinks
section.

**Decision: deprecate the value, do NOT remove it from the enum.** PostgreSQL has
no `ALTER TYPE … DROP VALUE`; removing it means recreating the type and converting
real data in `dishes` and `event_dishes` (including historical event snapshots) —
destructive, irreversible without backup, and it would **not** fix the visible
symptom (which lives in the UI, not the enum). Deprecation gives the desired
user-visible result (beverages only via `drinks`, no duplicate "Begudes" plat
section) at low cost and fully reversibly. The inert value stays in the DB as a
**documented** vestige (§B4).

### B1. Remove `drink` from the dish-category options (create/edit dish UI)
Wherever the dish create/edit UI offers the list of categories, **exclude
`drink`** from the offered options. The active set becomes: `aperitif`,
`starter`, `main`, `dessert`, `other`.
- If the option list is currently **derived automatically** from the enum,
  replace that with an **explicit list of active values** — this explicit list
  becomes the single source of truth for "what the user can pick". Keep it in one
  place so future additions/removals are one edit.

### B2. Remove `drink` from the AI paths
- **Dish assistant (020):** the `dish-assistant` Edge Function prompt must **not**
  propose `drink` as a category. Update the list of valid categories given to
  Claude in the prompt to the active set (no `drink`). This is a prompt change
  (the valid-category list), **not** a post-hoc validation/guard.
- **Menu wizard (022, future):** note in the spec/prompt that when 022 is built it
  must use the same active-category list (no `drink`). (Nothing to build here now;
  this is a forward note so 022 doesn't reintroduce it.)

### B3. Don't render a `drink` plat-category section in the event menu
In the event **Menu** tab, where dishes are grouped by `category`, the grouping
must **not** produce a "Begudes" section from plat-category `drink` (beverages are
shown via the `drinks` entity's own section).
- **Inspect the current menu grouping first (plan mode)** and implement the
  omission cleanly within how it's already built — don't restructure the grouping.
- **Legacy data:** live data should no longer contain plat-category `drink`
  (the one case, "Begudes amb cava", was removed via the app). If the inspection
  finds any **live** `event_dishes` still carrying `category = 'drink'`, **stop
  and report** rather than silently hiding them (hiding a plat the user can still
  see would be data-loss-by-omission). For the expected case (none live), simply
  ensure the `drink` group is not rendered.

### B4. Document the deprecation
So the vestige is explained, not buried:
- **Enum comment** in a small migration:
  `comment on type public.dish_category is 'Values: aperitif, starter, main, dessert, other. "drink" is DEPRECATED (spec 024): beverages live in the drinks entity since the drinks feature; value kept inert for historical event_dishes compatibility, not offered in UI/AI/menu.';`
- One line in `docs/backlog.md` (or the relevant ADR) recording the decision:
  beverages consolidated to the `drinks` entity; `dish_category.drink` deprecated,
  not dropped (Postgres enum constraint), removed from active code paths in 024.

---

## Out of scope
- Dropping `drink` from the `dish_category` enum (deliberately not done — see §B
  context).
- Any change to the `drinks` / `event_drinks` entity itself, or the
  beverage add/edit flows (separate; some captured in backlog).
- A2 physical-delete + `orders` FK design, **if** suppliers turns out not to be a
  clean soft-delete mirror (then split out and decide separately).
- Anything in Specs 022 / 023 (queued after this pass).

## i18n, tests, verification
- i18n ca/es/en for all new/changed strings: events group headers (incl.
  "Passats"), supplier delete action + confirm, any labels. `flutter gen-l10n`.
- Tests:
  - A1: events accordion — opening one group collapses the other; "Passats"
    label resolves in the three locales.
  - A2: supplier delete follows the confirmed model (soft-delete mirror →
    `deleted_at` set + filtered from list); guard the `orders` case per the
    investigation outcome.
  - B1/B2: the active-category list excludes `drink` (UI options + the prompt's
    valid-category list); a generated/created dish never lands `category = drink`.
  - B3: the menu grouping renders no `drink` plat section; if any live legacy
    `event_dishes.drink` exists, the build stopped per §B3 (don't paper over).
  - Keep the existing suite green.
- `flutter analyze` + `flutter test` green before PR.

## Operator / deploy
- `supabase db push` only if used for the §B4 enum comment (shown before push).
- Redeploy `dish-assistant` after approval if the prompt changed (B2).
- On device (Internal Testing build): Events groups behave as an accordion and
  read "Passats"; a test supplier can be deleted; creating/AI-generating a dish
  offers no "Begudes" category; the Maduixer menu shows no duplicate "Begudes"
  plat section.

## Notes
- Polish-pass rationale (per Spec 021): batch small fixes into one Internal
  Testing cycle.
- §B is a data-model consolidation expressed in **code**, not a destructive
  schema change — the enum keeps all its values; only the active code paths and
  presentation change, plus a documenting comment.
