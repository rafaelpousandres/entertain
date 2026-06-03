# Specification 005 — Shopping lists and supplier messages (MVP screen group 3, first half)

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read `CLAUDE.md`, `entertain - Data model.md`, and `entertain - Design system.md`
> before starting. This specification is the only scope for this assignment; do
> not pull work forward from screen group 3 second half (Specification 006) or
> later phases.

---

## 1. Goal

Build the **shopping lists and supplier messages** half of the third MVP screen
group. After this assignment, an event's menu (built in Specifications 003 and
004) can be turned into per-supplier shopping lists. For supplier categories
that the user wants to send to a vendor (the fishmonger, the butcher, etc.),
the app composes a message and sends it through the user's configured channel.
For supplier categories the user wants to handle in person (a supermarket trip,
a pantry verification), the same list is available as a read-only view —
without sending anything — to be acted on later. The per-ingredient state
machine that tracks "received / missing / at home / ..." belongs to
Specification 006 and is **out of scope** here; this assignment lays the data
foundation but does not yet implement those states.

The new surfaces added in this assignment are:
1. **Event shopping panel** — a new view on the event detail screen showing the
   menu's ingredients grouped by supplier category, with per-category actions.
2. **Supplier message screen** — the screen that composes and sends the
   message to a vendor for one category of one event, captured as an `order`.
3. **Settings screen** — global app settings: signature for outgoing messages
   and per-category messaging preferences (channel + address).

---

## 2. Scope — what to do

### 2.1 General

- All screens build on top of the existing app: the Supabase client and
  anonymous-session bootstrap, the design system / theme, the i18n setup,
  Riverpod, and go_router.
- Reuse the UI toolkit established in Specifications 003 and 004 (primary
  and secondary buttons, icon circle, collapsible section header, form
  fields, segmented choice, stepper, searchable single-choice sheet). Add new
  components only if a genuinely new pattern is needed; if so, place them in
  `lib/ui/` and follow the existing conventions.
- All user-visible strings go through i18n (intl + ARB) per `CLAUDE.md`;
  extend the existing ca/es/en ARB files. Catalan is the display language for
  the MVP.
- All data access goes through the corresponding Phase 0 tables with RLS in
  force. Configuration (channel / address / signature) is group-scoped via
  membership; orders are scoped through their parent event.

### 2.2 Schema migration

Add a single migration that extends two existing tables, with no new tables:

- `supplier_categories`: add columns `channel` (enum or text:
  `whatsapp` / `email`, nullable) and `channel_address` (text, nullable).
  These are optional configuration applied per group / per category. They are
  read-only on system content from the client; concretely, each group has its
  own per-category configuration — store it however cleanly fits, but do not
  modify the `is_system` content seeded in earlier migrations.
  > Implementer note: if `supplier_categories` is a single system-shared table
  > and per-group configuration must not pollute it, introduce a small
  > companion table such as `group_supplier_settings(group_id,
  > supplier_category_id, channel, channel_address)`. Decide between extending
  > the existing table vs. introducing a companion table by inspecting the
  > current schema, and pick the cleanest option. Flag the decision in the PR
  > body.
- `orders`: add columns `sent_at` (timestamptz, nullable), `sent_channel`
  (same enum/text as above, nullable), and `sent_address` (text, nullable).
  These persist the fact and metadata of an actual send. They are nullable
  because an order may exist as a draft or as a snapshot that has not been
  sent yet (see §2.4).

