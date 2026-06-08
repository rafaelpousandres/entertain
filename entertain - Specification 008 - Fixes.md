# Specification 008 — Fixes (post-real-use)

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read `CLAUDE.md`, `entertain - Data model.md`, `entertain - Design system.md`,
> the original `entertain - Specification 008 - Real-use feedback round.md`,
> and all previous specifications (001 through 007 plus their fixes rounds)
> before starting. This document follows up on Spec 008 after a second
> round of real-world usage. Four items emerged, all of them either small
> bugs uncovered by genuine use or follow-up corrections to items that
> were technically delivered in Spec 008 but didn't quite hit the mark
> in practice.

---

## 1. Goal

The MVP plus Spec 008 are now in real use. A second wave of feedback
surfaced four items:

1. **§2.1 — Stale quantity on the dish-in-event menu card.** When the
   user changes the servings count on an event_dish and ingredient
   quantities scale correctly, the dish's "menu card" (the row that
   summarises the dish back in the event's menu list) keeps showing an
   old quantity until the app is closed and reopened. A reactivity
   bug.
2. **§2.2 — Supplier category at first step of the add-ingredient
   modal.** In Spec 008 §2.5 the supplier category selector was added
   to the add-ingredient flow, but it lives on a second step alongside
   the quantity. The user wants it on the first step alongside name
   and unit, where the other structural attributes live.
3. **§2.3 — Desa button hidden by keyboard, system-wide.** Spec 008
   §2.11 was marked verified but the real bug persisted in many
   screens. This pass adopts a single, consistent pattern across the
   app: the primary save action moves into the AppBar so it is always
   visible regardless of keyboard state.
4. **§2.4 — New units in the seed catalog: paquet, pot, llauna.**
   Three abstract countable units the user needs for real ingredients
   (a packet of x, a jar of y, a can of z). No conversion to other
   units; ambiguity in size is accepted by the project owner.

---

## 2. Scope — what to fix

### 2.1 Stale quantity on dish-in-event menu card

**Observed**: in an event's menu tab, each dish appears as a card
that summarises some of its content (name, servings, perhaps the
quantity of the most relevant ingredient or a count of ingredients).
When the user opens an event_dish detail screen, edits the servings
count, and the ingredient quantities scale correctly inside that
screen, the change is correctly persisted to the database. However,
when the user goes back to the menu tab, the card for that dish
still shows the **old quantity**. The card only refreshes when the
app is fully closed and reopened.

**Root cause** (hypothesis, to verify): the Riverpod provider that
backs the menu list does not re-emit when an event_dish or its lines
change. Either the dependency graph misses the relevant edge, or the
provider caches the value with stale invalidation.

**Fix**: identify the provider serving the menu tab and ensure it
re-emits whenever the underlying event_dish or its lines are
modified. The pattern in the rest of the app (per the Spec 007
shopping panel real-time refresh, for example) is the model to
follow.

Concretely:

- Audit `events_providers.dart` (and any related providers) for the
  source of the menu-tab card data.
- Verify that mutations to `event_dishes` (especially the `servings`
  column) and to `event_dish_ingredients` invalidate the menu-tab
  provider and trigger a re-fetch / re-emission.
- If a manual `ref.invalidate(...)` or equivalent is missing at the
  edit-save callback, add it.
- Add a widget/integration test that reproduces the bug: open an
  event, change the servings on a dish, return to the menu tab, and
  verify the card reflects the new quantity.

No model changes.

### 2.2 Supplier category on the first step of the add-ingredient modal

