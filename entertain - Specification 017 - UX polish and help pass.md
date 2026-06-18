# Specification 017 — UX polish and help pass

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read CLAUDE.md and the help-texts companion document
> "entertain - Spec 017 help texts.md" (the verbatim copy for Part B).
> Two parts: **A — UX consistency polish** (behaviour) and **B — Help**
> (content + selective help icons). One branch, one PR; commit the spec with
> the code.

---

## Part A — UX consistency polish

### A.1 Contextual add button on the event Menu

The event Menu currently shows a fixed bottom "+ Afegeix plat" button **and** a
separate inline "+ Afegeix beguda" inside the drinks section — two different
ways to add, which is inconsistent.

Make the **bottom button contextual**, matching the grouped-catalog pattern
(where the bottom action follows the active tab): it reflects the **open
accordion section** — a dish category open → "+ Afegeix plat"; the Begudes
section open → "+ Afegeix beguda". The accordion opens **one section at a
time**, so there is no ambiguity. With everything collapsed → default to
"+ Afegeix plat". Remove the separate inline drinks add button.

### A.2 Splash logo — native plain, overlay carries the logo

The Android-12 native splash clips the logo (the circle crop cuts the outer
chairs), and there is a visible size jump from the large native logo to the
in-app overlay.

Fix by **removing the logo from the native splash**: the native splash is a
**plain background** in the exact cream `#FBF5EA`, no logo. The logo appears
only via the **in-app overlay** (which already renders well, ~1s). Ensure the
native background and the overlay background are the **same `#FBF5EA`** so the
transition shows only the logo appearing, with no colour jump. Regenerate the
native splash config accordingly.

### A.3 Back arrow = exit without saving, app-wide + confirm if dirty

Today the back arrow's meaning is inconsistent: on some edit screens it exits
without saving (with a confirm), on others (e.g. the event-menu item cards) it
saves implicitly. Unify to one rule across the app:

- **Back arrow = exit without saving.** If there are **unsaved changes**, show
  a confirmation ("Discard changes?") before leaving.
- **Saving is an explicit action** — a Save / ✓ affordance on edit screens.
  Where edits were previously applied on-the-fly (e.g. the menu item-card
  steppers), move to explicit save so back-without-saving is meaningful and
  consistent.

Audit the edit/detail screens (event form, dish/drink/ingredient editors, line
editors, event-dish detail, the menu item-card edit) and apply the single
pattern. Flag any screen where on-the-fly save is deeply assumed and explicit
save would be a large change, before doing it.

### A.4 Unify delete / remove wording and behaviour

Delete actions are inconsistent ("Esborra" vs "Treu del menú" vs others) for
what are actually two distinct concepts. Standardise:

- **Remove from a context** (the item stays in its catalog) →
  "Treu de [context]" / "Remove from [context]" (e.g. remove a dish from a
  menu). No catalog deletion.
- **Delete from the catalog** (gone for good) → "Esborra" / "Delete", always
  with a confirmation (destructive).

Audit every delete/remove affordance and apply the right wording + behaviour
consistently. ca/es/en.

---

## Part B — Help

All copy is in the companion doc "entertain - Spec 017 help texts.md";
integrate **verbatim** into the ARB files and the manual.

### B.1 Correct outdated help (Spec 016 model change)

- **`helpDrinksBody`** currently describes the old drinks model (servings +
  optional purchase unit) — **factually wrong** after Spec 016. Replace with
  the corrected copy (§1.1 of the help-texts doc): drinks are units of a
  denomination, no servings, no scaling.
- **`helpMenuTabBody`** — append the prepared-dishes/drinks sentence (§1.2),
  keeping the existing format-scaling + 3–5 servings guidance.

### B.2 New selective help icons (only where concepts aren't obvious)

Add a `HelpIconButton` to **three** screens (not all editors — keep it
selective):
- **Dish editor** (`dish_editor_screen.dart`) → `helpDishEditorBody` (§2.1):
  explains the cooked/bought toggle.
- **Drink editor** (`drink_editor_screen.dart`) → `helpDrinkEditorBody` (§2.2):
  denomination + no scaling.
- **Supplier category detail** (`supplier_category_detail_screen.dart`) →
  `helpSuppliersBody` (§2.3): multiple suppliers + default.

Other editors/forms stay without a help icon (self-explanatory).

### B.3 Update the Getting Started card

Update `gettingStartedStep1..5` (Settings card) to the revised five steps
(§3): grouped Catalog, prepared dishes/drinks, multiple suppliers.

### B.4 Update the manual + regenerate the PDF

- Update `docs/manual/index.md` with the revised body (§4): grouped Catalog,
  prepared dishes, drinks, multiple suppliers.
- Regenerate the getting-started PDF to match (same content), replacing the
  current one.

---

## Acceptance criteria

1. Menu bottom add button is contextual (open section → plat/beguda; collapsed
   → plat); the separate inline drinks add button is gone.
2. Native splash is a plain `#FBF5EA` background (no logo, no clip); the overlay
   logo appears with no colour jump.
3. Back arrow exits without saving app-wide, confirming if there are unsaved
   changes; saving is an explicit action on edit screens.
4. Delete/remove wording and behaviour unified ("Treu de…" vs "Esborra"),
   ca/es/en.
5. `helpDrinksBody` and `helpMenuTabBody` corrected; three new help icons added
   (dish editor, drink editor, supplier detail) with the new bodies.
6. Getting Started card and manual + PDF updated.
7. flutter analyze clean; flutter test passes; tests for any dirty-state /
   confirm-on-back logic added where feasible.

## Notes

- No migration (this Spec is UI + content only).
- Part A.3 is the largest item (touches several edit screens + introduces an
  explicit-save/dirty pattern). Present the plan for A.3 before implementing,
  and flag screens where the change is non-trivial.
- All new/changed strings ca/es/en; run `flutter gen-l10n`.

Branch: `feat/spec-017-ux-polish-and-help`.
