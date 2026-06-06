# Specification 006 — Fixes (post-validation)

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read `CLAUDE.md`, `entertain - Data model.md`, `entertain - Design system.md`,
> and the original `entertain - Specification 006 - Polish round.md` before
> starting. This document is a follow-up to Specification 006 after on-device
> validation; it lists four small issues that surfaced during the validation
> and that must be fixed before the polish round can be considered complete.

---

## 1. Goal

After validating the original Specification 006 on the Android device,
four issues emerged that need a corrective pass. Two are direct
regressions or imprecisions of the previous round (the date/time width
rebalancing went too far, and the dish editor places the new
"Preparació" field above the ingredients instead of below them). The
other two are linguistic shortcomings of the message composer that
became visible only when a wider range of cases was tested (the unit
"unitats" should be suppressed from the message text, and the Catalan
preposition "de" should contract to "d'" before vowels).

The original Specification 006 stays as the conceptual basis. This Spec
only amends it where validation revealed issues.

---

## 2. Scope — what to fix

### 2.1 Date/time width rebalancing — overcorrected

**Observed**: in the event edit form, the previous fix set the
proportion between the Date field and the Time field to roughly 3:1.
The Date field now has excess space, while the Time field is too narrow
and its content ("21:00") wraps to two lines. The 2:1 proportion of
Specification 003 was insufficient (the long-format date wrapped); the
3:1 of Specification 006 is excessive (the time wraps).

**Fix**: change the layout so that the Time field has an intrinsic
width sized to fit its content (typically the literal "HH:MM" plus a
small margin for the trailing icon if any), and the Date field takes
the remaining horizontal space. This decouples the layout from any
arbitrary proportion and adapts naturally to whatever date format ends
up being displayed.

If an intrinsic layout is not practical for the chosen widget, the
implementer may fall back to a fixed-width Time field and a
flex-expanded Date field. The acceptance criterion is the same: in
real conditions on the device, neither the Date nor the Time wraps.

### 2.2 Preparation field placement in the dish editor

**Observed**: the dish editor places the new "Preparació" multi-line
field **above** the list of ingredient lines. This breaks the natural
reading order for a recipe, which is: dish identification, ingredient
list, then preparation steps. The project owner expects the editor to
present the same order.

**Fix**: in the dish editor screen, move the "Preparació" field so
that it appears **below** the ingredient lines section, after all the
existing ingredient editing UI. The order of sections in the editor
should be:

1. Title
2. Description (one-line subtitle)
3. Category and other metadata (servings, format, etc.)
4. Ingredient lines section (with the "Add ingredient" action)
5. **Preparation** (multi-line text)

