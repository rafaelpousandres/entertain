# Specification 005 — Fixes (round 2)

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read `CLAUDE.md`, `entertain - Data model.md`, `entertain - Design system.md`,
> the original `entertain - Specification 005 - Shopping lists and supplier
> messages.md`, and the first round of fixes
> `entertain - Specification 005 - Fixes.md` before starting. This document is
> a second round of fixes after on-device validation of the first round; it
> addresses two issues with the supplier message text that surfaced when the
> message format was tested against the project owner's real use case
> (sending shopping orders to suppliers in the style he was already using
> manually before the app existed).

---

## 1. Goal

The first round of fixes corrected the message text by removing private
event information (event title, event date) and adding the needed-by date.
That made the text more privacy-aware and operationally useful, but
on-device validation revealed two remaining shortcomings:

1. The message has no greeting at all. It opens directly with the
   needed-by date line, which feels abrupt for the recipient and is not
   how the project owner used to phrase his real WhatsApp orders to
   suppliers.
2. The per-line ingredient preparation note (`prep_note`) does not appear
   in the message text. The project owner's real WhatsApp orders to
   suppliers included this preparation explicitly ("250 g de tonyina
   tallada a daus petits", "400 g de bacallà esmicolat"), because the
   preparation is sometimes done by the supplier before delivery and is
   part of the actual order, not just internal information for the cook.

This round corrects both shortcomings.

---

## 2. Scope — what to fix

### 2.1 Configurable greeting in Settings

**Observed**: the message body starts directly with the needed-by date
line, with no greeting. The Settings screen currently lets the user
configure a signature for outgoing messages, but no greeting.

**Fix**: extend the Settings screen with a new single-line text field
**"Salutació"** (greeting), placed adjacent to or just above the existing
**"Signatura"** field. The greeting is appended at the **very beginning**
of every outgoing message, on its own line, with a blank line separating
it from the rest of the body.

- The greeting defaults to **"Hola,"** in Catalan on first run if not
  set. The user can edit or clear it.
- If the greeting is empty (the user clears it), no greeting line is
  inserted; the message starts with the date line as before.
- The greeting field follows the same persistence pattern as the
  signature (currently group-scoped via `groups.signature`; add a
  parallel `groups.greeting` column via migration, or place the greeting
  on the appropriate row at the implementer's discretion, consistently
  with how the signature is stored).

### 2.2 Preparation notes included per ingredient line in the message

**Observed**: the message currently renders each ingredient line as
`<quantity> <unit> <ingredient_name>` (for example, "250 g Tonyina"). The
per-line `prep_note` is omitted entirely. The recipient supplier therefore
has no information about how the ingredient should arrive prepared, which
is often part of the order in the project owner's real practice.

**Fix**: when composing the message text, each ingredient line includes
its `prep_note` (snapshot value from `event_dish_ingredients`) if the
note is not empty. The line is rendered on a single line, in the form:

> `<quantity> <unit> de <ingredient_name>, <prep_note>`

For example: `250 g de tonyina, tallada a daus petits`.

If `prep_note` is empty, the line is rendered without the trailing
clause:

> `<quantity> <unit> de <ingredient_name>`

For example: `250 g de bacallà dessalat`.

Notes:
- The `de` before the ingredient name is the Catalan preposition; do not
  apply elision rules (it stays `de` even before vowels — `de oli`, not
  `d'oli`) for this iteration. A future polish round may add proper
  Catalan contraction handling.
- The first character of the `prep_note` is **not** changed; it is
  rendered as the user wrote it (lowercase or capitalised as it was
  entered).
- If at some point in the future the project owner wants
  ingredient-defaults for prep notes (the cascade
  `ingredient.prep_description → dish_ingredient.prep_note →
  event_dish_ingredient.prep_note`), that work is a separate iteration
  and is **out of scope here**. For this round, we use the existing
  snapshot value on `event_dish_ingredients` as-is.

---

## 3. Out of scope

Explicitly **not** part of this assignment (deferred to later iterations,
captured in the running list of project pendings):

- All items already deferred in the first round of fixes.
- Cascade behaviour of `prep_note` from `ingredients.prep_description`
  through `dish_ingredients.prep_note` down to
  `event_dish_ingredients.prep_note`.
- Catalan contraction handling (`de` → `d'` before vowels).
- Allowing ad-hoc ingredient lines on the per-event dish detail.
- UI reorganisation of the event detail screen and Settings.

These will continue to be tackled separately.

---

## 4. Acceptance criteria

The assignment is complete when the project owner can verify all of the
following on the Android device:

1. The Settings screen has a new "Salutació" (greeting) text field,
   placed near the existing "Signatura" field. It accepts free text and
   persists across app restarts.
2. By default on first run, the greeting is "Hola,"; the user can edit
   or clear it freely.
3. Sending a supplier message produces a body that starts with the
   greeting on its own line, followed by a blank line, then the
   needed-by date line, then the items, then a blank line, then the
   signature. When the greeting is empty, the body starts directly with
   the needed-by date line.
4. Each ingredient line in the message text includes its `prep_note` if
   the note is non-empty, in the form `<quantity> <unit> de <ingredient>,
   <prep_note>`. If the `prep_note` is empty, the line is rendered
   without the trailing clause.
5. The two changes work together: a real send for an event with several
   ingredients, some with prep notes and some without, produces a
   message that reads naturally and matches the project owner's
   pre-existing WhatsApp practice for ordering from suppliers.
6. All affected screens follow the design system and have no hardcoded
   user-facing strings.
7. The work is committed to the existing `feat/spec-005-shopping-and-messages`
   branch, on top of the previous fixes. The existing PR #7 against
   `main` should reflect these changes.

---

## 5. Notes for the implementer

- These are two small, focused changes within the message composer and
  the Settings screen. They should not require any reorganisation or
  refactor of the existing flow.
- The first change (§2.1) adds a column to the same row that holds the
  signature; treat the two fields as a coherent pair.
- The second change (§2.2) is purely formatting; the data is already
  there in `event_dish_ingredients.prep_note`. Just include it.
- The PR description should be amended to mention this second round of
  fixes after the first round, with its own acceptance criteria
  listed clearly.
