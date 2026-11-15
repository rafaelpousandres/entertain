# Entertain — Specification 034 — UX improvements from user feedback

> **Origin:** First production feedback round. Real user suggestions collected via
> the in-app Suggestions tool (Spec 021), extracted 2026-11-15, plus two director
> items. Scope deliberately bounded to concrete, low-risk UX improvements — no new
> large features, no infrastructure, no parked items (collaboration/multi-group,
> in-person shopping mode, RSVP web, admin panel stay out by decision).
>
> **Source traceability:** each item cites its origin — suggestion number from the
> 2026-11-15 report (S#), director item (DIR), or backlog (BL §).

## Goal

Turn the first real-use feedback into a coherent, shippable release that polishes
existing flows. Every item is an improvement to something that already exists; none
adds a new surface. The release must be validatable as a whole and low-risk for the
users already in production.

## Out of scope (explicitly, to prevent gold-plating)

- **Collaborative / multi-group shopping list** (S#7) — large, touches RLS and
  architecture (Phase 2). Deserves its own spec; not here.
- **In-person shopping mode** (BL Spec 028) — already specified; separate release.
- **Typography change** (S#1) — single subjective opinion on the global design
  system / brand identity; not actioned on one data point. Logged in backlog to
  revisit if more users ask.
- **Infrastructure** (CI workflow, photo-staging cron, quota bridge reversion) —
  belongs to the infra/Pro pass, not this UX release.

---

## Block A — Adding dishes to the event menu (flow rework)

The current flow for putting dishes on an event menu is clunky: dishes land with
default servings and must be edited afterwards, and creating a dish with AI forces
a round-trip out to the catalog. Both are addressed here.

### A1 — Ask for servings before adding a catalog dish (S#11)
When adding a dish from the catalog to an event menu, prompt to confirm/adjust the
**servings before** the dish is added, instead of inserting it with default servings
and forcing the user to edit the per-event copy afterwards.
- Current: dish inserted with default servings → user opens the per-event copy → edits.
- Target: the servings step happens as part of adding, up front.
- Keep the per-event copy model (editing later still possible); this only moves the
  servings decision to insertion time.
- **Where:** client, event menu add-dish flow.

### A2 — Create an AI dish directly from the event menu (DIR)
Allow creating a dish with the AI assistant **directly from the event menu**, saving
it to the catalog along the way (so the catalog stays the source of truth) and adding
it to the current event menu in one go.
- Current: leave menu → go to catalog → create with AI → return to event → add to menu.
- Target: from the menu's "+ add dish" area, an AI-create entry that creates the dish
  (persisted to the catalog, same as the catalog flow — reuses Spec 020 assistant and
  its `dish_assistant` quota) and adds it to the event menu, respecting A1 (servings
  asked before it lands).
- No change to quota or AI infrastructure; this is a new entry point to the existing
  assistant, plus wiring the result into the menu.
- **Where:** client, event menu; reuses the dish assistant (Spec 020).

---

## Block B — Catalog integrity warnings

### B1 — Warn when deleting an ingredient in use (S#8)
When deleting an ingredient, warn if it is used in one or more dishes, and say which
dishes, so the user can decide with full information.
- Target: before confirming deletion, check usage across dishes; if used, show a
  warning listing the affected dishes (not a silent delete, not a hard block — an
  informed confirmation).
- **Where:** client (confirmation UI) + the query that resolves ingredient→dishes
  usage.

### B2 — Flag a dish ingredient that is not in the catalog (S#9)
If a dish has an ingredient that is not in the catalog, indicate it visually so the
user can correct it.
- Context: AI-created dishes (Spec 020) match ingredients to the catalog; some may end
  up unmatched. Today nothing signals which ones.
- Target: a visual marker on the unmatched ingredient line in the dish, with an
  affordance to fix it (match to an existing catalog ingredient or create it).
- **Where:** client, dish detail; relies on the existing matched/unmatched state from
  the assistant pipeline (confirm how "not in catalog" is represented in the model
  before building the UI).

---

## Block C — Photos

### C1 — Multi-select photos from the gallery (S#12)
When adding photos from the device gallery, allow selecting more than one at a time.
Currently only one can be added per action.
- Target: the gallery picker allows multi-selection; selected photos are added in
  selection order, each failing one not aborting the rest (reuse the robustness pattern
  already decided for multi-upload where applicable).
- **Where:** client, photo add flow (gallery picker).

### C2 — Drag feedback in the photo carousel (S#13)
When a carousel photo is picked up to be reordered by dragging, nothing indicates it
is selected / about to drag until it actually moves. Add a clear visual state on
pick-up (e.g. lift/shadow/highlight) so the user knows the photo is grabbed.
- **Where:** client, photo carousel reorder interaction.

### C3 — Include all event and dish photos in the summary PDF (S#10)
Put all the photos of the event — and of the dishes — in the event summary sheet.
- Current: the summary shows the first (cover) photo only.
- Target: keep the first photo as the cover/header as today, and additionally include
  the remaining photos, smaller but clearly visible, for both the event and each dish.
- **Constraint:** more photos must not bloat the PDF or hurt render time. Reuse the
  existing ≤1000px session-cache downscale (Spec 027 §C); choose a small thumbnail size
  and layout for the secondary photos; cap or paginate sensibly if an entity has many.
  CC decides the exact size/layout within this constraint.
- **Where:** client, `event_summary_pdf_builder.dart` (+ photo resolution already used
  by the summary).

---

## Block D — Event duplication

### D1 — Copy guests when duplicating an event (DIR)
When duplicating an event, also copy the guests. Currently they are not copied.
- Target: duplication includes the guest list (names, contacts, and the per-event
  state/dietary fields as appropriate). Confirm against the current duplication logic
  what is copied today (menu, dishes, etc.) and extend it to guests consistently.
- **Where:** client/repository, event duplication logic.

---

## Block E — Summary button reachability (backlog residual)

### E1 — Keep "Create summary" visible without scrolling (BL §6)
On the event detail screen, the Notes field reduced to `maxLines: 2` (Spec 033 §C)
does not always guarantee the **"Create summary"** button is visible without scrolling
(depends on screen height and content above). Implement a robust solution: anchor the
button outside the scroll area, or compute available space.
- **Where:** client, `event_detail_screen.dart`.

---

## Acceptance criteria (per block)

- **A1:** adding a catalog dish asks for servings before it lands on the menu; the
  dish appears already with the chosen servings; the per-event copy remains editable.
- **A2:** from the event menu, the user can create a dish with AI without leaving the
  event; the dish is persisted to the catalog and added to the menu with servings
  asked up front; `dish_assistant` quota is consumed exactly as in the catalog flow.
- **B1:** deleting an in-use ingredient shows a warning naming the dishes that use it
  before the delete proceeds.
- **B2:** a dish ingredient not present in the catalog is visually flagged, with a way
  to fix it.
- **C1:** multiple gallery photos can be selected and added in one action.
- **C2:** picking up a carousel photo to drag shows an immediate visual state.
- **C3:** the summary PDF shows the cover photo as before plus the remaining event and
  dish photos as small thumbnails, without a disproportionate size/time cost.
- **D1:** duplicating an event produces a copy that includes the guest list.
- **E1:** the "Create summary" button is reachable without scrolling across screen
  sizes and content lengths (verified on device).

## Notes for implementation

- **No database schema change is anticipated** for most items; B1 and B2 rely on
  existing relations (ingredient↔dish usage; matched/unmatched ingredient state). CC
  confirms the model before building each UI; if any item turns out to need a schema
  change, CC flags it in words before any `db push`, per the migration protocol.
- **Validation:** Closed Testing (per the director's standing decision — no Pixel
  Internal gate for this kind of low-risk UX change), unless CC judges an item risky
  enough to warrant device validation first.
- **Sequencing:** blocks are independent; CC may implement and land them in the order
  it judges cleanest, but all ship together as one coherent release. Report at natural
  stopping points.
- **Language:** code/comments in English, user-facing strings via ARB (ca/es/en), per
  the project convention.

## Backlog updates on incorporation

- Mark S#8, S#9, S#10, S#11, S#12, S#13 as incorporated into Spec 034.
- Mark the two director items (duplicate→guests, AI dish from menu) as incorporated.
- Mark BL §6 "Create summary without scroll" residual as incorporated.
- Log S#1 (typography) as a captured idea to revisit if more users request it.
- Log S#7 (collaborative shopping list) as a captured idea for a future dedicated spec
  (Phase 2, multi-group).

---

## Block F — Duplicate a catalog dish (DIR, added 2026-11-15)

### F1 — Duplicate a dish to create a variant
Allow duplicating a dish in the catalog, producing an independent copy that can then
be modified to record a variant of the same dish (same base, different tweaks) without
re-creating it from scratch. Common need: "the same dish, but with X changed."
- **Independence:** the copy is fully independent — editing it does not touch the
  original, and vice versa (same guarantee as event duplication's per-event copies).
- **What copies:** name (suggested as "Còpia de …" / "Copy of …", editable), ingredients
  with their quantities and notes, dietary attributes, purchase mode / supplier if the
  dish is a purchased one, recipe/preparation steps, **and the photos** (director
  decision 2026-11-15). The copy must remain **independent**: deleting, adding or
  reordering photos on one dish must not affect the other. CC decides in the plan how to
  achieve that given the storage model — a shared-reference copy only if the `media`
  model guarantees that per-dish photo edits never touch another dish's rows/blobs;
  otherwise copy the blobs so the two dishes are truly independent.
- **Entry point:** from the dish catalog (e.g. an action on the dish card or inside the
  dish editor), consistent with how other duplicate/overflow actions are surfaced.
- **Where:** client, catalog (dish card / dish editor) + `catalog_repository` (duplicate
  logic); confirm against the dish model what a faithful independent copy requires.
- **BD:** likely none (reuses existing dish/ingredient relations); CC confirms in the
  plan, and flags before any `db push` if a schema change turns out necessary.

### Acceptance criteria — F1
- Duplicating a catalog dish produces an independent copy with the same ingredients,
  quantities, attributes and (if purchased) supplier data; editing either dish leaves
  the other unchanged; the copy's name is pre-filled as a "copy of" and is editable.

### Backlog update
- Log the dish-duplication capability as incorporated into Spec 034 (director item,
  2026-11-15).
