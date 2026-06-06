# Specification 007 — Fixes (round 2)

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read `CLAUDE.md`, `entertain - Data model.md`, `entertain - Design system.md`,
> the original `entertain - Specification 007 - MVP finish.md`, and the
> first round of fixes `entertain - Specification 007 - Fixes.md` before
> starting. This document is a second round of fixes after on-device
> validation of the first round; it gathers five small improvements that
> emerged when the project owner used the polished panel in realistic
> conditions.

---

## 1. Goal

The first round of fixes corrected the supplier category contact model,
the redundant section headers, the transition matrix flexibility, the
Rebost binary model, and the automatic state adjustment on category
change. All five passed on-device validation.

While exercising the panel, the project owner identified five further
improvements:

1. The state-indicator colours should follow a semantic palette of
   availability (green for "I have it", red for "I don't", yellow for
   "in transit", orange for "in transit but late").
2. A new visual state "Retrassat" (Delayed) should appear for items
   in `ordered` state whose needed-by date has passed.
3. The channel preferent selector should offer a "Compartir" option
   that dispatches via the OS share sheet without requiring a stored
   address.
4. The address fields in the supplier category detail screen should
   be visually paired with their corresponding channel radio button.
5. The supplier sections in the shopping panel should be reordered so
   the two consultive sections (Rebost, Sense categoria) are grouped
   at the end, after the dispatching-capable sections.

This round corrects all five.

---

## 2. Scope — what to fix

### 2.1 Semantic colour palette for ingredient states

**Observed**: the state indicators on each ingredient line currently
use the design system tokens chosen during Phase 7B (e.g. urgent for
"to_order", warning for "missing", secondary accent for "ordered",
success for "received", neutral for "at_home"). These choices do not
align with the project owner's mental model, which classifies the
states by **availability** rather than by stage:

| State | Availability | Suggested colour |
|---|---|---|
| **at_home** | I have it | green |
| **received** | I have it | green |
| **to_order** | I don't have it | red |
| **missing** | I don't have it | red |
| **ordered** | In transit | yellow |

**Fix**: change the colour mapping so that the indicator colour
reflects availability:

- `at_home` and `received` use the **success / green** token.
- `to_order` and `missing` use the **danger / red** token.
- `ordered` uses the **warning / yellow** token.

The implementer should pick the appropriate semantic tokens from the
design system; if no exact "yellow" or "red" token exists, choose the
closest equivalent that conveys the meaning. The two pairs
(at_home/received and to_order/missing) intentionally share the same
colour: they differ in history (planned vs leftover, fresh-arrival vs
always-present) but not in current availability, and the user reads
the panel for availability first.

The state-name labels next to each indicator continue to disambiguate
which precise state each line is in, so sharing colour between two
states does not lose information.

### 2.2 Derived state "Retrassat" (Delayed) for overdue orders

**Observed**: when an order is sent for an event, the corresponding
lines move to `ordered` and stay there until manually marked as
`received`. If the supplier does not deliver by the needed-by date,
the line stays in `ordered` with no visual cue that it is now late.
The project owner wants a visual alarm for this case.

**Fix**: introduce a **derived state** "Retrassat" (Delayed). It is
not persisted in the database; it is computed at the UI layer as:

> state = `ordered` AND CURRENT_DATE > needed_by_date

When a line satisfies this condition, the UI renders it as if it
were in a sixth state called "Retrassat", with a distinct **orange**
colour (between the yellow of `ordered` and the red of
`to_order` / `missing`). The state label reads "Retrassat" /
"Retrasado" / "Delayed".

In the shopping panel:

- The per-state sub-group within a supplier section gets an extra
  sub-group "Retrassat" (positioned between "Demanat" and "Rebut",
  reflecting its semantic position).
