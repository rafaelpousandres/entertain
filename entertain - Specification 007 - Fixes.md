# Specification 007 — Fixes (post-validation)

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read `CLAUDE.md`, `entertain - Data model.md`, `entertain - Design system.md`,
> and the original `entertain - Specification 007 - MVP finish.md` before
> starting. This document is a follow-up to Specification 007 after on-device
> validation of both Phase 7A and Phase 7B; it lists five issues that
> surfaced during validation and that must be fixed before the MVP can be
> considered complete and the PR merged.

---

## 1. Goal

Specification 007 was implemented and validated in two phases. Phase 7A
(UI reorganisation, supplier category admin) and Phase 7B (ingredient
state machine, unified shopping panel) both pass their acceptance
criteria. However, on-device validation surfaced five issues that this
round corrects before merging the MVP.

The five issues are:

1. Supplier categories should store **both** a phone number and an
   email address, with the channel selector indicating which one is
   used by default.
2. The per-supplier section header in the shopping panel shows a
   summary that is visually redundant with the per-state sub-group
   headers.
3. The manual state transition matrix for ingredients **outside** the
   Rebost category is too restrictive; the user cannot correct
   classification errors freely.
4. The Rebost category needs a simpler, more focused state model
   ("A casa" / "Falta") that matches the project owner's real mental
   model for a household pantry.
5. Changing an ingredient line's category to or from Rebost (via
   per-event override) does not adjust the line's state
   automatically.

---

## 2. Scope — what to fix

### 2.1 Phone and email as separate fields on supplier categories

**Observed**: each supplier category currently stores one `address`
field whose meaning depends on the selected channel (WhatsApp →
phone, Email → email address). This forces the user to pick one or
the other: there is no way to record both for the same category.

**Fix**: extend the supplier category configuration so that **both**
a phone number and an email address can be stored, with the channel
selector indicating which is the default for outgoing messages.

Concretely:

- Replace (or augment) the `channel_address` column in
  `group_supplier_settings` with two columns: `phone_address` (text,
  nullable) and `email_address` (text, nullable).
- The `channel` column continues to indicate the **default** channel
  for this category. The composer picks the address corresponding to
  the default channel.
- At the supplier category detail screen, show both fields: "Telèfon"
  and "Correu electrònic", plus a "Canal preferent" selector
  (WhatsApp / Email / Cap). The relevant address field is highlighted
  or marked as the default; the other is editable but secondary.
- When the user presses **Envia missatge** in the shopping panel, the
  default channel and its address are pre-selected. The supplier
  message screen lets the user **change the channel** before sending
  (an explicit selector or a small action), and if changed, uses the
  other address.

Migration steps:
- Add `phone_address` and `email_address` columns to
  `group_supplier_settings`.
- Migrate existing rows: copy `channel_address` to `phone_address` or
  `email_address` based on the current `channel` value.
- Optional: drop `channel_address` after migration. If keeping it
  for safety is simpler, mark it as deprecated and stop writing to
  it.

Apply the migration to the remote Supabase project with
`supabase db push`.

### 2.2 Remove redundant summary from supplier section header

**Observed**: in the shopping panel (Compra tab), each supplier
section currently has two layers of summary information:

- The section header shows a per-category count summary (e.g.
  "Fruiteria · 2 per demanar").
- The sub-group headers within the section repeat the same data per
  state (e.g. "Per demanar · 2").

When all ingredients in a category are in the same state — which is
the common case — these two summaries say exactly the same thing,
creating visual redundancy and noise.

**Fix**: remove the aggregate summary from the supplier section
header. The section header shows only the supplier name (and any
relevant indicators, e.g. configured channel/address icon if any).
All quantitative information lives in the per-state sub-group
headers inside the section.

The global summary header at the top of the Compra tab is unchanged
— it continues to show event-wide counts.

### 2.3 Free transition matrix for ingredients outside Rebost

**Observed**: the current transition matrix for manual state changes
is restrictive. For example, an ingredient in `to_order` can be moved
to `received` or `missing` but **not** to `ordered`. An ingredient in
`received` cannot be moved back to `ordered`. The user cannot
correct classification errors freely (e.g. accidentally marking as
received, or wanting to manually mark as ordered because the order
was placed through a non-app channel).

**Fix**: for ingredients **whose supplier category is not Rebost**,
allow any manual transition between any two of the four states
`to_order`, `ordered`, `received`, `missing` (excluding transitions
to the same state). The transition popup shows the three other states
as options regardless of the current state.

The automatic transitions (add dish → `to_order`; send message
confirmed → `ordered`) remain unchanged. The user can always
manually override afterwards.

### 2.4 Rebost: simplified two-state model

**Observed**: ingredients in the Rebost category currently expose the
full state machine (five states), but the project owner's real mental
model for a household pantry is binary: either the staple is at home
(default), or it's missing and needs replenishment. The other states
(`to_order`, `ordered`, `received`) do not map onto how the user
thinks about pantry items.

