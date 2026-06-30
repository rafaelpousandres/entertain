# Spec 032 — Course ordering, input-pill harmonisation, shopping urgency order, and summary line rules

From **real use** organising an actual event. Five related polish items, one pass → one AAB →
one internal-testing round → one PR (mobile validation gate: AAB built from the branch, validated
on the Pixel **before** the merge — per canònic §2.3 v0.9).

- **A.** Canonical course order everywhere (aperitius → entrants → plats principals → postres → begudes).
- **B.** Input-pill harmonisation: one shared base for all selection pills; size to ~72% of the
  pre-Spec-031 original; guest-status pills gain semantic colour on press.
- **C.** Shopping order by urgency (both modes); status-change selector in reverse order.
- **D.** Summary sheet: two-weight horizontal rules + per-course section titles.

None of these touch the data model.

---

## A. Canonical course order — everywhere

Courses must always appear in this fixed order wherever they're listed:

```
1. Aperitius   2. Entrants   3. Plats principals   4. Postres   5. Begudes
```

- Define this as a **single canonical order** (one ordered enum/constant), consulted by every
  surface that lists courses. Do **not** re-sort per surface — one source of truth.
- Currently the summary sheet (at least) does not respect this order; fix it there and anywhere
  else courses are listed (menu, add-to-menu, catalog groupings, etc.).
- Empty courses are simply absent (no empty headers — see §D).

---

## B. Input-pill harmonisation

### B1. One shared base component
All "input pills" (selection chips the user taps to choose) must share **one base component** —
same shape, size, typography, spacing, and **neutral→pressed behaviour**. They differ only in
**which colours** the pressed state uses, per domain. Pills to harmonise:

- Dietary input pills (VGN/VGT/SG/?) — ingredient/dish/guest editors.
- Event **type** pills.
- Event **format** pills.
- Guest **status** pills.

All already render as pills today; this unifies them under one base so they look and behave
identically. The pressed-state palette is the only per-domain difference.

### B2. Behaviour (identical for all)
- **Not pressed** → neutral format (as the dietary pills look now: outline, secondary text, no fill).
- **Pressed** → the pill takes its domain colour as fill + a checkmark, same grammar as the
  dietary pills.

### B3. Guest-status semantic colours (pressed state)
Guest-status pills follow the exact same neutral→pressed mechanic; the pressed colours are
semantic (a traffic-light read):

- **Excused** pressed → **red** fill + checkmark.
- **Pending** pressed → **orange** fill + checkmark. *(Pending is the default, so it is the
  pressed one on a fresh guest.)*
- **Confirmed** pressed → **green** fill + checkmark.
- Any status **not** pressed → neutral (same as all other input pills).

(No colour before pressing — identical rule to the dietary pills.)

### B4. Size
Spec 031 shrank the dietary choice pills to 60% of their original. That was a bit too small.
Resize the shared base to **~72% of the pre-031 original** (i.e. roughly +20% over the current
60%). Apply to the shared base so all harmonised pills grow together. Final size to be confirmed
on the Pixel (calibration; nudge if a hair too small/large).

Reference (pre-031 originals, for the 72% target): horizontal padding 14, vertical 9, checkmark
16, spacing 6, border-radius 20, font 15 → scale each to ~72%.

---

## C. Shopping order by urgency

### C1. Ingredient list order (both Comandes and En persona modes)
Order ingredients by **urgency**, most urgent on top:

```
1. Per demanar   2. Falta   3. Demanat   4. Rebut   5. A casa
```

Within each status group, **alphabetical**. (Received / at-home items sink to the bottom.)

### C2. Status-change selector — reverse order
When changing an ingredient's status, the list of options offered keeps its current behaviour
(omitting the current status, as now), but in **reverse order**:

```
A casa → Rebut → Demanat → Falta → Per demanar   (omitting the current status)
```

Only the ordering of the selector changes; everything else as-is.

---

## D. Summary sheet — two-weight rules + course section titles

The summary already looks good; these make it more readable and structured. Keep all content.

### D1. Per-course section titles
Add a section title for each course present, in the canonical order (§A):

```
Aperitius · Entrants · Plats principals · Postres · Begudes
```

- **Begudes** title already exists; add the other four.
- **Omit any course that is empty** (no title for a course with no dishes).

### D2. Full-width horizontal rules, two weights

**Thick rule** (heavier than the current line) — between the major blocks:
- Between Capçalera and Convidats.
- Between Convidats and Menú.
- Between Menú and Compra.

**Thin rule** (as the current line) — within blocks:
- Under the Convidats title.
- Under the Menú title.
- Under each course-type title (Aperitius … Begudes).
- Under each dish + its ingredients group.
- Under each supplier-category title in Compra.

Rules span the **full width** of the document.

### D3. Implementation note (expert calibration)
Give the rules enough vertical breathing room so a thick block-rule immediately followed by a
thin title-rule doesn't read as a cramped double line. Balance the air above/below each weight so
the hierarchy reads cleanly (thick = major break, thin = minor grouping). Minor spacing
adjustments to achieve a clean, professional read are in scope.

---

## Implementation notes
- **A:** single canonical course order constant/enum; every course-listing surface consults it.
  Audit the summary builder and menu/catalog groupings for hard-coded or alphabetical orderings
  and replace with the canonical one.
- **B:** extract/confirm a shared base input-pill widget; migrate dietary, event-type,
  event-format and guest-status pills onto it; per-domain pressed palette; size to ~72% of the
  pre-031 original on the base.
- **C:** shopping list sort = (urgency rank, then name) in both modes; status-selector list
  reversed (omit current).
- **D:** summary builder — add per-course titles (canonical order, skip empty); two rule weights
  full-width at the specified boundaries; tune vertical spacing per D3.
- i18n: course titles (Aperitius/Entrants/Plats principals/Postres/Begudes) need the three
  locales if not already present; reuse existing strings where they exist.

## Tests
- Course order: a menu with courses added out of order renders in canonical order on every
  surface (summary included).
- Input pills: all four families share the base; neutral when unpressed, domain colour +
  checkmark when pressed; guest-status pressed colours red/orange/green per status.
- Shopping: ingredients sort by urgency rank then name in both modes; status selector lists in
  reverse, omitting the current status.
- Summary: per-course titles appear in canonical order, empty courses omitted; thick rules at the
  three block boundaries, thin rules at the within-block boundaries.

## Verification (Pixel, internal testing — one AAB, built from the branch, validated before merge)
1. `flutter analyze` + `flutter test` green.
2. On the Pixel:
   - Courses everywhere in canonical order (check the summary specifically).
   - All input pills harmonised and at the new ~72% size, legible; guest-status pills show
     red/orange/green + checkmark when pressed, neutral otherwise.
   - Shopping (both modes): ingredients ordered by urgency, alphabetical within status; status
     selector reversed.
   - Summary: course titles present (empty ones omitted), two-weight full-width rules at the
     right places, clean spacing.
   - No regression on existing editing flows.

## Out of scope
- Data-model changes.
- Translation model (stays Sonnet).
- Any pill colour semantics beyond the dietary palette and the guest-status traffic-light.
- Open-ended restyling of the summary beyond the listed rules/titles.
