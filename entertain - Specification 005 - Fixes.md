# Specification 005 — Fixes (post-validation)

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read `CLAUDE.md`, `entertain - Data model.md`, `entertain - Design system.md`,
> and the original `entertain - Specification 005 - Shopping lists and supplier
> messages.md` before starting. This document is a follow-up to Specification
> 005 after on-device validation; it lists the bugs and functional gaps that
> must be fixed before the shopping list and messaging flow can be considered
> usable.

---

## 1. Goal

After validating the original Specification 005 on the Android device, seven
issues emerged that prevent the shopping list and supplier messaging flow from
being trustworthy in real use. Some are bugs (the user interface or the data
flow does not behave as the original Spec required); others are functional
gaps that the original Spec did not anticipate but that practical use has
made clearly necessary. This Spec corrects them.

The original Specification 005 stays as the conceptual basis. This Spec only
amends it where validation revealed issues.

---

## 2. Scope — what to fix

### 2.1 Bug — shopping panel does not refresh after menu edits

**Observed**: after editing the event menu (removing a dish from the menu,
editing the dish in the catalog, re-adding it to the menu, adding new
ingredients to the dish at the catalog), the event shopping panel does not
reflect the changes. The user sees stale data from the previous state, even
after navigating away from the panel and back to it. Only a full cold start
of the app loads the current state.

**Fix**: ensure the shopping panel reads its data reactively from the source
of truth at the moment the panel is shown, or that the relevant Riverpod
providers are invalidated when the underlying data changes. The mechanism is
the implementer's choice; what matters is that the user sees the current
state of `event_dish_ingredients` for the event every time they enter the
shopping panel, without requiring an app restart.

### 2.2 Bug — duplicated event_dish_ingredients rows when re-adding a dish

**Observed**: when the user removes a dish from the event menu and re-adds
it, the underlying `event_dish_ingredients` rows are not always cleaned up,
producing duplicate copies of the same ingredient line. Direct inspection
of the database via SQL Editor showed two copies of the same ingredient
after a remove-and-re-add cycle.

**Fix**: removing a dish from the event menu must physically delete the
corresponding `event_dishes` row **and** all its `event_dish_ingredients`
rows (cascade was specified at the model level; verify it is in fact
applied). If the cascade is not configured at the database level, add it as
a migration; if it is configured but not effective, identify the actual
cause (an `on delete restrict` somewhere, an application-level delete that
does not cascade, a transactional issue) and fix it. Verify with a
reproducible test: remove-and-re-add a dish, check the row count after each
operation matches expectations.

### 2.3 Bug — copy-on-add does not include catalog edits made after the original add

**Observed**: when the user removes a dish from the event menu, edits the
dish in the catalog (adds a new ingredient line to the recipe), and re-adds
the dish to the menu, the new ingredient line is **not** copied to
`event_dish_ingredients`. Only the lines that existed at the original
add-time appear.

**Fix**: investigate why the second add does not snapshot the current state
of `dish_ingredients`. The copy-on-add logic should always read the current
state of the catalog (`dishes` and `dish_ingredients`) at the moment of
addition; the snapshot is the picture of "right now", not "back then". If
caching, stale queries, or a hidden source of truth is interfering, find it
and remove it.

### 2.4 Bug — shopping panel hides ingredients without a supplier category

**Observed**: ingredients in the event menu whose `supplier_category_id` is
null do not appear in the shopping panel at all. The user has no way to
know that these ingredients exist or need attention. This is critical: the
shopping panel is the radar of "what do I need for this event"; hiding data
defeats its purpose.

**Fix**: extend the shopping panel to include a dedicated section for
ingredients without an effective `supplier_category_id`. The section is
consultive (no send action, similar to the pantry section in spirit), with
a clear label such as "Sense categoria" / "Sin categoría" / "Uncategorised"
and an explicit hint that the user should assign a category to these
ingredients to manage them properly. The section appears only when there
is at least one such ingredient; otherwise it is omitted.

### 2.5 Functional gap — message text leaks event information and lacks the needed-by date

**Observed**: the message sent to a supplier includes the event title and
the event date in its header. Both are private information that the user
does not want to share with the supplier (the supplier does not need to
know what the event is or when it is). On the other hand, the message
does **not** include the date by which the user needs the goods, which is
the only date that matters to the supplier.

**Fix**: rewrite the message text composer so that:
- The event title is **not** in the message.
- The event date is **not** in the message.
- A new field, "Data de necessitat" (when the user needs the goods), is
  added to the supplier message screen as an editable field, defaulting to
  the day before the event date if known, otherwise empty. The user can
  edit this date before sending.
- The needed-by date is included in the message as a natural sentence in
  Catalan, such as "Per al dia 5 de juny" or "Necessari per al 5 de juny".
