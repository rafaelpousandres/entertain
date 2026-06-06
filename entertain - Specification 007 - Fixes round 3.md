# Specification 007 — Fixes (round 3)

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read `CLAUDE.md`, `entertain - Data model.md`, `entertain - Design system.md`,
> the original `entertain - Specification 007 - MVP finish.md`, and the
> previous two rounds of fixes (`entertain - Specification 007 - Fixes.md`
> and `entertain - Specification 007 - Fixes round 2.md`) before starting.
> This document is a third round of fixes after on-device validation of
> the second round; it gathers three small improvements that emerged when
> exercising the new shopping panel and the channel preferent selector.

---

## 1. Goal

The second round of fixes corrected the colour palette, introduced the
derived "Retrassat" state, added "Compartir" as a channel preferent,
paired address fields with their channels, and reordered the supplier
sections. All five passed on-device validation.

Three further improvements emerged from the validation:

1. The order of states in the global summary header and in the
   per-supplier sub-groups should follow a clear concern-decreasing
   pattern (most urgent first, most settled last).
2. The channel preferent selector currently shows truncated text on
   narrow widths (e.g. "What…" / "Corre…"). Icons solve the problem
   universally and read faster.
3. The "Usa com a llista de la compra" action currently only sets a
   semantic marker ("Ho compraràs en persona") without generating any
   useful list output. It should produce a plain text list, copy it
   to the clipboard, and move the relevant lines to `ordered` so the
   state machine reflects what is happening.

This round corrects all three.

---

## 2. Scope — what to fix

### 2.1 State ordering in summary header and sub-groups

**Observed**: the global summary header at the top of the Compra tab
currently lists state counts in the order: A casa · Per demanar ·
Demanat · Retrassat · Rebut · Falta (or similar). The per-supplier
sub-groups within each section follow a similar non-prioritised
order. This mixes "I don't have it" with "I have it" without a clear
visual hierarchy, and forces the user to scan all six counts to find
the urgent ones.

**Fix**: reorder the state counts in the global summary header and
the per-state sub-group headers within each supplier section to
follow this **concern-decreasing** order:

1. **Per demanar** (red)
2. **Falta** (red)
3. **Retrassat** (orange)
4. **Demanat** (yellow)
5. **Rebut** (green)
6. **A casa** (green)

Reading left to right (or top to bottom): from the most urgent
(needs planning / has failed) to the most settled (already at home).
The colour gradient reinforces the visual hierarchy: reds first,
orange, yellow, greens last.

This ordering applies to:

- The global summary header at the top of the Compra tab.
- The per-state sub-group headers within each supplier section.

States that have zero lines in a given section continue to be
omitted (as already implemented), so the order is implicit: only the
states with at least one line are shown, in this canonical order.

### 2.2 Channel preferent selector with icons instead of text

**Observed**: the channel preferent selector currently uses text
labels (WhatsApp / Correu / Compartir / Cap). On the device, the
labels are truncated to "What…" / "Corre…" / "Comp…" / "Cap" because
the layout does not give enough room for the full text. The user
can tell what each option means only by deduction from position.

**Fix**: replace the text labels with **icons** that are universally
recognisable:

- **WhatsApp**: an icon that clearly evokes WhatsApp (the official
  logo if available via a package like `font_awesome_flutter`; if
  not, a chat-bubble icon like `Icons.chat_bubble_outline` is
  acceptable).
- **Correu**: a mail / envelope icon (`Icons.email_outlined` or
  similar).
- **Compartir**: a share icon (`Icons.share_outlined` or similar).
- **Cap**: a neutral "none" icon (`Icons.block` or
  `Icons.do_not_disturb_alt`), or the literal text "Cap" if no
  icon reads cleanly as "no channel".

The icons should be sized to be tappable and visually balanced
within the radio row. A small text tooltip on long-press (Android
default behaviour with `Tooltip` widget) is welcome but not
required.

This change applies wherever the channel selector appears:

- The supplier category detail screen (under Settings > Proveïdors).
- The override widget on the supplier message screen (when the user
  changes the channel just before sending).

If the design system has a recommended icon set for channels, use
it consistently with the rest of the app.

### 2.3 "Usa com a llista de la compra" — functional output

**Observed**: the action "Usa com a llista de la compra" currently
only shows the message "Ho compraràs en persona" and changes the
button icon from cart to check, without producing any useful output.
The state of the relevant ingredient lines is not updated. The user
gets a semantic marker but no actual list of what to buy.

**Fix**: implement the action so that:

1. The action **generates a plain text list** of the ingredients
   currently in `to_order` state for this supplier section. The
   text uses the same line format as the supplier message
   (`<qty> <unit> de <ingredient>, <prep_note>`), with Catalan
   elision rules and the unit-suppression for the `unit` system
   unit applied. It does **not** include greeting, needed-by date,
   or signature — those are message-specific.

   Example output for Verduleria with three items in `to_order`:

   ```
   100 g de llimona, tallada a rodanxes
   3 ous
   2 cebes, picades
   ```

2. The text is **copied to the device clipboard** automatically.

3. A **toast / SnackBar** confirms the action: "Llista copiada al
   porta-retalls" / "Lista copiada al portapapeles" / "List copied
   to clipboard".

4. The relevant ingredient lines (all the ones that were in
   `to_order` and contributed to the list) **move to `ordered`
   state** automatically, just as if they had been sent via the
   supplier message flow. Their per-line state indicator updates
   to the yellow `ordered` colour and they move into the "Demanat"
   sub-group within the section.

The button icon may continue to change (cart → check) as a visual
confirmation, but the textual message "Ho compraràs en persona" is
replaced with the toast above.

The implication is that the user takes the clipboard text to their
notes app, WhatsApp, paper, or wherever, and walks to the
supermarket with it. When they return with the purchases, the
existing **"Marca tot com a rebut"** bulk action (already
implemented for `ordered` lines) moves everything to `received`.

If, in the future, "Compra personal" needs to be distinguishable
from "Comanda al proveïdor" for analytic purposes, a new column on
`event_dish_ingredients` could record the dispatch channel. For
this round, both look identical at the state level — `ordered` is
`ordered`, regardless of how it got there.

---

## 3. Out of scope

Explicitly **not** part of this assignment (deferred to later
iterations, captured in the running list of project pendings):

- All items already deferred in previous rounds.
- Distinguishing "Comprat personalment" from "Demanat al proveïdor"
  as a separate state or sub-state.
- Custom icons or colours for individual supplier categories.
- A dedicated history view showing past purchases with timestamps.
- Sharing the generated shopping list via the OS share sheet (as an
  alternative to clipboard copy). The clipboard approach is the
  primary path for this round; share sheet may be added later if
  needed.

---

## 4. Acceptance criteria

The assignment is complete when the project owner can verify all of
the following on the Android device:

1. In the global summary header at the top of the Compra tab, state
   counts appear in the order: Per demanar · Falta · Retrassat ·
   Demanat · Rebut · A casa. States with zero count for the event
   are omitted.
2. Within each supplier section, per-state sub-group headers appear
   in the same canonical order: Per demanar, Falta, Retrassat,
   Demanat, Rebut, A casa. Empty sub-groups are omitted.
3. The channel preferent selector in the supplier category detail
   screen uses icons for each option (WhatsApp / mail / share / no
   channel). All four options are recognisable without truncation
   regardless of device width.
4. The same icon-based selector applies on the supplier message
   override widget when the user changes the channel before
   sending.
5. Pressing "Usa com a llista de la compra" in a supplier section
   generates a plain text list of the `to_order` lines, copies it
   to the device clipboard, and shows a toast confirmation. The
   lines move to `ordered` state automatically and appear in the
   "Demanat" sub-group.
6. The clipboard text can be pasted into another app (Notes,
   WhatsApp, etc.) and contains the expected line format.
7. Pressing "Marca tot com a rebut" for the same section after
   "Usa com a llista de la compra" moves the lines from `ordered`
   to `received` as expected.
8. All existing flows continue to work without regression.
9. All affected screens follow the design system and have no
   hardcoded user-facing strings.
10. The work is committed to the existing `feat/spec-007-mvp-finish`
    branch, on top of the previous Phase 7A, Phase 7B, Fixes round
    1, and Fixes round 2 commits. The existing PR #16 should
    reflect these changes.

---

## 5. Notes for the implementer

- §2.1 is a small ordering change in two places (summary header and
  sub-group headers). No data changes.
- §2.2 may require adding a small package dependency (e.g.
  `font_awesome_flutter`) if the official WhatsApp logo is desired.
  If that adds significant weight or complexity, a generic
  chat-bubble icon is acceptable. The implementer chooses.
- §2.3 is the substantive change of the round: the action now does
  real work (generate text, clipboard write, state update). Treat
  the text generation as a refactor of the existing
  `composeItemLine` helper to allow output without a wrapper
  (greeting/signature/date); the line format itself is unchanged.
- The clipboard write uses Flutter's `Clipboard.setData` from
  `services.dart`. The toast is the standard SnackBar pattern from
  the design system.
- No new migrations.
- The PR description for #16 should be amended to document this
  third round of fixes as a fifth section after the second round.