- The global summary header at the top of the Compra tab counts
  delayed items as a separate count (e.g. "15 ingredients · 8 a casa ·
  3 per demanar · 2 demanats · **1 retrassat** · 0 rebut · 1 falta").

Transitions:
- Manually marking a delayed line as `received` (which is allowed by
  the free transition matrix) takes it out of the derived state
  automatically (because the underlying `state` changes).
- Manually marking a delayed line as `missing` is also allowed; in
  that case the line moves to the `missing` sub-group.
- The user can also reset to `to_order` to re-plan, which clears the
  delayed condition naturally.

Implementation note: the "Retrassat" pseudo-state is purely a
presentation concept. The underlying database column `state` still
contains the four operational values (`at_home`, `to_order`,
`ordered`, `received`, `missing`); no migration is needed.

### 2.3 "Compartir" option as channel preferent

**Observed**: the channel preferent selector currently offers
WhatsApp, Email, and Cap (None). For suppliers reached via other
channels (Telegram, Signal, SMS) or for cases where the user prefers
to choose the destination at send time, there is no clean option:
the user must pick WhatsApp or Email arbitrarily and override at the
message screen.

**Fix**: add a fourth option **"Compartir"** to the channel preferent
selector. When this option is the default for a supplier category:

- The phone and email address fields remain visible and editable but
  are **not required**. The user may leave both empty and the
  configuration still validates.
- Pressing "Envia missatge" in the shopping panel triggers the OS
  share sheet directly with the composed message text. The user
  picks the destination app at that moment (Telegram, SMS, copy to
  clipboard, etc.).
- The post-channel confirmation flow from Spec 005 §2.7 still
  applies after the share sheet closes.

The share sheet behaviour is already implemented as a dispatch
option in Spec 005; this fix surfaces it as a first-class preferent
channel rather than requiring the user to manually override on each
send.

Translations: ca "Compartir" / es "Compartir" / en "Share".

### 2.4 Visual pairing of address fields with their channel

**Observed**: in the supplier category detail screen, the channel
preferent selector and the two address fields (phone, email) are
laid out as independent rows. The relationship between each address
and the corresponding channel is implicit; the user has to read both
field labels to understand which one matters for the selected
channel.

**Fix**: redesign the layout so that each channel radio button is
visually paired with its corresponding address field. Conceptually:

```
○ WhatsApp     [+34 666 12 34 56     ]
○ Email        [proveidor@correu.com  ]
○ Compartir    (no address needed)
○ Cap
```

The exact widget composition is at the implementer's discretion; the
goal is that the visual association between each channel option and
its address field is immediate. The selected radio indicates the
preferent channel; the corresponding address is the one used by
default. The non-selected address remains visible and editable but
visually secondary (e.g. lower contrast, smaller, or simply not
highlighted).

The Rebost category continues to show no channel/address fields at
all, regardless of this layout change.

### 2.5 Reorder supplier sections — consultive sections at the end

**Observed**: the shopping panel currently orders supplier sections
alphabetically by name, with "Sense categoria" appended at the very
end. This means the Rebost section is interleaved with the dispatching
categories (Carnisseria, Peixateria, Rebost, Supermercat, ...,
Sense categoria), which makes the visual grouping unclear: the user
expects the consultive sections (those without send actions) to be
grouped together at the end.

**Fix**: split the section ordering into two groups:

1. **Dispatching categories** (those that can send messages):
   alphabetical by name. Examples: Carnisseria, Peixateria,
   Supermercat, plus any user-added categories.
2. **Consultive sections** (those without send actions): grouped at
   the end, in this order:
   - Rebost (the system pantry category).
   - Sense categoria (the catch-all for unclassified ingredients).

The result is that the user-visible order goes: dispatch-able
categories first (alphabetical), then Rebost, then Sense categoria.

---

## 3. Out of scope

Explicitly **not** part of this assignment (deferred to later
iterations, captured in the running list of project pendings):

- All items already deferred in the first round of fixes.
- Configuring custom colours per category or per state from the
  Settings screen.
- Persisting "Retrassat" as a fifth operational state in the
  database (it is a derived state; no migration).
- A timeline visualisation of orders / state transitions (would be
  a Phase 1 enrichment).
- iOS-specific share sheet behaviour. Phase 2.

---

## 4. Acceptance criteria

The assignment is complete when the project owner can verify all of
the following on the Android device:

1. State indicators in the shopping panel use the semantic palette:
   green for `at_home` and `received`, red for `to_order` and
   `missing`, yellow for `ordered`. The state label next to each
   indicator continues to disambiguate which exact state each line
   is in.
2. An order whose `needed_by_date` has passed and whose state is
   still `ordered` appears under a sub-group "Retrassat" within its
   supplier section, with an orange indicator. The global summary
   header counts delayed items as a separate count.
3. Manually marking a delayed line as `received` or `missing` moves
   the line to the corresponding sub-group; the "Retrassat" sub-group
   disappears when it becomes empty.
4. The channel preferent selector in the supplier category detail
   screen offers four options: WhatsApp, Email, Compartir, Cap.
   Choosing "Compartir" allows leaving both addresses empty.
5. Sending a message for a supplier whose preferent channel is
   "Compartir" triggers the OS share sheet directly. The post-channel
   confirmation flow runs as usual.
6. In the supplier category detail screen, each channel radio button
   is visually paired with the relevant address field. The user can
   tell at a glance which address corresponds to which channel.
7. In the shopping panel, supplier sections appear in the order:
   dispatching categories (alphabetical), then Rebost, then Sense
   categoria.
8. All existing flows continue to work without regression.
9. All affected screens follow the design system and have no
   hardcoded user-facing strings.
10. The work is committed to the existing `feat/spec-007-mvp-finish`
    branch, on top of the previous Phase 7A, Phase 7B, and Fixes
    round 1 commits. The existing PR #16 should reflect these
    changes.

---

## 5. Notes for the implementer

- §2.1 is a pure colour mapping change at the presentation layer. No
  data changes. If the design system needs an additional colour
  token for orange (used in §2.2), add it consistently with the
  existing palette.
- §2.2 is presentation-only. The database `state` column stays as
  the four operational values; "Retrassat" is computed at render
  time. Be careful to update the global summary header counts
  consistently — the count for `ordered` should not include the
  delayed items if they are counted separately as "Retrassat".
- §2.3 builds on the existing share sheet dispatch from Spec 005.
  The new aspect is making it a preferent channel rather than a
  manual override.
- §2.4 is a layout refactor of the supplier category detail screen.
  Use the design system's form layout patterns; the exact widget
  choice is open.
- §2.5 is a small sort change in the shopping panel; ensure the
  comparator handles all three groups (dispatching, Rebost, Sense
  categoria) in the right order.
- The PR description for #16 should be amended to document this
  second round of fixes as a fourth section after the first round.