The detail view (read-only display of a dish, both in the catalog and
from inside an event's menu) should follow the same order.

### 2.3 Suppress the "unitats" unit in the message composer

**Observed**: when an ingredient line uses the system unit "unitats"
(the generic unit meaning "pieces" or "items"), the message composer
currently renders the line as `<qty> <unit> de <ingredient>` →
"3 unitats de ous". The natural Catalan form for countable items is
"3 ous" (no unit, no preposition).

**Fix**: extend the data model so that a unit may be flagged as
"omitted from display". Concretely:

- Add a column `omit_in_display` (boolean, not null, default false) to
  the `units` table via migration.
- Mark the existing system unit "unitats" (whatever its `code` is —
  likely `unit`, `piece`, `u`, or similar) as `omit_in_display = true`.
- In the message composer, when a line's unit has
  `omit_in_display = true`, render the line as `<qty> <ingredient>`
  (no unit, no "de" preposition). When the unit's flag is false, the
  current behaviour applies (`<qty> <unit> de <ingredient>` or, if no
  unit, `<qty> <ingredient>` per Specification 006 §2.3).
- The `prep_note` clause, when present, is appended as before
  (`, <prep_note>`).

This is a model-level change rather than a special case in the
composer, so future units that should be omitted from display can be
flagged the same way without code changes.

Apply the migration to the remote Supabase project with
`supabase db push`.

### 2.4 Catalan elision "de" → "d'" before vowels

**Observed**: the message composer always uses the literal "de" as the
Catalan preposition between the unit and the ingredient name. When
the ingredient name starts with a vowel or with a silent "h", correct
Catalan requires the elision to "d'" ("d'oli", "d'hostal"). The
current output produces grammatically awkward forms like "200 g de
oli" or "100 g de hortalisses".

**Fix**: in the message composer, add a helper function that applies
the elision rule whenever the "de" preposition is rendered:

- If the next word starts with a vowel (`a`, `e`, `i`, `o`, `u`,
  case-insensitive) or with `h` (silent in Catalan), use `d'` with no
  space between the apostrophe and the next word.
- Otherwise, use `de ` (with a trailing space).

The rule has occasional exceptions in Catalan (aspirated h, some
foreign words), but a simple vowel-or-h test covers the vast majority
of food ingredient names. Edge cases will be addressed if and when
they appear in real use.

Apply this rule consistently: every place in the composer that emits
"de" should go through the helper. After the change, lines should
read "200 g d'oli, 250 g de tonyina, 100 g d'hortalisses".

---

## 3. Out of scope

Explicitly **not** part of this assignment (deferred to later
iterations, captured in the running list of project pendings):

- UI reorganisation of the event detail screen (Specification 007).
- Ingredient state machine and per-event summary panel (Specification
  007).
- Admin screen for supplier categories (Specification 007).
- Contact picker for the WhatsApp / email address field.
- Display label / name on per-category messaging configuration.
- Photos for dishes and ingredients.
- Allowing the creation of ingredients without a unit at all. With
  §2.3 in place, the "unitats" unit covers countable items
  satisfactorily; making the unit optional in the model is not
  necessary.

---

## 4. Acceptance criteria

The assignment is complete when the project owner can verify all of
the following on the Android device:

1. In the event edit form, opening an existing event with a long-format
   date (for example "13 de juny de 2026") displays the date on a
   single line and the time "HH:MM" on a single line, with neither
   wrapping. The relative widths look balanced and the layout adapts
   to different month names without manual tuning.
2. In the dish editor, the "Preparació" multi-line field appears
   **below** the ingredient lines section. The reading order is:
   title → description → metadata → ingredients → preparation. The
   detail view of a dish (catalog and inside an event's menu) follows
   the same order.
3. Sending a supplier message for an ingredient with the "unitats"
   unit produces a line of the form "3 ous", not "3 unitats de ous"
   or "3 unitats d'ous".
4. Sending a supplier message for an ingredient whose name starts with
   a vowel or "h" produces a line with "d'" instead of "de ": for
   example "200 g d'oli", "100 g d'hortalisses". Lines whose
   ingredient name starts with a consonant continue to use "de ":
   "250 g de tonyina".
5. The four changes work together: a real send for an event whose
   menu includes a mix of normal ingredients, countable items, and
   ingredients starting with vowels produces a message that reads as
   naturally written Catalan throughout.
6. All affected screens follow the design system and have no hardcoded
   user-facing strings.
7. The work is committed to the existing `feat/spec-006-polish`
   branch, on top of the previous fixes. The existing PR #11 should
   reflect these changes.

---

## 5. Notes for the implementer

- The four fixes are independent and have no logical dependencies.
  Implement them in whatever order is cleanest.
- §2.3 is the only fix in this round that requires a migration. Apply
  it to the remote project with `supabase db push`.
- §2.4 is a small linguistic helper that should live alongside the
  composer code, not in a separate localisation module. Treat it as
  Catalan-specific Catalan; do not generalise prematurely to other
  languages.
- The PR description for #11 should be amended to mention this round
  of fixes after the original polish round, with the four acceptance
  criteria listed clearly.