- The rest of the message stays as before: greeting with the user's name
  (from the signature), the list of items as `<quantity> <unit> <ingredient name>`, signature at the end.

The result should be a message that is functional for the supplier
(identifies who is ordering, when it is needed, and what is needed) and
respects the user's privacy (does not reveal the event's purpose or date).

### 2.6 Functional gap — needed-by date field on orders

**Observed**: there is no field on `orders` to persist the user's chosen
needed-by date.

**Fix**: add a `needed_by_date` (date, nullable) column to the `orders`
table via migration. Apply the migration to the remote project. The
supplier message screen sets this value when the user picks the date, and
the value is included in the message text (see §2.5).

### 2.7 Functional gap — send marking is too optimistic

**Observed**: the app marks an order as sent (`sent_at = now()`) as soon
as the external channel (WhatsApp, email, share sheet) is opened. The app
does not know whether the user actually sent the message in the external
app, whether the destination was valid, or whether the channel succeeded
at all. In testing, an invalid WhatsApp number resulted in the order being
marked as sent even though no message ever left the device.

**Fix**: after the external channel is opened, the app returns the user
to a confirmation step: a small dialog or screen asking "Has enviat el
missatge correctament?" / "¿Enviaste el mensaje correctamente?" / "Did
you send the message?" with two clear options:
- **Yes**: the order is marked as sent (`sent_at = now()`, plus the
  channel and address metadata).
- **No**: the order is not marked as sent. The user can retry later from
  the shopping panel.

If the channel cannot be opened at all (no WhatsApp installed, no email
client configured, share sheet cancelled), the confirmation step is
skipped and the order remains unsent.

This is the only reliable way for the app to know whether the message
actually went out, given that no consumer messaging platform provides a
reliable callback when the user confirms a send.

---

## 3. Out of scope

Explicitly **not** part of this assignment (deferred to later iterations,
captured in the running list of project pendings):
- Admin screen to add / edit / delete supplier categories.
- Contact picker integration for the address field.
- Name / label field on per-category messaging configuration.
- Allowing ad-hoc ingredient lines on the per-event dish detail (the case
  where a user wants to add an ingredient to the event copy without
  editing the catalog dish).
- UI reorganisation of the event detail screen (tabs Event / Menu /
  Shopping) and of Settings (tabs General / Suppliers / Messages).

These will be tackled separately after the Spec 005 fixes are merged.

---

## 4. Acceptance criteria

The assignment is complete when the project owner can verify all of the
following on the Android device:

1. After editing the event menu in any way (adding a dish, removing a dish,
   editing a dish in the catalog, adding ingredients to a dish), the
   shopping panel for the event reflects the current state without an app
   restart.
2. Removing a dish from the event menu deletes both the `event_dishes`
   row and all corresponding `event_dish_ingredients` rows; no orphan or
   duplicate rows remain. Verified by direct SQL query.
3. Re-adding a dish that was previously removed copies the **current**
   state of the catalog dish, including any ingredient lines added since
   the original add.
4. Ingredients in the menu whose `supplier_category_id` is null appear in
   the shopping panel under a dedicated "Sense categoria" section, with
   no send action and a hint about assigning a category.
5. The supplier message composed for sending does not include the event
   title or the event date.
6. The supplier message screen lets the user pick a needed-by date,
   persisted on the order as `needed_by_date`. The date appears naturally
   in the message text.
7. After invoking the external channel (WhatsApp, email, share sheet) for
   a send, the app asks the user whether the send was successful, and
   only marks the order as sent if the user confirms yes. A "no" answer
   leaves the order in the unsent state, available for retry.
8. All affected screens follow the design system and have no hardcoded
   user-facing strings.
9. The work is on a feature branch with a pull request against `main`,
   leaving `main` shippable, per `CLAUDE.md`.

---

## 5. Notes for the implementer

- These fixes are corrections to Specification 005, not new features.
  Where the original Spec is in tension with the fixes, the fixes here
  take precedence.
- The four bugs (§2.1 to §2.4) are not independent: §2.1, §2.2, and §2.3
  all touch the data flow around the menu and the per-event ingredient
  snapshots. Investigate them together; a single root cause may explain
  more than one symptom.
- The functional gaps (§2.5, §2.6, §2.7) are interdependent in a
  different way: §2.5 needs the data plumbing of §2.6, and §2.5 also
  needs §2.7 to make the send experience trustworthy. Implement them as
  a coherent set rather than as isolated changes.
- The PR description should list the seven fixes explicitly and describe,
  for each one, what was identified as the root cause and how it was
  resolved. This is the record we will refer to if any of these issues
  re-emerges later.
- Keep scope strict. The deferred items in §3 are not for this
  assignment; if they tempt you while you are inside the relevant code,
  resist and leave them for their own iterations.