**Observed**: Spec 008 §2.5 added a "Categoria de proveïdor" selector
to the modal for adding/editing ingredient lines. The selector
appears, but on a **second step** of the modal, alongside the
quantity. The user expects it on the **first step**, together with
the name and unit, because conceptually the supplier category is a
structural attribute of the ingredient (what kind of thing it is and
where it's bought), parallel to name and unit. Quantity is a
contextual attribute (how much of it for this dish), and belongs to
a separate step.

**Fix**: reorganise the add-ingredient flow so that the first step
collects:

- **Name** (text input).
- **Unit** (selector).
- **Supplier category** (selector, with "Sense categoria" as the
  default).

The second step then collects:

- **Quantity** (numeric input).
- **Prep note** (optional text input).

The selectors and inputs should be ordered top to bottom on each step
in the order listed above.

This applies to:

- Adding an ingredient line to a catalog dish (from the dish editor
  screen).
- Adding an ad-hoc ingredient line to a per-event dish (from the
  event-dish detail screen).
- Editing an existing ingredient line: the same two-step structure
  applies, with the supplier category appearing on the first step.

No model changes — just UI reorganisation of the modal flow.

### 2.3 Desa button hidden by keyboard — system-wide fix

**Observed**: in many edit screens, the Desa button at the bottom of
the screen is hidden by the on-screen keyboard when the user is
typing. Worse, the back navigation (system back gesture or arrow)
can dismiss the screen without saving, losing the user's work
silently.

Specific screens confirmed by the project owner so far:

- The dish editor (catalog).
- The add-ingredient flow from the dish editor.
- The add/edit-ingredient flow from the Ingredients tab.
- "De fet passa a quasi bé tot arreu" (essentially everywhere).

The Spec 008 §2.11 fix was marked verified but the underlying
pattern was not applied consistently.

**Fix**: adopt a **single, consistent pattern** across all edit
screens in the app:

> **The primary save action lives in the AppBar as a trailing icon
> action (a check mark icon, "Desa" semantics).**

This pattern guarantees the button is **always visible** regardless
of keyboard state. It's the pattern used by mature Android apps like
Gmail (compose), Calendar (event editor), and Keep (note editor).

Concretely:

- Audit every screen that has a Desa button (or equivalent primary
  save action) and move that button **into the AppBar** as a trailing
  `IconButton` with the check icon (`Icons.check`).
- Remove the bottom-of-screen Desa button. Either remove the
  bottom bar altogether (if the AppBar action is the only primary
  action), or keep secondary actions at the bottom (e.g. a
  destructive "Esborra" action, if any).
- Use a consistent visual treatment for the AppBar save icon across
  all screens.
- The same applies to modal screens with save actions (e.g. the
  add-ingredient modal): the save action goes into the modal's
  header bar instead of the bottom.

Screens to audit and update (this list is the floor, not the
ceiling — apply the pattern wherever a Desa button currently lives):

- `dish_editor_screen.dart`
- `ingredient_line_editor_screen.dart`
- `event_form_screen.dart`
- `event_dish_detail_screen.dart`
- `event_dish_line_editor_screen.dart`
- `supplier_category_detail_screen.dart`
- `settings_screen.dart` (the Missatges sub-screen)
- The add-ingredient modal (whatever screen file backs it, possibly
  shared between the dish editor and the event-dish detail).
- Any other screen with a primary save action.

For each updated screen:
- Remove the FAB-style or bottom-button Desa.
- Add an `IconButton(icon: Icon(Icons.check), onPressed: _save)` to
  the AppBar's `actions` list.
- Verify accessibility: the icon should have a `tooltip: 'Desa'`
  (with proper translation: ca/es/en).
- Verify keyboard behaviour: when the keyboard is open, tapping the
  AppBar action saves and dismisses the keyboard.
- Verify back navigation: the system back gesture and the leading
  back arrow should both prompt the user if there are unsaved
  changes ("Hi ha canvis sense desar. Vols sortir?" with a "Sortir
  sense desar" / "Cancel·la" choice). This second part is the
  guard against silently losing work.

Translations:
- "Desa" (ca, AppBar tooltip + unsaved-changes button label).
- "Guardar" (es).
- "Save" (en).
- "Hi ha canvis sense desar. Vols sortir?" / similar.
- "Sortir sense desar" / "Discard and exit" / "Descartar y salir".
- "Cancel·la" / "Cancel" / "Cancelar".

This is a **system-wide refactor**. It should be done once,
consistently, and tested screen by screen.

### 2.4 New units: paquet, pot, llauna

**Observed**: when entering real ingredients (e.g. "1 paquet de
galetes Maria", "2 pots de melmelada", "3 llaunes de pesols"), the
existing unit catalog doesn't have these countable abstract units.
The user has to either fall back to no unit (which loses the unit
semantics) or invent ad-hoc workarounds.

**Fix**: add three new units to the seed unit catalog:

- **paquet** (ca) / **paquete** (es) / **packet** (en) — singular;
  plural "paquets" (ca) / "paquetes" (es) / "packets" (en).
- **pot** (ca) / **bote** (es) / **jar** (en) — singular; plural
  "pots" (ca) / "botes" (es) / "jars" (en).
- **llauna** (ca) / **lata** (es) / **can** (en) — singular; plural
  "llaunes" (ca) / "latas" (es) / "cans" (en).

These are **abstract countable units** with no defined size or
conversion. The user explicitly accepts the ambiguity: a "paquet"
of one ingredient may be 100 g and of another may be 1 kg; the
context is recorded in the ingredient itself, not in the unit.

Behaviour:

- Each unit is added to the `units` table (or wherever the seed unit
  catalog lives) with the appropriate translations.
- They appear in the unit selector wherever the existing units
  appear (add-ingredient modal, line editor).
- They behave like the existing countable units (e.g. "eggs"): no
  conversion to other units, quantity displayed as integer (rounded
  up if scaling produces fractions, per Spec 008 §2.10 logic for
  countable units).
- Plural forms follow the standard project conventions for plural
  rendering (per Spec 006 §2.3 unit suppression and Spec 008 §2 in
  general): when quantity > 1 the plural is shown, when 1 the
  singular, when 0 still the singular form (no zeros are shown in
  practice).

Migration: `20260611010000_seed_units_paquet_pot_llauna.sql`
inserting the three new units with their translations.

---

## 3. Out of scope

Explicitly **not** part of this assignment:

- Defining a default size/weight for "paquet", "pot", "llauna" — the
  ambiguity is intentional.
- Unit conversion between abstract countable units and weight/volume
  units (e.g. "1 paquet = 250 g").
- Adding more abstract units beyond the three listed (e.g. "tros",
  "rajola"). If more are needed they will be added in future rounds
  as the real use surfaces them.
- A full redesign of the add-ingredient modal beyond the
  two-step reorder.
- Optimistic UI updates in the menu tab beyond a clean re-fetch on
  underlying data change.
- A general undo/redo system for edits across the app.

---

## 4. Acceptance criteria

The assignment is complete when the project owner can verify all of
the following on the Android device:

1. **§2.1 — Reactive menu card.** In an event's menu tab, after
   editing the servings count on a dish detail screen and returning
   to the menu tab, the dish card reflects the new quantity
   immediately (no app restart required).
2. **§2.2 — Two-step modal order.** The add-ingredient modal has
   two steps: the first contains name, unit, and supplier category;
   the second contains quantity and prep note. Editing an existing
   ingredient line shows the same two-step structure with the
   current values pre-filled on each step.
3. **§2.3 — AppBar save action.** In every edit screen with a
   primary save action, the action lives in the AppBar as a check
   icon and is always visible regardless of keyboard state.
4. **§2.3 — Unsaved changes guard.** When the user tries to leave
   an edit screen with unsaved changes (system back or leading
   arrow), a confirmation dialog appears with options to discard
   changes or cancel and stay.
5. **§2.4 — New units available.** The three new units (paquet,
   pot, llauna) appear in the unit selector wherever it is shown
   (catalog modal, event modal, line editor). Each is properly
   translated into ca/es/en and uses correct singular/plural forms.
6. **§2.4 — Countable behaviour.** When scaling an event_dish that
   uses one of the new units, the quantity rounds up to the next
   integer (as per the existing countable-unit rule from Spec 008
   §2.10).
7. All existing flows continue to work without regression.
8. All affected screens follow the design system and have no
   hardcoded user-facing strings.
9. The work is committed to a new branch
   `feat/spec-008-fixes-real-use` with a clean PR description
   listing the four items.

---

## 5. Notes for the implementer

- §2.1 likely requires understanding the Riverpod provider graph
  that backs the event detail screen. The fix may be a single
  `ref.invalidate(...)` call at the save callback in the
  event_dish_detail_screen or the line_editor_screen, but verify
  that the menu card actually depends on the same provider that's
  being invalidated. A widget test that reproduces the bug is the
  best safeguard.
- §2.2 is a UI rearrangement. No model changes. Just move the
  supplier category selector from step 2 to step 1 in the
  add-ingredient modal flow, and adjust step labels accordingly if
  the modal uses any.
- §2.3 is the most substantial of the four. The pattern is well
  documented in Material Design and used by Gmail / Calendar /
  Keep. The unsaved-changes guard is a common pattern using
  `WillPopScope` or `PopScope` in Flutter. Use a single shared
  widget for the AppBar save action and the unsaved-changes guard
  if it improves consistency, so that future screens automatically
  follow the pattern.
- §2.4 is a small seed migration plus making sure the selector and
  the plural-rendering logic pick the new units up.
- One migration: `20260611010000_seed_units_paquet_pot_llauna.sql`.
- Stop and ask the project owner if any ambiguity arises,
  particularly around the unsaved-changes guard semantics (per
  screen specifics).
- The PR description should reference each of the four items by its
  §2.x number, with a short summary and checkbox state.
