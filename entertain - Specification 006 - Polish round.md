# Specification 006 — Polish round

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read `CLAUDE.md`, `entertain - Data model.md`, `entertain - Design system.md`,
> and the relevant prior Specifications before starting. This Spec is a polish
> round between Specifications 005 and the upcoming UI reorganisation +
> ingredient-state work (which will become Specification 007). It picks up
> small, well-defined improvements that accumulated during the validation of
> earlier Specs and that the project owner wants resolved before the app
> enters real-world use.

---

## 1. Goal

After completing the Spec 005 cycle (shopping lists and supplier messages
with two rounds of fixes), several small improvements have surfaced —
either from on-device validation, from observed friction in real use cases,
or from gaps in the data model that became visible only when downstream
functionality was implemented. This Spec gathers them into a single
coherent round, before the project moves on to bigger structural work.

The five improvements are:

1. A new **preparation** field on dishes (multi-line, separate from the
   existing short description).
2. **Ad-hoc ingredient lines** on the per-event dish detail, with an
   option to promote the line to the catalog recipe.
3. **Comma-less rendering** for countable ingredients without a unit
   ("3 ous", not "3 de ous").
4. **Default preparation cascade** from ingredient → dish line → event
   line, so the editor pre-fills the lower level with the level-up value.
5. **Date / time field width rebalancing** on the event detail header,
   to prevent the date from wrapping when displayed in long format.

---

## 2. Scope — what to do

### 2.1 New `preparation` field on dishes

**Observed**: there is no field on the dish model for the actual recipe —
the instructions for how to prepare the dish. The existing `description`
field on `dishes` is short (a subtitle, a one-liner) and is unsuited for
multi-line cooking instructions.

**Fix**: add a new column `preparation` (text, nullable, free format) to
the `dishes` table via migration. The column is **separate from
`description`**, which stays as a one-line short text. Conceptually:

- `description` — a one-line subtitle / brief identification of the dish.
- `preparation` — the multi-line recipe / cooking instructions.

The dish editor exposes both fields: `description` as a single-line text
input (as it is today), and `preparation` as a multi-line text input
below it (or wherever the design system suggests for long-form text in
forms).

The dish detail (both in the catalog and when opened from inside an
event's menu) shows both: the description as a subtitle below the title,
and the preparation as a longer block further down the screen.

The `preparation` field is **not** copied to `event_dishes` on add-to-menu.
The per-event dish detail reads it from the current state of the catalog
dish (via `source_dish_id`). This is intentional: the recipe is the same
thing whatever event uses it, and the user expects to always see the
latest version of the recipe when cooking.

### 2.2 Ad-hoc ingredient lines on the per-event dish detail

**Observed**: the per-event dish detail screen allows editing or
removing existing ingredient lines, but does **not** allow adding new
lines ad-hoc. To add an ingredient to a specific event's version of a
dish, the user currently has to edit the catalog recipe, remove the dish
from the menu, and re-add it — which forces unwanted changes to the
catalog recipe and loses any per-event overrides on the other lines.

**Fix**: add an "Afegeix ingredient" action to the per-event dish detail
screen. The action opens the existing ingredient line editor (the same
one already used elsewhere), operating on `event_dish_ingredients` of
this `event_dish`. The new line is added directly to the event's copy.

Before saving, the line editor presents a checkbox:

> ☐ **Afegir aquesta línia també a la recepta original**

- If **unchecked** (default): the line is added only to
  `event_dish_ingredients`. The catalog recipe is unaffected. Removing
  and re-adding the dish to this or any other event will not include
  this line.
- If **checked**: the line is added both to `event_dish_ingredients`
  (for this event) **and** to `dish_ingredients` (for the catalog recipe
  pointed to by `event_dishes.source_dish_id`). Future events using this
  dish will include the line.

The checkbox defaults to unchecked. The wording should make it clear
that the catalog change is irreversible from this flow (the user must
edit the catalog directly to undo it later).

### 2.3 Comma-less rendering for countable ingredients without a unit

**Observed**: when an ingredient has no unit (a countable item like
eggs, lemons, or pieces of bread), the message composer renders the
line as `<qty> de <ingredient>`, producing awkward Catalan such as
"3 de ous" instead of the natural "3 ous".

**Fix**: in the message composer, when the unit of an ingredient line is
null or empty, omit the "de" preposition. The line is rendered as:

> `<qty> <ingredient>`

instead of

> `<qty> de <ingredient>`

Examples:
- `3 ous` (no unit) — not `3 de ous`.
- `2 llimones, tallades a rodanxes` (no unit, with prep_note) — not
  `2 de llimones, tallades a rodanxes`.
- `250 g de tonyina, tallada a daus petits` (with unit, unchanged).

The prep_note clause and the comma before it are unaffected — they
remain whenever `prep_note` is non-empty, regardless of whether there is
a unit.

### 2.4 Default preparation cascade

**Observed**: the data model anticipates a cascade of preparation notes:

- `ingredients.prep_description` — the default preparation for this
  ingredient ("how this ingredient is normally prepared").
- `dish_ingredients.prep_note` — override for this dish.
- `event_dish_ingredients.prep_note` — override for this event-dish-line.

In practice, the editors treat each level as independent: when adding an
ingredient line, the editor starts with an empty `prep_note` field
instead of pre-filling it with the ingredient's `prep_description` (or
the corresponding `dish_ingredients.prep_note` when editing an
event-dish-line). The user has to retype the same preparation note for
every dish that uses the same ingredient in the same way.