**Fix**: for ingredients **whose supplier category is Rebost**,
restrict the available states to two:

- `at_home` (default for pantry items): the staple is present.
- `missing`: alarm; the staple has run out and needs to be
  replenished.

The transition popup for Rebost items shows only the opposite state
as an option (from `at_home` → offer `missing`; from `missing` →
offer `at_home`).

The Rebost section in the shopping panel:
- Continues to show no "Envia missatge" action.
- Continues to show no "Usa com a llista de la compra" action.
- The "Marca tot com a rebut" bulk action does not apply (no
  `ordered` state for Rebost).
- Sub-group headers within the Rebost section show only the two
  relevant states ("A casa", "Falta") when populated.

The global summary header at the top of the Compra tab continues to
count all states across all categories.

### 2.5 Automatic state adjustment on category change

**Observed**: when the user changes an ingredient line's category to
Rebost (via per-event override at the line editor), the line's state
is not automatically adjusted; it stays in whatever state it had
before (typically `to_order`). The inverse case (changing from Rebost
to another category) has the same issue: the line stays in `at_home`
even though it now needs to be ordered.

**Fix**: when the user changes the `supplier_category_id` of an
`event_dish_ingredients` row via the line editor:

- If the new category is **Rebost** and the current state is
  `to_order`, `ordered`, or `received`, change the state to
  `at_home`. If the current state is `missing`, keep it as `missing`
  (the alarm is still relevant regardless of category).
- If the new category is **not Rebost** (any other category or null)
  and the current state is `at_home`, change the state to
  `to_order`. If the current state is `missing`, keep it as
  `missing`.

The state adjustment happens at save time in the line editor (client
side) or via a trigger on update (database side); the implementer
chooses the cleanest mechanism. The trigger approach is consistent
with the existing default-on-insert trigger from Phase 7B.

---

## 3. Out of scope

Explicitly **not** part of this assignment (deferred to later
iterations, captured in the running list of project pendings):

- Contact picker integration for the phone / email fields.
- A separate "Encarregat" or "Ordered manually" state for items
  ordered through non-app channels. The §2.3 free matrix covers this
  case sufficiently.
- A history view of past orders (currently visible only via the
  supplier message screen).
- Editing supplier category translations from within the app
  (decision Option 4 from Phase 7A stands).
- Photos, cooking schedule, package equivalence, total food
  verification. Phase 1.

---

## 4. Acceptance criteria

The assignment is complete when the project owner can verify all of
the following on the Android device:

1. In the supplier category detail screen, both a "Telèfon" and a
   "Correu electrònic" field are visible and independently editable.
   The "Canal preferent" selector indicates which one is used by
   default. Both values persist correctly.
2. In the shopping panel, sending a message uses the default channel
   and its address. The supplier message screen allows the user to
   switch the channel before sending, in which case the other
   address is used.
3. In the shopping panel, the per-supplier section headers show only
   the supplier name (no aggregate count summary). The per-state
   sub-group headers carry all quantitative information.
4. For an ingredient not in the Rebost category, tapping the line
   offers all three other states as transition options regardless of
   the current state. The user can freely move between `to_order`,
   `ordered`, `received`, and `missing`.
5. For an ingredient in the Rebost category, tapping the line offers
   only the opposite state of the current one (`at_home` ↔
   `missing`). No other states are presented.
6. Changing an ingredient line's category to Rebost automatically
   moves the line to `at_home` (unless it was in `missing`).
   Changing the category away from Rebost automatically moves the
   line to `to_order` (unless it was in `missing`).
7. All existing flows (add dish to menu, send supplier message,
   confirm dispatch, multi-order delta, manual state transitions for
   non-Rebost, bulk "Marca tot com a rebut") continue to work
   without regression.
8. All affected screens follow the design system and have no
   hardcoded user-facing strings.
9. The work is committed to the existing `feat/spec-007-mvp-finish`
   branch, on top of the previous Phase 7A and Phase 7B commits.
   The existing PR (against `main`) should reflect these changes.

---

## 5. Notes for the implementer

- §2.1 is the most substantial of the five fixes: it requires a
  schema change, a data migration, UI changes on the category detail
  screen, and a small change to the supplier message flow. Treat it
  as the central piece of this round.
- §2.2 is a small UI cleanup; no model changes.
- §2.3 is a change to the transition options exposed in the popup;
  no model changes.
- §2.4 is a presentation restriction on the Rebost transition
  options; the state column itself still supports all five values
  (for data consistency with the rest of the model), but the UI does
  not surface the irrelevant ones for Rebost items.
- §2.5 is naturally a database trigger (consistent with the existing
  BEFORE INSERT trigger from Phase 7B). A BEFORE UPDATE trigger that
  reads the old and new `supplier_category_id` and adjusts `state`
  accordingly keeps the logic in one place.
- The PR description should be amended to document this round of
  fixes as a third section after Phase 7A and Phase 7B, with the
  nine acceptance criteria listed.
