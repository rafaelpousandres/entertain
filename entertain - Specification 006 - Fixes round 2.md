# Specification 006 — Fixes (round 2)

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read `CLAUDE.md`, `entertain - Data model.md`, `entertain - Design system.md`,
> the original `entertain - Specification 006 - Polish round.md`, and the
> first round of fixes `entertain - Specification 006 - Fixes.md` before
> starting. This document is a second round of fixes after on-device
> validation of the first round; it addresses three small issues that
> surfaced when the previous fixes were verified together with a wider set
> of ingredient cases.

---

## 1. Goal

The first round of fixes corrected the date/time width, the preparation
field placement, the "unitats" unit handling, and the Catalan elision
rule. On-device validation of that round revealed three remaining
issues:

1. The Description field is placed in the wrong position in the dish
   editor (currently between "Racions base" and "Ingredients" instead
   of right after "Nom" as a subtitle).
2. The user-facing label of the generic `unit` unit is rendered as
   "unitat" (singular) rather than "unitats" (plural), which is
   unnatural when displayed in a quantity picker.
3. The message composer preserves the catalog capitalisation of
   ingredient names and prep notes ("Anxoves", "En oli d'oliva"),
   producing message text with mid-sentence capitals that does not
   read as natural Catalan prose.

This round corrects all three.

---

## 2. Scope — what to fix

### 2.1 Description field placement in the dish editor

**Observed**: in the dish editor, the order of fields is currently:
Nom → Categoria → Racions base → Descripció → Ingredients → Preparació.
The Description ("Descripció") is acting as a one-line subtitle of the
dish, but it appears far from the title — separated by metadata fields
that are conceptually a different kind of information.

**Fix**: move the "Descripció" field so that it appears **immediately
after "Nom"**, before any of the metadata fields. The order in the
dish editor should be:

1. Nom (title)
2. **Descripció** (one-line subtitle)
3. Categoria
4. Racions base
5. (Other metadata fields, if any)
6. Ingredients section (with the "Afegeix ingredient" action)
7. Preparació (multi-line)

The same order applies to the dish detail (read-only display): title,
description as subtitle, metadata, ingredients, preparation.

### 2.2 Plural label for the generic unit

**Observed**: the system unit with code `unit` is shown to the user as
"unitat" (singular). When the user picks the unit for an ingredient
the natural reading is "3 unitats", not "3 unitat".

**Fix**: update the translations for the `unit` row in the
`translations` table (or wherever the unit display labels are kept) so
that the user-facing label is plural in all three supported locales:

- Catalan: "unitats"
- Spanish: "unidades"
- English: "units"

This is a data-only change (an UPDATE of existing translation rows, or
a small migration that re-seeds them). No code changes are required.
Apply the change to the remote project so the running app reflects it
without a new build.

If the translations are seeded from a SQL migration file in the
repository, update the seed file too, so a fresh database has the
plural form by default.

### 2.3 Message composer — lowercase ingredient names and prep notes

**Observed**: the message composer takes the ingredient name and the
prep note directly from `event_dish_ingredients` and inserts them into
the message text without normalising their case. As a result, lines
like "80 g d'Anxoves, En oli d'oliva" appear with mid-sentence capital
letters, which is not how Catalan prose is written.

**Fix**: in the message composer, when an ingredient name or a prep
note is inserted into a message line, **lowercase the first character**
of each. Keep the rest of the string as it is in the catalog.

Concretely, for every line of the form `<qty> <unit> de <ingredient>,
<prep_note>` (or any of the variants), the function that emits the
line should apply `firstCharToLowercase()` (or equivalent) on the
ingredient name and on the prep_note before concatenating them.

- Result for an ingredient stored as "Anxoves" with prep_note "En oli
  d'oliva": `80 g d'anxoves, en oli d'oliva`.
- Result for "Llimona" with prep_note "Tallada a rodanxes":
  `100 g de llimona, tallada a rodanxes`.
- Result for "Ous" (no unit, no prep_note): `3 ous`.

The rest of the string is preserved as-is: proper nouns or acronyms
that appear in the middle of an ingredient name or a prep note (rare
in practice) would keep their internal capitalisation; only the
**first** character is changed.

The catalog itself is not touched. The user keeps entering ingredient
names in Title Case (`Anxoves`, `Llimona`) for natural reading in
catalog screens. The transformation happens only at message composition
time.

---

## 3. Out of scope

Explicitly **not** part of this assignment (deferred to later
iterations, captured in the running list of project pendings):

- All items already deferred in previous rounds.
- More sophisticated case handling (proper nouns, acronyms, contextual
  rules). The simple "lowercase the first character" rule is sufficient
  for the food-ingredient domain.
- Lowercasing in screens other than the message composer (catalog UI,
  shopping panel, etc. keep their Title Case display).

---

## 4. Acceptance criteria

The assignment is complete when the project owner can verify all of
the following on the Android device:

1. In the dish editor, the "Descripció" field appears immediately after
   "Nom" and before "Categoria". The ordering matches: Nom →
   Descripció → Categoria → Racions base → … → Ingredients →
   Preparació. The detail view follows the same order.
2. When picking the unit for an ingredient, the generic unit (`unit`)
   appears as "unitats" in Catalan, "unidades" in Spanish, "units" in
   English.
3. Sending a supplier message for an event whose menu includes
   ingredients with different starting letters and different
   prep_notes produces lines with **lowercase initial letters** on
   both the ingredient name and the prep_note. Example messages:
   - `80 g d'anxoves, en oli d'oliva`
   - `100 g de llimona, tallada a rodanxes`
   - `3 ous`
   - `250 g de tonyina, tallada a daus petits`
4. The catalog and other UI screens continue to show ingredient names
   and prep notes in their original Title Case (no regression).
5. All affected screens follow the design system and have no
   hardcoded user-facing strings.
6. The work is committed to the existing `feat/spec-006-polish`
   branch, on top of the previous fixes. The existing PR #11 should
   reflect these changes.

---

## 5. Notes for the implementer

- §2.1 is a pure reordering of fields in the editor and the detail
  view; no model changes.
- §2.2 is a data update; verify both the migration file (if any) and
  the rows in the remote project.
- §2.3 is a small string transformation in the composer. Add it as a
  private helper next to the existing `catalanConnector` and apply it
  consistently. Add or extend tests to cover the lowercase behaviour
  on the first character.
- The PR description for #11 should be amended to mention this second
  round of fixes after the first one.