**Fix**: when the ingredient line editor opens for a **new** line (no
prep_note set yet), pre-fill the `prep_note` field with the level-above
value if any:

- For a new `dish_ingredients` line (catalog dish editor): pre-fill with
  the chosen ingredient's `prep_description`.
- For a new `event_dish_ingredients` line (per-event dish detail):
  pre-fill with the corresponding `dish_ingredients.prep_note` if the
  line is being added from the catalog dish (which has a source line);
  if the line is fully ad-hoc (no source line in `dish_ingredients`),
  pre-fill with the ingredient's `prep_description` instead.

The pre-fill is **editable**: the user can change or clear it. Once the
user saves the line, the explicit value (including empty) is what is
stored, regardless of the default.

When the editor opens for an **existing** line, the stored value is
shown as-is (no cascade applied).

This pattern keeps the level-above defaults as a convenience but
respects explicit user choice at every level.

### 2.5 Date / time field width rebalancing on the event detail header

**Observed**: on the event detail screen, the header shows the event
date and time side by side. The date is rendered in long Catalan format
("13 de juny de 2026") and does not fit on a single line when the two
fields share equal width; it wraps to two lines. Meanwhile, the time
field ("21:00") has more space than it needs.

**Fix**: rebalance the relative widths of the date and time fields on
the event detail header. The date should have enough width for the long
format on a single line (no wrap); the time should be narrower. A
proportion of approximately 2:1 or 3:1 (date:time) is a reasonable
starting point, but the implementer should verify that the long date
fits on a single line on the standard device width.

This is the same fix already applied earlier to the event form (Spec
003 polish round); the bug recurred on the event detail header because
that surface uses a different layout.

---

## 3. Out of scope

Explicitly **not** part of this assignment (deferred to later
iterations, captured in the running list of project pendings):

- UI reorganisation of the event detail screen (tabs Event / Menu /
  Shopping / Ingredients) and of Settings (tabs General / Suppliers /
  Messages). These will be tackled in Specification 007.
- The ingredient state machine (received / missing / at home / pending
  / ordered) and the per-event summary panel. Also Specification 007.
- Admin screen to add / edit / delete supplier categories. Will be part
  of Specification 007 alongside the Settings reorganisation.
- Contact picker integration for the WhatsApp / email address field.
- Label / display name on per-category messaging configuration.
- Greeting Catalan elision (`de` → `d'` before vowels). The §2.3 fix is
  about avoiding "de" entirely when the unit is null; the contraction
  before vowels remains untreated for now.
- Photos for dishes and ingredients. Phase 1.

---

## 4. Acceptance criteria

The assignment is complete when the project owner can verify all of the
following on the Android device:

1. The dish editor (in the catalog and visible when editing a dish
   accessible from the catalog) has both a short single-line
   "Descripció" field and a long multi-line "Preparació" field. Both
   persist correctly across app restarts.
2. The dish detail (in the catalog and inside an event's menu) shows
   the description as a subtitle and the preparation as a longer block.
3. From the per-event dish detail, the user can add a new ingredient
   line ad-hoc. A checkbox in the line editor offers to also add the
   line to the catalog recipe. When unchecked, the catalog is
   unaffected; when checked, the line appears in the catalog recipe and
   in any future event that adds this dish.
4. The supplier message renders countable ingredient lines without the
   "de" preposition when the unit is null ("3 ous", not "3 de ous").
   Lines with units are unchanged.
5. When adding a new ingredient line to a dish (catalog or per-event),
   the prep_note field is pre-filled with the level-above default if
   any, and is editable. Existing lines show their stored value.
6. The event detail header displays the date in long Catalan format on
   a single line, with the time field correctly sized next to it. The
   date does not wrap.
7. All affected screens follow the design system and have no hardcoded
   user-facing strings.
8. The work is on a feature branch with a pull request against `main`,
   leaving `main` shippable, per `CLAUDE.md`.

---

## 5. Notes for the implementer

- This Spec gathers five independent improvements; they touch different
  parts of the app and have no logical sequencing constraints between
  them. Implement them in whatever order is cleanest.
- The migration for §2.1 is a simple `ALTER TABLE dishes ADD COLUMN
  preparation TEXT NULL`. No data migration is needed because the
  column is new and the existing `description` column is preserved
  unchanged.
- The checkbox in §2.2 is the only behavioural decision that introduces
  a path between the per-event view and the catalog. Make sure the
  catalog write happens only on save and only when the checkbox is
  checked; do not pre-emptively write to the catalog as a side-effect.
- The cascade in §2.4 is a pre-fill in the editor only; nothing changes
  in how the data is stored. Each level retains its own explicit value.
- The PR description should describe each of the five improvements
  briefly, with the corresponding acceptance criterion.
