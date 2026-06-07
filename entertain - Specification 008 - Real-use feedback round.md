# Specification 008 — Real-use feedback round

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read `CLAUDE.md`, `entertain - Data model.md`, `entertain - Design system.md`,
> and the previous specifications (001 through 007 plus their fixes rounds)
> before starting. This is the first specification after closing the MVP
> (Specs 001–007, merged in PR #16) and starting real-world usage. It
> collects eleven items that emerged during the project owner's first
> sustained use of the app on real events.

---

## 1. Goal

The MVP is complete and the project owner has started entering real data
and using the app for actual events. The first sustained use surfaced a
batch of improvements — some small bugs, some structural — that this
specification gathers into a single coherent pass before continuing.

The eleven items, grouped by nature:

**Small corrections** (no model changes):
- §2.1 — Capitalise the app display name from "entertain" to "Entertain".
- §2.6 — Rename the seed supplier category "Fruiteria" to "Verduleria"
  (es: "Verdulería"; en: "Greengrocer").
- §2.7 — In the supplier categories list (Settings > Proveïdors),
  always place "Rebost" last (after all dispatch-capable categories,
  alphabetical among themselves).
- §2.8 — Remove the "Signatura" section title in Settings > Missatges
  and rename the underlying "Signatura dels missatges" field to just
  "Signatura". Keep the Salutació field as is.
- §2.11 — Solve the "Desa button hidden by keyboard" usability bug.

**Functionality additions** (model changes):
- §2.3 — Supplier categories grow a free-text "Nom" field for the
  concrete supplier name (e.g. "Peixos Samba"). The existing "Nom"
  field that holds the category label is renamed to "Categoria".
- §2.4 — Events gain a derived `status` field with three values:
  in-preparation, ready, past. The events list groups events by
  status with collapsible sections.
- §2.5 — When adding an ingredient to a dish (catalog or per-event),
  the ingredient editor exposes the supplier category selector so it
  can be set at creation time.
- §2.9 — Add a global message-text-channel setting (SMS vs WhatsApp)
  alongside the existing greeting and signature. The "text" icon in
  supplier dispatch resolves to the configured channel at send time.
- §2.10 — The number of servings for a dish in an event becomes
  editable. Ingredient quantities scale automatically when the value
  changes.

**Visual identity**:
- §2.2 — The launcher icon adopts the new "table with six chairs"
  design. This is a passive asset swap and is treated as a parallel
  operational pass (not a code feature).

---

## 2. Scope — what to fix

### 2.1 App display name: "Entertain"

**Observed**: the app installs on Android with the visible label
"entertain" (lowercase). The wordmark in the visual identity uses
lowercase intentionally as a graphical decision, but as an OS label
on the launcher and in app switchers, the lowercase first letter
reads as a typo. The user instinctively expects "Entertain".

**Fix**: change the `android:label` attribute in
`android/app/src/main/AndroidManifest.xml` from `entertain` to
`Entertain`. The wordmark in the visual identity (logo lockup) keeps
the lowercase styling — that is a typographic choice, not a
display-name change.

If the app name appears anywhere else in code (splash screen,
internal references, package descriptions, README), audit those and
align with the new capitalisation where the context is "the app's
display name". Internal package names (`com.entertain.app` or
similar) stay lowercase per Java/Dart convention.

Translations: ca "Entertain", es "Entertain", en "Entertain".

### 2.2 New launcher icon (table with six chairs)

**Observed**: the current launcher icon (introduced as part of Fase
0.5) shows a round table with six plates only. The project owner has
designed a new variant that adds six D-shaped chairs around the
table — one per plate, in alternating colours opposite to each plate,
each with an inner cream contour line that echoes the plate styling.

**Fix**: replace the three icon assets at `assets/icon/` with the
new design (v15 from the design iteration session). The three files
are:

- `assets/icon/entertain - icon foreground.png` (1024×1024,
  transparent background, scaled 1.30× compared to the previous
  version so the design uses more of the canvas).
- `assets/icon/entertain - icon background.png` (1024×1024, solid
  cream `#FBF5EA`).
- `assets/icon/entertain - icon legacy.png` (1024×1024, rounded
  square with cream background and the centred design).

After replacing the files, regenerate the Android launcher icons by
running `dart run flutter_launcher_icons`. The generated icons under
`android/app/src/main/res/mipmap-*/` and
`android/app/src/main/res/drawable-*/` will be overwritten with the
new design.

