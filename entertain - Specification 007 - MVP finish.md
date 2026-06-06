# Specification 007 — UI reorganisation, supplier category admin, ingredient states

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read `CLAUDE.md`, `entertain - Data model.md`, `entertain - Design system.md`,
> and the prior Specifications before starting. This is the last MVP
> Specification: with it, the app gains the structural UI it needs for
> long-term growth, the ability to manage supplier categories from within
> the app, and the ingredient-state machine that turns the shopping panel
> from a planning aid into an execution radar ("what do I still need for
> this event?").

---

## 1. Goal

After Specifications 001 to 006, the app has the full functional cycle:
events, dishes, ingredients, shopping lists per supplier, and message
dispatch with delta and multi-order. What is missing for the MVP to be
shipping-ready is twofold.

First, the navigation structure. The event detail screen and the
Settings screen have grown organically with each Spec and now mix
concerns awkwardly (an edit-pencil for the event next to a segmented
control for menu/shopping; a flat Settings page with greeting,
signature, and per-category channel configuration all together). A
tab-based reorganisation puts each concern in its own surface, keeps
the screens scalable for future growth, and aligns the app with the
patterns the project owner intuitively expects.

Second, the ingredient-state machine. The current shopping panel
tracks orders (what has been sent to whom) but not the state of each
ingredient (do I have it at home, have I ordered it, has it arrived,
is it still missing?). Adding that layer turns the shopping panel
from a planning tool into the radar the project owner needs the day
before the event.

This Spec is structured in two phases on the same branch:

- **Phase 7A — UI reorganisation and supplier category admin.** Pure
  structural and management changes. No new behaviour.
- **Phase 7B — Ingredient state machine and unified shopping panel.**
  Adds the state machine, the auto-transitions, the manual
  transitions, and the per-event summary header. Folds the shopping
  panel into the new structure.

The two phases are validated separately on the device, but they
arrive together on a single PR against `main`.

---

## 2. Scope — Phase 7A

### 2.1 Event detail screen — tabs Event / Menu / Shopping

Replace the current event detail screen (header + segmented control
Menu/Shopping + edit-pencil) with a three-tab layout:

1. **Esdeveniment** — the event's own data, editable in place. All
   the fields currently in the event edit form (title, type, format,
   date, time, guests, location, notes) live here, with a "Desa"
   action visible whenever there are unsaved changes. No separate edit
   screen, no edit-pencil.
2. **Menú** — the dish menu, exactly as it is today.
3. **Compra** — the shopping panel, exactly as it is today.

The tabs are text-only, no icons, consistent with the bottom
navigation bar. The default tab when opening an event from the list
is **Menú** (the most common landing point for ongoing planning).

The dish menu and the shopping panel are unchanged in this phase — only
their containing surface changes.

### 2.2 Settings screen — tabs General / Suppliers / Messages

Replace the current flat Settings screen with a three-tab layout:

1. **General** — for now, contains only an "About the app" entry with
   version and basic info. The language selector is **out of scope**
   for the MVP; Locale is detected automatically from the system. The
   fallback for unsupported locales is English.
2. **Proveïdors** — the supplier category management surface (see
   §2.3 below). Replaces the current per-category channel
   configuration cards. The per-category channel and address
   configuration moves under this tab as well, as part of each
   category's detail screen.
3. **Missatges** — the existing greeting ("Salutació") and signature
   ("Signatura") fields, plus any future message-format options.

Default tab when opening Settings is **General**.

### 2.3 Supplier category admin

The Proveïdors tab presents a list of all supplier categories
currently available to the user (system seed plus any the user has
added). Each row shows the category's display name and a brief
indicator of its configured channel/address if any.

A primary "Afegeix categoria" action is visible at the top or bottom
of the list, opening a small form to create a new user category.
The form has a single field: **Nom** (name) — typed in the user's
current locale. The new category is created with that name in the
current locale; the other locales fall back to the same name until
the user edits them.

Tapping a category opens its **detail screen**, with:

- **Nom** field (editable for the current locale only for user
  categories; for system categories, a three-field form is shown for
  Catalan / Spanish / English, to keep the translations coherent
  across locales).
- **Canal** selector (WhatsApp / Email / None).
- **Adreça** field (phone or email, depending on channel).
- **Esborrar** action at the bottom — visible for user categories,
  visible but disabled with explanation for the system "Rebost"
  category (cannot be deleted), visible for all other system
  categories (delete allowed for non-pantry system categories, with
  the implication that ingredients assigned to that category retain
  their `supplier_category_id` as null after deletion).

System categories are identified by `code` (the internal stable
identifier such as `fishmonger`, `pantry`, etc.); the display name
is just a translation. The "Rebost" category is special because its
`code = 'pantry'` triggers consultive behaviour throughout the app
(no message dispatch, etc.); renaming it does not affect that
behaviour.

The data model:

- `supplier_categories` keeps its `code`, `is_system`, and the new
  `group_id` (nullable; null for system categories shared by all
  groups, set to the group's id for user categories scoped to that
  group). Add a migration for the `group_id` column if it does not
  exist yet.
- `translations` is used as today; the three system locales remain
  for system categories; user categories may have one or more
  locale entries depending on what the user fills in.

When a user category is deleted, all its `event_dish_ingredients`
references are cleared (set to null) before the deletion. The
shopping panel will subsequently show those ingredients under "Sense
categoria".

### 2.4 Acceptance criteria for Phase 7A

The phase is complete when the project owner can verify all of the
following on the Android device:

1. Opening an event from the list shows three tabs — Esdeveniment,
   Menú, Compra — with the default tab being Menú. The
   Esdeveniment tab contains the event's own fields, editable
   directly with a "Desa" button when there are unsaved changes.
2. Opening Settings shows three tabs — General, Proveïdors,
   Missatges — with the default tab being General.
3. The Proveïdors tab lists all current supplier categories. From
   here, the user can add a new category with a single "Nom" field;
   the new category appears in the list immediately.
4. Tapping any category opens its detail screen with name, channel,
   and address fields, plus a delete action. User categories are
   deletable; the system Rebost category is not; other system
   categories are deletable with an appropriate confirmation.
5. Renaming a system category (e.g. "Fruiteria" → "Verduleria") in
   the current locale persists across app restarts. The category's
   behaviour (especially Rebost's consultive nature) is unaffected.
6. All existing flows that used the previous Settings layout continue
   to work (sending messages, configuring channels, etc.).

---

## 3. Scope — Phase 7B

### 3.1 Ingredient state machine

Each `event_dish_ingredients` row gains an explicit **state** column,
representing where the ingredient is in the user's mental shopping
process:

- `at_home` — already in the user's pantry / kitchen.
- `to_order` — needs to be ordered or bought.
- `ordered` — has been ordered (a supplier message has been sent for
  it).
- `received` — has been delivered or bought and is in the kitchen.
- `missing` — should have been ordered/bought but isn't, used as a
  late-stage alarm before the event.

Add a column `state` (enum) to `event_dish_ingredients` via migration.
Default value: `to_order` for new lines, `at_home` for lines whose
`supplier_category_id` resolves to the system Rebost category
(`code = 'pantry'`).

### 3.2 Automatic state transitions

The following transitions happen automatically:

- **On adding a dish to a menu**: each new `event_dish_ingredients`
  line is created with state `to_order` (or `at_home` if its
  resolved category is Rebost).
- **On adding an ad-hoc ingredient line** to a per-event dish detail:
  same rule as above.
- **On sending a supplier message** that includes a given line: the
  line's state moves to `ordered`. This applies to every line in
  the order that the user actually sent (subject to the confirmation
  flow from Spec 005 §2.7 — if the user said "no, not sent", no
  transition happens).
- **On removing a dish from the event menu**: the rows are deleted
  (no state change needed).

### 3.3 Manual state transitions

The user can manually move a line to:

- `received` from `ordered` or `to_order` (the latter for direct
  purchases the user makes without going through the message flow).
- `missing` from any state, as a flag.
- Back to `to_order` from any state, as a reset.
- Between `at_home` and `to_order` for ingredients in the Rebost
  category (the user explicitly tells the app whether they have it
  or not).

A bulk action on each supplier section: "Marca tot com a rebut" —
moves every line currently in `ordered` to `received` for that
supplier in this event. Visible only when the supplier section has
at least one line in `ordered`.

### 3.4 Unified shopping panel (replaces the current Compra tab)

The Compra tab is rebuilt to integrate the state machine. Its
content, per event:

**Summary header** at the top, showing the global state of all
ingredients in the event:

> 15 ingredients · 8 a casa · 5 per demanar · 2 demanats · 0 rebut · 0 falten

The counts adjust as the user makes changes.

**Sections per supplier**, in the order: assigned supplier
categories first (sorted by category name), then "Sense categoria"
last. Each section has:

- **Category name** as header, with a per-category state summary
  (a compact version of the global summary, for that supplier only).
- **Sub-groups by state**, in this order: Per demanar, Demanat,
  Rebut, Falta, A casa. Each sub-group lists the ingredient lines
  whose state matches.
- **Actions** at the bottom of the section:
  - "Envia missatge" — available when there is at least one line in
    `to_order` (the delta to be sent).
  - "Usa com a llista de la compra" — always available if the section
    has any line in `to_order` or `ordered` or `received`.
  - "Marca tot com a rebut" — available when there is at least one
    line in `ordered`.
- Sections for Rebost-category and "Sense categoria" do **not** show
  message-sending actions, consistent with prior Specs. They do show
  the state machine and the bulk action where applicable.

Each ingredient line in any state shows a small state indicator and
a tap-action to change state manually (a small popup with the
allowed transitions for that line's current state).

### 3.5 Acceptance criteria for Phase 7B

The phase is complete when the project owner can verify all of the
following on the Android device:

1. Adding a dish to an event menu creates ingredient lines in state
   `to_order` by default, and in `at_home` for lines whose category
   is Rebost.
2. Sending a supplier message via the existing flow moves every line
   in that order to `ordered`, but only after the user confirms the
   send was successful (the Spec 005 §2.7 confirmation).
3. The Compra tab shows a summary header with the global counts of
   each state for the event, updating in real time as the user
   changes states.
4. Per-supplier sections show sub-groups by state, with the order:
   Per demanar, Demanat, Rebut, Falta, A casa. Each line has a
   state indicator and a tap-to-change action.
5. The bulk action "Marca tot com a rebut" works correctly for a
   supplier section, moving all lines from `ordered` to `received`.
6. The Rebost section shows the state machine without
   message-sending actions; lines there default to `at_home` but
   can be moved to other states as needed.
7. The "Sense categoria" section behaves like Rebost in terms of
   actions (no message dispatch) but shows the full state machine.
8. After a real event-day workflow (planning → message sending →
   delivery confirmation → consumption), the summary header and
   the per-section sub-groups accurately reflect the project owner's
   real situation, with no manual data manipulation required.

---

## 4. Out of scope

Explicitly **not** part of this assignment (deferred to Phase 1 or
later):

- Language selector in Settings (deferred; Locale auto-detection is
  the MVP behaviour).
- Theme selector (light / dark / auto).
- Icons or colours for supplier categories (only name in the MVP).
- Contact picker integration for the WhatsApp / email address field.
- Display label / name on per-category messaging configuration (the
  current category name in the user's locale serves as label).
- Pantry as a dynamic inventory (just a state column on
  `event_dish_ingredients` for the MVP; the actual pantry tracking
  goes to Phase 1).
- Cooking schedule, total-food verification, package-equivalence
  editor, photos. Phase 1.
- iOS support. Phase 2.

---

## 5. Implementation notes

- The branch is `feat/spec-007-mvp-finish`. Phase 7A commits land
  first, then a midway point where the project owner validates the
  reorganisation. Phase 7B commits land after that. One PR against
  `main` carrying both phases.
- The migrations land in chronological order: first the Phase 7A ones
  (supplier category `group_id` if needed, anything else
  structural), then the Phase 7B ones (`event_dish_ingredients.state`).
- The Compra panel rebuild is substantial because it has to
  preserve the existing delta + multi-order logic from Spec 005 while
  adding the state machine on top. Treat the existing
  `event_shopping_panel.dart` and its supporting code as the
  starting point, refactor as needed, but make sure none of the
  multi-order behaviour regresses.
- The pattern of "send → all lines in that order move to `ordered`"
  is the **only** place where the state machine interacts with the
  message dispatch flow. Keep them loosely coupled: the message
  dispatcher should not need to know about the state machine, only
  emit a notification or return a list of line ids whose state should
  be updated. The state update happens at the call site, after the
  confirmation.
- The state-change popup on each line should be a simple bottom
  sheet or dropdown with only the legal transitions for the current
  state; do not show all five states as options every time. Reduces
  cognitive load.
- Translation keys for all new strings must be added to `app_ca.arb`,
  `app_es.arb`, `app_en.arb`. No hardcoded user-facing strings.

If any ambiguity arises during implementation (especially around the
specific layout of the Compra tab — the exact visual hierarchy of
summary header, supplier sections, state sub-groups, and per-line
state indicators), stop and ask. The Spec gives the structure; the
visual detail benefits from the project owner's input.

---

## 6. PR description

The PR description should be split into three sections matching the
implementation order:

- **Phase 7A — UI reorganisation and supplier category admin.** The
  six acceptance criteria of §2.4.
- **Phase 7B — Ingredient state machine and unified shopping panel.**
  The eight acceptance criteria of §3.5.
- **Decisions taken during implementation.** Any decision you took
  without explicit guidance, with the rationale, so the project
  owner can review and validate.
