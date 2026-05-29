# Specification 003 — Event screens (MVP screen group 1)

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read `CLAUDE.md`, `entertain - Data model.md`, and `entertain - Design system.md`
> before starting. This specification is the only scope for this assignment; do
> not pull work forward from later screen groups or phases.

---

## 1. Goal

Build the first real feature screens of entertain: the three screens of the
**Event** group. After this assignment the app no longer shows the
Specification 002 placeholder — it opens on a list of the user's events, lets the
user create and edit an event, and lets the user open an event to see its detail
and menu. These screens read from and write to the Phase 0 schema delivered in
Specification 002.

The three screens are:
1. **Events list** — the app home; the list of the user's events and the entry
   point to create a new one.
2. **Event form** — create a new event or edit an existing one.
3. **Event detail / menu** — an event's header information and its menu (the
   dishes in the event).

---

## 2. Scope — what to do

### 2.1 General

- All three screens are built on top of the existing app: the Supabase client
  and anonymous-session bootstrap from Specification 002, the design system /
  theme, the i18n setup, Riverpod, and go_router.
- Replace the temporary placeholder screen from Specifications 001/002 with the
  Events list as the app's home. The startup bootstrap (Supabase init +
  anonymous session, with the auto-provisioned group and membership) must still
  run before the home screen renders; surface a clear error state if the backend
  is unreachable, but the placeholder connectivity readout itself is removed.
- All screens follow `entertain - Design system.md`: the warm (direction A)
  palette tokens, Fraunces for display/titles and Nunito Sans for body, the
  spacing scale, corner radii, and the card / list-row / primary-button /
  form-field / section-header components defined there. Use the project theme;
  if a token or component from the design system is not yet in the theme, add it
  to the theme rather than hardcoding values in a screen.
- Every user-visible string goes through i18n (intl + ARB) per `CLAUDE.md` — no
  hardcoded string literals. Follow the existing ca/es/en ARB setup; Catalan is
  the display language for the MVP.
- All data access goes through the `events` table with RLS in force
  (Specification 002). Events belong to a group: resolve the current user's
  group from their membership and create events within it.

### 2.2 Events list (home screen)

- The app's home. A top bar with the screen title, and a scrollable list of the
  user's events.
- Each event is a card / list row showing: a leading date element (day and
  month) derived from `event_date`, the event `title`, a secondary line
  combining `type`, `guest_count`, and `status`, and a trailing chevron. Handle
  an event with no `event_date` gracefully (no date element, or a neutral
  placeholder).
- Tapping an event card opens the Event detail / menu screen for that event.
- A clear empty state when the user has no events yet, inviting them to create
  the first one.
- A primary action — a full-width "New event" button in the bottom action bar —
  opens the Event form in create mode.
- Order the list in a sensible, stable way (e.g. by `event_date`, most recent
  first, with dateless events handled consistently). Exclude soft-deleted events
  (`deleted_at` not null).

### 2.3 Event form (create and edit)

- One screen used for both creating a new event and editing an existing one. A
  top bar with a back control and a title that reflects the mode.
- Fields, each mapped to the `events` table:
  - **Title** (`title`) — text.
  - **Type** (`type`) — a choice among lunch / dinner / other.
  - **Format** (`format`) — a choice among seated / buffet / other. (This is the
    field that will govern default servings per dish in a later phase; it is
    captured here.)
  - **Date** (`event_date`) and **Time** (`event_time`) — both optional; use
    native date / time pickers.
  - **Guest count** (`guest_count`) — an integer, edited with a stepper.
  - **Location** (`location_name`) — text. Do not build address / map /
    coordinate fields; those are later phases.
  - **Notes** (`notes`) — multi-line text, optional.
- `status` defaults to `planning` on creation and is not edited through this
  form in this assignment.
- The primary action saves the event: in create mode it inserts a new row in the
  user's group; in edit mode it updates the existing row. Validate that at least
  a title is present before saving.
- In edit mode, provide a way to delete the event. Deletion is a **soft delete**
  (`deleted_at`), per the data model; confirm with the user before deleting.
- On save or delete, return to the previous screen and reflect the change.

### 2.4 Event detail / menu screen

- Opened from an event card. Shows the event's header information — `title`
  (display type), and a metadata line with the date and guest count — and an
  edit affordance that opens the Event form in edit mode for this event.
- Below the header, the **menu**: the event's dishes (`event_dishes`) grouped by
  `category`, using the collapsible section-header component from the design
  system (category icon, label, count). Each dish row shows the dish name and a
  trailing chevron.
- Because adding dishes to an event is built in the next screen group, an event
  will normally have no dishes yet at this point: implement a clear
  **empty-menu state**. Build the grouped-by-category list structure so the next
  group can populate it without rework.
- The actions that belong to later groups — adding a dish to the menu (screen
  group 2) and generating the shopping list (screen group 3) — are **out of
  scope here** (see §3). Either omit their controls or render them as clearly
  non-functional placeholders; flag the choice.

### 2.5 Navigation and state

- Wire the three screens with go_router: home (events list) → event detail →
  event form (edit); and home → event form (create).
- Manage screen state and data with Riverpod, consistent with how the app is
  already structured.
- After creating, editing, or deleting an event, the events list and the detail
  screen reflect the current data without requiring an app restart.

---

## 3. Out of scope

Explicitly **not** part of this assignment:
- Adding, editing, or removing dishes within an event, the dish catalog, and the
  ingredient catalog and editors (screen group 2).
- Generating or sending the shopping list, and the settings screen (screen
  group 3).
- The `address`, `latitude`, and `longitude` fields of `events`, and any map UI
  (later phases).
- Editing an event's `status`, event photos / media, guest lists and people,
  event duplication, and quantity scaling (later phases).
- Real authentication UI — the anonymous session from Specification 002 is what
  these screens run on.

---

## 4. Acceptance criteria

The assignment is complete when the user can verify all of the following on the
Android device:

1. The app opens on the Events list instead of the Specification 002
   placeholder; startup still establishes the backend session, and an
   unreachable backend produces a clear error state.
2. With no events, the Events list shows the empty state; creating events makes
   them appear as cards with date, title, type, guest count, and status.
3. The New event button opens the Event form; filling it in and saving creates
   an event that appears in the list and is stored in the `events` table within
   the user's group.
4. Opening an event shows its detail / menu screen with the event header and an
   empty-menu state; the edit affordance opens the Event form pre-filled, and
   saving changes updates the event.
5. Deleting an event from the edit form removes it from the list (soft delete:
   `deleted_at` set; the row is not physically removed).
6. All three screens follow the design system (warm palette, Fraunces / Nunito
   Sans, cards, buttons, form fields) and contain no hardcoded user-facing
   strings.
7. The work is on a feature branch with a pull request, leaving `main`
   shippable, per `CLAUDE.md`.

---

## 5. Notes for the implementer

- These are the first screens the project owner will test as a real product, and
  he will manually enter his own events and (later) dishes through them. Keep the
  create / edit flows fast and low-friction: sensible defaults, only the title
  mandatory, forgiving validation, and a quick path from the list to creating an
  event.
- The data model is the source of truth for structure. If a field or
  relationship does not translate cleanly to a screen, stop and flag it on
  claude.ai rather than improvising a structural change.
- The event detail / menu screen is deliberately a partial screen at this stage:
  its menu will be empty until screen group 2 adds the dish flow. Build its
  structure (header, grouped-by-category menu, empty state) so the next group
  plugs in without rework, and do not build the deferred actions.
- Keep scope to this screen group. Do not pull dish, ingredient, shopping-list,
  or settings work forward.