This is a parallel operational pass and may be committed alongside
the §2.1 capitalisation change in the same commit ("App identity:
new launcher icon and display name").

### 2.3 Supplier category gets a "Nom" field for the concrete supplier

**Observed**: in the supplier category detail screen, the user can
already configure a phone number, an email address, and a channel
preference. The implicit reality is that these settings refer to a
**specific supplier** — for instance, the user's chosen fishmonger
is "Peixos Samba", and the phone/email belong to them. But the
screen never asks for the supplier's name. The user can't record
"Peixos Samba" anywhere; the category is just labelled "Peixateria".

**Fix**: extend the category detail model to include a free-text
field for the concrete supplier name.

Concretely:

- Rename the existing label-of-category field in the detail screen
  from "Nom" to **"Categoria"** (this is the multi-language label
  showing "Peixateria", "Carnisseria", "Verduleria", etc.). For
  system categories, this field stays read-only (per Spec 007 §3.4
  Option 4). For user categories, it remains editable.
- Add a new **"Nom"** field — free-text, single line — that stores
  the name of the concrete supplier (e.g. "Peixos Samba", "Tocineria
  Dani"). Optional (can be left empty). This applies to both system
  and user categories.

Schema:
- Add column `supplier_name TEXT` (nullable) to
  `group_supplier_settings`. This is per-group state — different
  groups can have different supplier names for the same shared
  category.
- No migration of existing data: the column defaults to NULL for all
  rows. Existing categories continue to work without a supplier
  name.

UI:
- The "Nom" field appears at the top of the supplier category detail
  screen, above the channel selector and address fields.
- For the Rebost category, the "Nom" field is not shown (Rebost has
  no contact details and represents the user's own pantry).
- The shopping panel supplier section header in the Compra tab
  continues to show only the **category label** (e.g. "Peixateria").
  The supplier name is informational at the detail level and does
  not appear on the shopping panel header.

Translations:
- "Categoria" (ca) / "Categoría" (es) / "Category" (en).
- "Nom" (ca) / "Nombre" (es) / "Name" (en).

Migration: `20260610010000_supplier_settings_supplier_name.sql`
adding the column.

### 2.4 Events have a derived `status` (in-preparation / ready / past)

**Observed**: the events list shows all events as a flat list with no
indication of how complete or current each event is. The user has
to open each event to check whether its menu is fully procured. As
events accumulate over time, past events mix with upcoming ones,
adding noise.

**Fix**: introduce a derived event status with three values, computed
at the UI/query layer (not persisted to the database).

**Statuses**:
- **Past** (`past`): the event's date is strictly before today (in
  the user's local time zone). Overrides everything else: a past
  event is always past.
- **Ready** (`ready`): the event's date is today or later AND every
  ingredient in the event's menu is in state `at_home` or `received`.
- **In preparation** (`in_preparation`): the event's date is today
  or later AND at least one ingredient is in any state other than
  `at_home` or `received` (i.e. `to_order`, `ordered`, `missing`,
  or the derived `delayed` from Spec 007 round 2). Events with no
  ingredients at all also count as in-preparation (the user is still
  assembling the menu).

**Transitions** are implicit through the computation: every render
recomputes the status from the current data. There is no event-level
state machine to maintain; the status reflects whatever the data
says.

**Presentation**:
- A coloured circular dot/indicator appears on each event card next
  to the title — same colour token system as the ingredient states
  (Spec 007 round 2):
  - In preparation → red (`danger`).
  - Ready → green (`success`).
  - Past → muted brown / disabled token (a calm, finished colour).
- The event detail screen header displays the status as a small
  pill/badge with the textual label next to the dot (e.g. a small
  rounded chip "En preparació" / "Ready" / "Passat"). On the event
  card in the list, the dot is sufficient; the label is not needed.

Translations:
- "En preparació" / "En preparación" / "In preparation".
- "Llest" / "Listo" / "Ready".
- "Passat" / "Pasado" / "Past".

**List grouping**:
- The events list groups events under three collapsible section
  headers, in this order: **En preparació**, **Llest**, **Passat**.
- Within each section, events are sorted by date ascending (closest
  first within in-preparation/ready; for past, the same — most
  recent past at the top of the past section).
- Default collapse state: **In preparation** expanded, **Ready**
  expanded, **Past** collapsed. The user can toggle each section.
  Collapsed/expanded state is per-session (not persisted).
- Each section header shows the section name and the count of events
  in the section (e.g. "En preparació · 2").
- Empty sections (zero events) are omitted entirely (no header
  shown).

Implementation note: the status is derived per event at query time.
For performance, the shopping panel aggregates already exist (Spec
007 §2 / round 2); the event list can reuse the same per-event
aggregation logic to determine the status without N+1 queries. The
implementer chooses the cleanest path.

### 2.5 Supplier category selectable when adding an ingredient

**Observed**: when adding a new ingredient to a dish (in the catalog
or per-event), the modal asks for name, quantity, unit, and prep
note — but not the supplier category. The newly created ingredient
is therefore assigned to "Sense categoria" and the user must navigate
to the Ingredients tab afterwards to assign it. This is friction in
the most frequent workflow (building a dish line by line).

**Fix**: add a **Categoria de proveïdor** selector to the "Afegeix
ingredient" modal. The selector lists all the user's available
supplier categories (system + user-defined) plus a "Sense categoria"
option at the bottom. The default selection is "Sense categoria" so
that nothing changes for the user who doesn't care.

The selector appears between the existing fields, in this order:
name, quantity & unit, **supplier category**, prep note.

This applies to:
- Adding an ingredient line to a catalog dish (from the dish detail
  screen).
- Adding an ad-hoc ingredient line to a per-event dish (from the
  event-dish detail screen — introduced in Spec 006 §2.2).

When editing an existing ingredient line, the selector also appears
and reflects the current value, so the user can change the category
without going to the Ingredients tab.

No schema change required: `event_dish_ingredients` already has
`supplier_category_id` (Spec 007 §2 — UI override). The catalog
`dish_ingredients` schema needs verification by the implementer; if
the supplier category is currently only stored at the
`ingredients` level (catalog-wide), then per-line override at the
catalog dish level is not in scope for this fix — only the modal UI
addition for setting it at the catalog `ingredients` level.

Confirm before implementing: if the catalog-level model already
allows per-line supplier override, follow that. If not, the modal
sets the category on the underlying `ingredients` row (which affects
all uses of that ingredient).

### 2.6 Seed category rename: Fruiteria → Verduleria

**Observed**: the seed supplier categories include "Fruiteria" (a
shop selling fruit). In real Catalan retail, the natural one-stop
shop for both fruit and vegetables is the **verduleria**. The
project owner expects the seed category to reflect the more useful
real-world category.

**Fix**: rename the seed category's translation labels:
- ca: "Fruiteria" → "Verduleria".
- es: "Frutería" → "Verdulería".
- en: "Greengrocer" (unchanged if already so; if "Fruit shop",
  update to "Greengrocer").

The change is to the translations table only (or the seed
migration's row for this category). The category ID, its
`is_system` flag, and any user data linked to it stay intact. Users
who have already configured contact details for this category
under its old name see the new label automatically.

Migration: `20260610020000_seed_category_rename_verduleria.sql`
updating the relevant translation rows.

### 2.7 Rebost is last in the supplier categories list

**Observed**: in Settings > Proveïdors, the categories appear in some
order (likely alphabetical or insertion order). The Rebost category
is conceptually different from the dispatch-capable categories: it's
a consultive section for the user's own pantry, not a supplier
relationship. It belongs visually at the bottom of the list, after
all the dispatch-capable categories.

**Fix**: in the supplier categories list at Settings > Proveïdors,
sort categories as follows:
- All dispatch-capable categories (everything except Rebost), sorted
  alphabetically by their localised category label.
- Then **Rebost** at the bottom.

This mirrors the existing sort in the shopping panel (Spec 007 round
2 §2.5), where dispatch-capable categories come first and Rebost
sits before "Sense categoria". In the Settings list there is no
"Sense categoria" entry (it's not a configurable category), so the
order is just: dispatchables alphabetical → Rebost.

### 2.8 Signatura section title cleanup in Settings > Missatges

**Observed**: in Settings > Missatges, the form currently has:
- A section title "Signatura".
- A subsection or field group titled "Signatura dels missatges"
  with the signature text field below.
- A Salutació field above.

The duplication (section "Signatura" containing subsection
"Signatura dels missatges") is redundant.

**Fix**:
- Remove the outer section title "Signatura".
- Rename the inner label "Signatura dels missatges" to simply
  **"Signatura"** — this becomes the field's own label, no longer a
  subsection title.
- The Salutació field continues to appear above, with its own label
  unchanged.

The final structure of the screen has two top-level form fields,
each with its own label: "Salutació" and "Signatura". No section
titles in between.

Translations: "Signatura" (ca) / "Firma" (es) / "Signature" (en) —
already used for the field label.

### 2.9 Message text channel: SMS or WhatsApp (group-level)

**Observed**: the supplier message dispatch supports WhatsApp as a
channel. In some regions (Spain, much of Latin America) WhatsApp is
the default for informal supplier conversations; in others (United
States, parts of Asia) SMS or a different messaging app is more
common. The "text" dispatch icon currently means WhatsApp
specifically; this assumption needs to be made configurable.

**Fix**: add a **group-level** setting "Canal de missatges de text"
(or similar) with the values **SMS** and **WhatsApp**. Stored in the
`groups` table alongside `signature` and `greeting`.

UI:
- In Settings > Missatges, add a new selector "Canal de missatges
  de text" with two options (SMS / WhatsApp).
- Default value for existing groups: WhatsApp (current behaviour).
  No data migration needed beyond setting the default in the
  migration.

Behavior:
- When a supplier category has its `channel` set to the text channel
  (currently `whatsapp` in the enum; conceptually now "text"), the
  dispatch resolves at send time to either the SMS app or WhatsApp
  based on the group's setting.
- For the dispatch icon shown in the channel selector and the
  Compra panel, the icon stays a chat-bubble regardless of which
  underlying app is configured — the icon represents "text message",
  the underlying app is a group preference.

Schema:
- Add column `text_message_channel TEXT NOT NULL DEFAULT 'whatsapp'`
  to `groups`. Allowed values: `'sms'`, `'whatsapp'`. Enforced by a
  CHECK constraint or an enum if cleaner.
- The existing `message_channel` enum (used for per-supplier channel
  preference) keeps the value `whatsapp` for backward compatibility
  in the per-supplier setting. The interpretation is now: "use the
  group's configured text channel". The enum value could be renamed
  to `text` in a later refactor; for this round, leave the enum as
  is and add the group-level setting on top.

Translations:
- "Canal de missatges de text" / "Canal de mensajes de texto" /
  "Text message channel".
- "SMS" / "SMS" / "SMS" (same across languages).
- "WhatsApp" / "WhatsApp" / "WhatsApp" (proper noun, no
  translation).

Future channels (Line, WeChat, Telegram, Signal) are out of scope
for this round but the design allows adding new enum values later
without breaking existing data.

Migration: `20260610030000_groups_text_message_channel.sql` adding
the column with default `'whatsapp'`.

### 2.10 Servings per dish in event: editable and scales ingredients

**Observed**: when a dish is added to an event, its servings count
is auto-assigned but **not editable** afterwards. The user wanted to
adjust the servings for a specific dish at the event level
(different from the catalog master) but can't. Additionally, when
the servings change, the ingredient quantities should scale
proportionally — but this is also not happening (because the field
is fixed at creation).

**Fix**: make the servings count for each event-dish editable, and
have ingredient quantities scale automatically whenever the value
changes (including the initial assignment when the dish is added to
the event).

Default values (assigned at the moment the dish is added to the
event):
- For events of type **Asseguts** (seated): the number of guests of
  the event.
- For events of type **Bufet** (buffet) or **Altre** (other): the
  master dish's own servings count (carried over from the catalog
  master).

Editability:
- The servings count appears as an editable field on the event-dish
  detail screen (next to the dish title or in the header area).
- The user can change it freely.
- When the value changes, all ingredient quantities for that event
  dish are recalculated immediately as:

  `new_quantity = (master_quantity / master_servings) * event_servings`

  rounded **up** to 2 significant figures.

  Examples:
  - master qty = 100 g, master servings = 4, event servings = 6 →
    100/4 * 6 = 150 g → rounded up to 2 sig figs = 150 g.
  - master qty = 250 g, master servings = 4, event servings = 6 →
    250/4 * 6 = 375 g → rounded up to 2 sig figs = 380 g.
  - master qty = 1 (egg, no unit), master servings = 4, event
    servings = 6 → 1/4 * 6 = 1.5 → for countable units (no unit
    declared, i.e. items like eggs / lemons), round up to the next
    whole integer = 2 eggs.

  For ingredients that have no unit (countable items, e.g. "3 ous"),
  always round up to the next integer regardless of the 2 sig figs
  rule (you can't have 1.5 eggs).

- The same rescaling fires also for ad-hoc ingredients (those that
  were added directly to the event-dish, not inherited from the
  master): they get their own implicit "master quantity" stored at
  creation time, scaled proportionally relative to the
  event-servings at the time of creation. If the servings change
  later, the ad-hoc quantity scales relative to its own initial
  servings reference.

Implementation note on data:
- The event-dish row needs to store the `servings` value (it likely
  already does, but as a fixed field — verify and make it
  updateable).
- For ad-hoc ingredient lines on event-dishes (per Spec 006 §2.2),
  we need to store their "reference servings" at creation so that
  later rescaling has a base. Add a column to
  `event_dish_ingredients` (e.g. `reference_servings INT`) if not
  already present. For lines inherited from a master dish, the
  reference is the master's `dish.servings`. For ad-hoc lines, the
  reference is the event-dish's `servings` at the time the line was
  added.

Verification with the project owner before implementing the rescale
logic is welcome if the data model interpretation has any ambiguity.

Migration: `20260610040000_event_dish_servings_editable.sql` —
ensures `event_dishes.servings` is mutable (no constraint
preventing updates) and adds `event_dish_ingredients.reference_servings`
if needed.

The future feature (Fase 1) of verifying the total servings across
the menu matches the event's guest count is **explicitly out of
scope** for this round.

### 2.11 Save button hidden by keyboard

**Observed**: in several modals and edit screens with a "Desa" button
at the bottom and a text field above, when the user taps the text
field, the on-screen keyboard slides up and covers the Desa button.
The user has to dismiss the keyboard first to access the button,
which is a friction point in many flows.

**Fix**: solve the keyboard-overlap usability bug with the
appropriate Flutter pattern for the platform.

The recommended approach for this app:

- **Android (primary platform)**: use
  `Scaffold(resizeToAvoidBottomInset: true, ...)` — already the
  default in Flutter, so verify this is set. Then ensure the bottom
  action area (where the Desa button lives) is part of a scrollable
  layout (e.g. `SingleChildScrollView` wrapping the form content
  with the button below). When the keyboard appears, the scroll
  view shrinks and the button is still reachable by scrolling.
- **Alternative pattern, simpler**: move the Desa button to the
  `AppBar` actions area as a text/icon action. This guarantees the
  button is always visible regardless of keyboard state. Material
  Design supports this pattern (e.g. Gmail's compose screen has a
  send icon in the app bar). Use this pattern for screens where the
  Desa action is the single primary action of the screen.
- **iOS (later)**: same as Android — Flutter's
  `resizeToAvoidBottomInset` and `SafeArea` patterns are
  cross-platform.

The implementer chooses the cleanest approach per screen. The goal
is: in every form screen, the user can complete entry and save
without dismissing the keyboard. Pick one pattern and apply it
consistently across the app for parity.

Out of scope: a global redesign of all forms. Just fix the cases
where the button is hidden.

---

## 3. Out of scope

Explicitly **not** part of this assignment:

- Multi-supplier per category (we keep the one-supplier-per-category
  model, only adding the "Nom" field).
- A history of past suppliers (when "Nom" changes, the old value is
  lost; no audit trail).
- Adding new channel options (Line, WeChat, Telegram, Signal) to
  the group-level text message channel.
- Verifying that the sum of servings across the menu matches the
  event guest count (Fase 1).
- Refactoring the `message_channel` enum value `whatsapp` to a more
  generic `text` (deferred to a later cleanup).
- Splash screen with the new logo (just the launcher icon for now).
- Notifications, reminders, or any time-based automation.

---

## 4. Acceptance criteria

The assignment is complete when the project owner can verify all of
the following on the Android device:

1. The app appears on the Android launcher and recent apps switcher
   as "Entertain" (capitalised), not "entertain".
2. The launcher icon is the new v15 design (table with six chairs).
3. In Settings > Proveïdors, opening any supplier category shows
   first a "Nom" field (free text, for the concrete supplier name),
   then the "Categoria" field (read-only for system categories,
   editable for user categories), then the channel selector and
   address fields. The "Nom" field persists independently per
   category and per group.
4. The Rebost category does not show the "Nom" field.
5. Events have a derived status (`in_preparation` / `ready` /
   `past`) computed from the current ingredient states and event
   date. A coloured indicator (red/green/brown) is visible on each
   event card in the list. The event detail header shows a small
   labelled chip with the status name.
6. The events list groups events under three collapsible sections:
   En preparació (expanded by default), Llest (expanded), Passat
   (collapsed). Each section header shows the section name and the
   count. Empty sections are not shown.
7. Within each section, events are sorted by date ascending.
8. Changing an ingredient's state (e.g. moving the last `to_order`
   ingredient to `received`) updates the event's status in real
   time. Changing the event date from future to past moves it to
   the Passat section.
9. In the "Afegeix ingredient" modal (both catalog and per-event),
   a "Categoria de proveïdor" selector is present. Editing an
   existing ingredient line also shows the selector with the
   current value.
10. The seed category formerly labelled "Fruiteria" is now
    "Verduleria" (ca), "Verdulería" (es), "Greengrocer" (en).
    Existing data linked to this category is preserved.
11. In Settings > Proveïdors, Rebost appears at the bottom of the
    list, after all dispatch-capable categories sorted
    alphabetically.
12. In Settings > Missatges, the "Signatura" section title is gone.
    The screen shows two top-level form fields: Salutació and
    Signatura. No subsection titles.
13. In Settings > Missatges, a "Canal de missatges de text" selector
    appears with two options (SMS / WhatsApp). Default for existing
    groups is WhatsApp. Changing this value affects which app opens
    when the "text" channel is used for supplier dispatch.
14. In an event-dish detail, the "Raccions" field is editable. When
    the value changes, all ingredient quantities update immediately
    according to the scaling rule (rounded up to 2 sig figs for
    measured ingredients, rounded up to the next integer for
    countable ones).
15. The default servings on adding a dish to an event respect the
    event type: Asseguts → guests count; Bufet/Altre → master dish
    servings.
16. In every form screen with a Desa button (or equivalent primary
    action), the button remains accessible while the on-screen
    keyboard is open — either visible via scroll or in the AppBar.
17. All affected screens follow the design system and have no
    hardcoded user-facing strings.
18. All existing flows continue to work without regression.
19. The work is committed to a new branch `feat/spec-008-real-use`
    with a clean PR description listing the eleven items.

---

## 5. Notes for the implementer

- This specification is broader than the Fixes rounds of Spec 007:
  it touches the data model (supplier_name, text_message_channel,
  potentially event_dish_ingredients.reference_servings), the
  state-derivation layer (event status), the UI of several screens
  (Settings > Proveïdors, Settings > Missatges, events list, event
  detail, add-ingredient modal), and the launcher icon assets.
  Plan the work in roughly the order of the §2 items so that each
  pass is independently testable.
- Migrations to apply remotely:
  - `20260610010000_supplier_settings_supplier_name.sql` (§2.3).
  - `20260610020000_seed_category_rename_verduleria.sql` (§2.6).
  - `20260610030000_groups_text_message_channel.sql` (§2.9).
  - `20260610040000_event_dish_servings_editable.sql` (§2.10, only
    if needed after verifying the existing schema).
- The event status derivation (§2.4) can reuse the per-event
  aggregation logic already in the shopping panel. The events list
  fetches event summaries with ingredient state counts and derives
  the status from those counts plus the date.
- The icon swap (§2.2) is operational. Run `dart run
  flutter_launcher_icons` after copying the new PNGs into
  `assets/icon/`. Commit the regenerated icon assets together with
  the source PNGs.
- For the servings rescale logic (§2.10), test the rounding rules
  carefully with edge cases:
  - Whole-number countable ingredients (no unit): round up to next
    integer.
  - Measured ingredients (with unit): round up to 2 sig figs.
  - Zero or negative servings: not allowed; servings field must
    enforce a positive integer.
- For the keyboard fix (§2.11), audit at least these screens:
  - Add/edit dish (catalog).
  - Add/edit ingredient (catalog and per-event).
  - Add/edit event.
  - Settings > Missatges (signature edit).
  - Settings > Proveïdors > category detail (now with the new "Nom"
    field).
- Stop and ask the project owner if any ambiguity arises,
  particularly around the catalog-level supplier category
  override (§2.5) and the ad-hoc ingredient reference servings
  (§2.10).
- The PR description should reference each of the eleven items by
  its §2.x number, with a short summary and a checkbox state.
