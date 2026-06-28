# Spec 028 — In-person shopping mode

Branch: one PR. No data-model change (reuses the existing shopping state machine).
Builds on the existing shopping screen — this is a **presentation variant**, not a new screen.

## Context

Shopping has two real-world modes: **ordering** (preparing supplier orders from home) and
**buying in person** (walking a shop/market, ticking off what you pick up). The current
shopping tab is built for **ordering** — states, supplier messages, order delta, deadlines.
This spec adds an **In-person** mode: the same list, the same data, the same states, but a
**simplified checklist** presentation for use while physically shopping.

Both modes are two faces of one thing — they operate on the **same shopping data and the
same state machine**. Nothing is duplicated; the interface adapts.

Note: the in-person mode does **not exist yet** (it was described in the manual/hints as a
planned feature). This builds it from scratch, but by **reusing** the ordering screen.

## A. The two modes

The **Compra** tab presents two sub-modes via **bottom tabs** (the bottom area of the
shopping screen is currently empty, so the tabs fit with no crowding):

- **Comandes** — the current screen, unchanged (supplier orders, states, messages, delta…).
- **En persona** — the new simplified checklist (this spec).

**Default mode** is chosen in **Configuració** (a new setting: which sub-mode the Compra tab
opens in). The tabs let the user switch on the fly within a session; the setting decides
which one is shown first.

## B. The In-person mode — reuse the ordering screen, simplified

In-person mode **reuses the existing shopping screen structure**, keeping most of it and
stripping the ordering-specific controls.

**Kept (identical to Comandes):**
- Header with counters (# ingredients, # by state).
- Sections per supplier, with the variable-color icon + pending/resolved count indicator.
- The whole accordion structure (collapsible sections).
- Supplier-grouped aggregation, quantities, units — all as today.
- **The existing color counters give "progress" for free** (green for received/at-home, etc.)
  — no new progress widget needed.

**Removed (inside each section):**
- "Afegeix extra" button.
- "Envia missatge" (supplier order message).
- "Usa com a llista de la compra".
- The full state selector / state transitions UI.

**Changed — the per-item control:**
- Each item shows a **checkbox** instead of the state selector.
- **Checked** when the item's state is **rebut** or **a casa**; **unchecked** for any other
  state (per demanar, demanat, falta…).
- Tapping to **check** → sets state to **rebut**.
- Tapping to **uncheck** (mistake recovery) → sets state back to **pendent** (per demanar).
- Because checked = received/at-home, the header/section color counters update exactly as in
  ordering mode (received items count green) — the user sees their progress through the shop.

That's it — In-person mode is essentially **a checklist with sections**. No managing, just
doing: walk, tick. To add an extra item or send an order, switch to Comandes.

## C. Photos on shopping rows (both modes)

The shopping rows currently show **no photo**. Add the **ingredient's cover photo** as a small
thumbnail on each row, in **both** modes (Comandes and En persona).
- Especially useful in In-person mode: recognizing a product by sight while walking the aisles
  is faster than reading.
- A small thumbnail at the leading edge of each row, like other lists in the app.
- Item with no photo → no thumbnail (no placeholder), as elsewhere.
- Bought dishes / drinks / extras: their photo if any, otherwise none.

## D. Implementation notes

- Reuse the existing shopping screen/widgets
  (`lib/features/shopping/screens/event_shopping_panel.dart` and its row/section widgets).
  Implement In-person as a **presentation variant** controlled by a mode flag, not a new
  screen — share the data providers, grouping, counters, and section/accordion widgets.
- Bottom tabs in the Compra tab toggle the mode flag (Comandes / En persona).
- New setting in Configuració: default shopping sub-mode (Comandes | En persona), persisted
  like other settings (the SharedPreferences-style store already used for prefs). The Compra
  tab reads it to pick the initial tab.
- The checkbox maps to the existing state machine: check → `rebut`; uncheck → `pendent`.
  Reuse the same state-update path the ordering screen uses (no new persistence logic).
- Photo thumbnail: resolve the ingredient cover via the existing
  `entityCoverPathsProvider` / `photoBytesProvider` path already used elsewhere; show a small
  rounded thumbnail. Applies to both modes (the shared row widget).
- i18n: ARB keys for the two tab labels (Comandes / En persona), the Configuració setting
  label + options. Follow app language.

## E. Edge cases

- An item in an intermediate state (e.g. `demanat`) shows **unchecked** in In-person mode
  (you don't have it yet) until ticked.
- Switching modes never changes data — only how it's shown.
- Empty shopping list → same empty state as today, in both modes.
- The default-mode setting only sets the **initial** tab; the user can switch freely after.

## Tests

- The checkbox reflects state: received/at-home → checked; any other → unchecked.
- Checking sets `rebut`; unchecking sets `pendent` (round-trip through the real state path).
- In-person mode hides: add-extra, send-message, use-as-list, state selector.
- In-person mode keeps: header counters, supplier sections, accordion, aggregation.
- Default sub-mode setting persists and selects the initial tab.
- Photo thumbnail renders on rows that have a cover, in both modes; absent when no photo.

## Verification

1. `flutter analyze` + `flutter test` green.
2. On the Pixel 8 Pro: in an event's Compra tab, switch to **En persona** → sections with
   counters and color icons, each row a checkbox + photo + name + quantity, no order buttons.
   Tick items → they count as received (green counters move); untick → back to pending.
   Switch to **Comandes** → full ordering screen intact. Set the default mode in Configuració
   → reopen Compra → it opens in the chosen mode. Photos show on rows in both modes.

## Out of scope

- Any change to the ordering mode's behavior (it stays exactly as is).
- Adding extras / messages / use-as-list in In-person mode (those live in Comandes).
- Per-aisle ordering of items (sections are by supplier; intra-section order unchanged).
- Changes to the underlying shopping state machine.