The app's group-scoped signature lives wherever group-level configuration
already lives in the schema (the data model's `groups` table or its companion
profile, at the implementer's discretion). Add the field if it does not yet
exist (a single `signature` text column on the appropriate row).

Apply the migration to the remote project with `supabase db push` once
committed.

### 2.3 Event shopping panel

- A new section reachable from the event detail screen (in addition to the
  existing menu view). The implementer chooses the navigation pattern (tabs,
  segmented control, secondary screen). Whatever is chosen, both views must
  feel like equal-rank views of the same event, not parent / child.
- The panel shows, for the event in question, **all of its
  `event_dish_ingredients` grouped by their effective `supplier_category_id`**
  (the snapshot value at the line, including any per-event override applied
  in Specification 004). Use the collapsible section-header component from
  the design system, one section per category.
- Each section header shows the category name (translated), an icon, and the
  count of ingredient lines. Each line within a section shows the ingredient
  name, quantity, and unit.
- For the **"Rebost" (pantry)** category specifically, the section is
  consultive only — no action button, no message. It is there as a checklist
  of what the user must already have at home for the event (mise en place
  reference).
- For **any other** category, the section has two actions at its footer:
  - **Send message** — opens the Supplier message screen (§2.4) for this
    category of this event.
  - **Use as a shopping list** — flips the section into a "going to the shop"
    mode. In Specification 005 this is a visual mode toggle only: no order
    is created, no message is composed, no state is yet tracked at the
    ingredient level. The mode is purely a hint to the user that they will
    handle this category in person. The per-ingredient state machine that
    makes this mode actionable lives in Specification 006.
  - A category may have multiple `orders` already sent (see §2.4) and at the
    same time newly-added ingredients that have not been sent yet. The
    section in that case shows the sent orders as historical entries and the
    delta of unsent ingredients with the action footer available.

### 2.4 Supplier message screen

- Opened from the event shopping panel when the user taps "Send message" on
  a category section. The destination is **one** category for **one** event.
- The screen shows:
  - A short header: vendor name (category), event title, event date.
  - The composed message text as a read-only block. Format is universal text
    (no Markdown, no platform-specific styling) with a clear structure:
    - A brief identifying line (event title, event date).
    - The list of items, one per line, in the form `<quantity> <unit> <ingredient name>`.
    - The signature configured in §2.5, separated by a blank line.
  - A primary action **Send**.
  - A small secondary affordance to change the destination for this one
    send only (override). The override does **not** modify the
    configuration in Settings.

#### Send behaviour

- The set of ingredients composing the message is **the entire current set of
  `event_dish_ingredients` lines for this event that belong to this category
  and have not yet been included in any sent order for the same event and
  category** (the **delta**, per §2.4 below). It is **not** an interactive
  selection: the user pre-arranges the menu before sending.
- On send:
  - Create a new row in `orders` for `(event_id, supplier_category_id)`,
    with `sent_at = now()`, `sent_channel` and `sent_address` set to the
    channel and destination actually used.
  - Create one row in `order_items` per ingredient line in the delta, copying
    `ingredient_name`, `quantity`, `unit_id` from the corresponding
    `event_dish_ingredients` rows. The snapshot is a true copy: subsequent
    edits to the event's menu do not affect the order's items.
  - Dispatch the message:
    - If the category has a configured channel:
      - `whatsapp`: open WhatsApp with a `https://wa.me/<number>?text=<urlencoded>` URL through `url_launcher` or `share_plus`, with the message text pre-filled. The address is the WhatsApp number including international prefix.
      - `email`: open the default email client with destination, subject (event title + category name + date, in Catalan), and body pre-filled. The address is the email address.
    - If no channel is configured (or the destination is unreachable for some reason), invoke the system's Share Sheet (`share_plus` `Share.share(text)`) and let the user pick the destination at that moment.
  - Capture `sent_channel` and `sent_address` from the actual dispatch (the
    configured ones, or the override if used, or whatever the share sheet
    handled).
  - The user is then returned to the event shopping panel.

#### Delta and successive orders

- Each `(event_id, supplier_category_id)` may have **multiple** orders sent
  successively if the user edits the menu and adds more items between sends.
  This is by design.
- When opening the supplier message screen for a category that already has
  one or more orders sent, compose the message from the **current event's
  ingredients of that category** minus the **union of all items already
  contained in previous orders for this `(event_id, supplier_category_id)`**.
  Match by `event_dish_ingredients.id` if possible, or by a stable key
  composed of the ingredient and the line's identity.
- If the delta is empty (everything has already been sent), show a clear
  "nothing to send" state with the list of previously-sent orders for this
  category.

### 2.5 Settings screen

- A new top-level screen accessible from the existing bottom navigation
  shell. Add a fourth tab "Settings" with an appropriate icon, **only if** it
  fits with the existing three tabs (Events, Dishes, Ingredients); otherwise,
  use an overflow action on the events list screen (top right). Decide
  during implementation and flag the chosen navigation in the PR body.
- The Settings screen contains two sections:
  - **Signature** — a single multi-line text field. The signature is appended
    to every outgoing message, separated by a blank line. Default is the
    user's `profiles.display_name` if set, otherwise empty.
  - **Per supplier category** — for each supplier category that is **not**
    the pantry, an editable row with: channel (radio: WhatsApp / Email /
    None), and the corresponding address field (phone number with
    international prefix, or email address). The system pantry category
    must not appear here.
- All changes persist immediately on edit, or with a save action — pick the
  cleanest option for this surface and flag it in the PR body.

### 2.6 Navigation and state

- Wire the new screens with go_router: event detail → event shopping panel
  (as tab or sibling); event shopping panel → supplier message screen; home
  shell → settings.
- Manage screen state and data with Riverpod, consistent with the existing
  structure. Reuse the providers and repositories already defined in
  Specifications 003 and 004.
- After sending an order, the event shopping panel reflects the new order
  immediately (the new order appears as a sent historical entry, and the
  unsent delta for that category is updated).

---

## 3. Out of scope

Explicitly **not** part of this assignment:
- The per-ingredient state machine (received / missing / at home / pending /
  ordered) and the corresponding actions and views. This is Specification
  006.
- Marking individual lines as received or in any specific state. The
  "shopping list" mode toggle in §2.3 is visual only.
- Multiple persistent vendors per category (we keep option B: one
  destination per category, with puntual override at send time).
- Re-sending an order. The `sent_at` and metadata reflect the most recent
  send; if the user wishes to re-send, a future iteration will add an
  explicit re-send action with traceability.
- The exact message text for the user — the format is fixed in §2.4 and not
  configurable in this assignment.
- Pantry as a managed inventory (stock control, automatic decrement) — that
  belongs to Phase 1.
- Auto-splitting of long messages across multiple sends.

---

## 4. Acceptance criteria

The assignment is complete when the project owner can verify all of the
following on the Android device:

1. From an event's detail, the user can switch to the event shopping panel
   and see the event's ingredients grouped by supplier category, including
   the pantry category as a consultive section.
2. The Settings screen lets the user set a global signature and per-category
   channel and address. Changes persist to the database.
3. Sending an order for a category with WhatsApp configured opens WhatsApp
   with the destination and the composed message pre-filled. The user only
   has to confirm and send.
4. Sending an order for a category with Email configured opens the default
   email client with the destination, subject, and body pre-filled.
5. Sending an order for a category without configured channel opens the
   system Share Sheet with the message text. The destination is selected by
   the user in the system.
6. The user can override the destination puntually at send time without
   modifying the persistent configuration.
7. After sending, a row is inserted in `orders` (with `sent_at`,
   `sent_channel`, `sent_address`), and one row per ingredient in
   `order_items`. The event shopping panel reflects this immediately.
8. If the user edits the event menu and adds new ingredients to a category
   after an order has been sent, the section's footer shows the unsent
   delta and offers to send a second order with only those new ingredients.
   Sending the second order does not modify the first.
9. The pantry category never offers a send action, only the consultive
   view.
10. All screens follow the design system and have no hardcoded user-facing
    strings.
11. The work is on a feature branch with a pull request against `main`,
    leaving `main` shippable, per `CLAUDE.md`.

---

## 5. Notes for the implementer

- The data model is the source of truth. Two new columns on
  `supplier_categories` (or a companion table for per-group configuration —
  see §2.2) and three new columns on `orders`. No new tables, no other
  structural changes.
- The per-ingredient state machine is **not** in this assignment. The
  "Use as a shopping list" mode toggle is purely a visual hint; do not
  attempt to track any state at the ingredient level. That work begins in
  Specification 006, and this Spec must leave the door open for it
  without anticipating its choices.
- Avoid duplication or accidental re-sending: the delta computation in
  §2.4 is the critical mechanism. Test it with several successive sends
  on the same event and same category.
- The Settings screen is functional, not aspirational. Per-category
  configuration must persist correctly across app restarts and across
  sessions.
- The PR description should describe the schema migration explicitly, the
  navigation pattern chosen (where settings lives, how event shopping
  panel relates to the menu view), and any structural decision made during
  implementation that was left open in this Spec.
- Keep scope strict. Anything related to ingredient state, pantry
  inventory, or vendor multiplicity is for later iterations.
