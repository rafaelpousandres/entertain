# Specification 018 — Add-to-menu flow improvements

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read CLAUDE.md before starting. This Spec improves the flow of adding dishes
> and drinks to an event's menu — the app's central action. No migration
> (UI + navigation only). One branch, one PR; commit the spec with the code.

---

## 1. Goal

Building a menu is the core task, and the add-to-menu flow has three friction
points found on-device:
- The **add-dish list** accordion behaves differently from every other
  accordion in the app (opens expanded, allows multiple sections open).
- There is **no way to create a new dish or drink from within the add flow** —
  the user must leave the event, go to the catalog, create the item, and come
  back.

This Spec aligns the accordion and adds an inline "create new" path that creates
the item and adds it to the event in one step.

---

## 2. Accordion consistency on the add-dish screen (§A.1 fix)

`add_dish_to_menu_screen.dart` currently opens with categories expanded and
allows several categories open at once. Align it with the established accordion
pattern used by the catalog and the event Menu:
- **Collapsed on entry** (all categories closed).
- **One section open at a time** (opening one closes the others).

Reuse the same accordion ordering/single-open helper the catalog screens use so
the behaviour is identical. (The Begudes add screen, if it groups by category,
should follow the same pattern for consistency.)

## 3. Create-new from within the add flow (§2/§3 friction)

Both the add-dish and add-drink screens get an inline **create-new** entry:
- **Add-dish screen** (`add_dish_to_menu_screen.dart`): a "+ Crea un plat nou"
  affordance (e.g. a header action or a row at the top/bottom of the list) →
  opens the **dish editor** (`dish_editor_screen.dart`) in create mode.
- **Add-drink screen** (`add_drink_to_menu_screen.dart`): a "+ Crea una beguda
  nova" affordance → opens the **drink editor** (`drink_editor_screen.dart`) in
  create mode.

### 3.1 Behaviour on save (the key flow)
When the user creates the item from this flow and saves it:
- The item is **created in the catalog** (as a normal create), and
- it is **immediately added to the current event** with **default values**
  (dish servings = the event's format default, as when adding an existing dish;
  drink quantity = 1), and
- the user is **returned to the event Menu** with the new item already in the
  menu.

The user can then adjust servings / quantity from the Menu as usual (no forced
adjust step — consistent with adding an existing item).

### 3.2 Editor presets carry over
The editors keep their existing preset behaviour when opened from this flow:
- A **bought dish** created here preselects the system "Plats preparats"
  supplier category (editable); a cooked dish is the editor default.
- A **drink** preselects the system "Begudes" supplier category (editable) and
  its denomination picker.

### 3.3 Cancel
If the user backs out of the editor without saving (respecting the Spec 017
dirty-state / confirm pattern), nothing is created and they return to the add
list unchanged.

---

## 4. Acceptance criteria

1. The add-dish screen opens collapsed, with one category open at a time —
   identical to the catalog / Menu accordion.
2. The add-dish screen has a "Crea un plat nou" entry that opens the dish editor
   in create mode; on save, the dish is created and added to the event with
   default servings, returning to the Menu with it present.
3. The add-drink screen has a "Crea una beguda nova" entry that opens the drink
   editor in create mode; on save, the drink is created and added to the event
   with quantity 1, returning to the Menu with it present.
4. Editor presets (bought dish → "Plats preparats"; drink → "Begudes" +
   denomination) apply when created from this flow.
5. Backing out of the editor without saving creates nothing and returns to the
   add list (Spec 017 confirm-if-dirty respected).
6. flutter analyze clean; flutter test passes; a test pins the create-and-add
   wiring (new item ends up in the event with defaults).

## 5. Notes

- No migration (UI + navigation only).
- All new strings ca/es/en; run `flutter gen-l10n`.
- Reuse existing pieces: the catalog accordion helper, the editors, and the
  existing add-to-event repository calls (`addDishToEvent` / the drink
  equivalent) for the "add with defaults" step.

Branch: `feat/spec-018-add-to-menu-flow`.
