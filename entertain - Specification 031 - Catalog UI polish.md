# Spec 031 — Catalog UI polish

Three independent UI items folded into one pass (one AAB, one internal-testing round, one PR),
all from **real use** of the app after Specs 029 and 030 §B shipped:

- **A.** Show-badges: drop the grey negative pills (revises Spec 030 §C).
- **B.** Bug fix: Pexels photo-search prefill at creation time (wrong / untranslated query).
- **C.** Choice-pills: shrink to 60% so they fit on one line.

None of these touch the data model. This is polish + one bug fix.

---

## A. Show-badges — drop the grey negative pills (revises Spec 030 §C)

Spec 030 §C introduced a **grey "negative-known" pill** (e.g. a grey "VGT" meaning *known not
vegetarian*, a grey "SG" meaning *known has gluten*). In real use these read **ambiguously**: a
grey pill labelled "Vegetarià" looks like "is vegetarian, dimmed" rather than "is **not**". The
grey doesn't negate strongly enough.

**New rule (per axis — diet and gluten — independently):**
- Known **positive** (is VGN / VGT, or is SG) → show the corresponding pill.
- **Unknown** → show the "?" pill.
- Known **negative** ("not it") → show **nothing**. **No negative pills.**

**Single "?" rule (kept from 030 §C):** if **both** axes are unknown, show **one** "?", not two.

**Resulting combinations:**

```
?  |  ? + SG  |  VGT + ?  |  VGN + ?  |  VGN + SG  |  VGT + SG  |  VGN  |  VGT  |  SG  |  (nothing)
```

User reading: a pill present → it is so (or, if "?", unknown); **no pill and no "?"** → it is
**not** so (known negative, no visual noise).

**Where:** **show**-badges only — catalog lists, menu, dishes/ingredients, and the summary PDF.
**NOT** the guest list (already correct). This is the presentation side (`DietPill` /
`DietaryBadges`), not the choice side.

**Derivation unchanged:** the diet/gluten state per entity is computed as before (Spec 026/030);
only the **rendering** changes — the negative state now renders as absence instead of a grey pill.

---

## B. Bug — Pexels photo-search prefill at creation time

**Symptom:** creating a new ingredient/dish and opening the Pexels photo search, the search field
shows only the **initial letter** of the name the first time, and the **full but untranslated**
name on subsequent opens.

**Root cause (diagnosed):** order-of-operations. The photo-search term is built from
`photoSearchTerm(localName, nameEn)` **before** the row exists in the DB and before the English
translation has been generated. At creation `nameEn` is `null` (the row doesn't exist yet), so
the search gets local-only — and, depending on timing, even an incomplete name. The
`translate-name` Edge Function fires **after** row insertion, too late for the first photo search;
on the second open (row now saved) `nameEn` is present.

**Goal:** the photo search at creation time must use the **full name** and, where it helps Pexels
results, have the **English translation available at that moment**, without depending on the row
being saved first.

**Possible approaches** (CC's technical call, per the code):
- Force/advance the English translation specifically for the photo search, not waiting on the
  normal save flow; or
- Defer opening the photo search until the translation is available; or
- Whichever CC finds cleanest with the current code.

**Constraint:** the fix must not block or slow the creation flow if translation fails or is slow
(translation is best-effort; the search must still work with at least the local name).

---

## C. Choice-pills — shrink to 60%

**Where:** the dietary **choice** pills (VGN/VGT/SG/?) in the ingredient, dish and guest editors
— the `DietChoicePill` component and the `DietLevelChoice` / `GlutenStateChoice` groups.

**Problem:** they take too much space and don't fit on a single line.

**Goal:** shrink them to **60% of current size** (40% smaller) so they fit on one line, keeping
legibility (colors and checkmarks clearly visible).

**Technical (CC's call):** scale padding, checkmark size, spacing and typography proportionally
so the set shrinks without losing clarity. Apply consistently across the three places the choice
pills are used.

---

## Implementation notes
- **A:** change the **show**-badge rendering (`DietPill` / `DietaryBadges` and the PDF badge
  drawing) so the known-negative state renders as **absence** (no pill) instead of a grey pill;
  keep the single transversal "?" for unknown axes; keep the positive pills as they are. Do not
  touch the guest-list pills. Update the relevant tests (the badge-emission helper should no
  longer emit grey negatives for the show side).
- **B:** make the creation-time photo-search term resolve the full name and, where it improves
  results, the English translation, without requiring the row to be saved first. Keep it
  best-effort and non-blocking.
- **C:** scale the `DietChoicePill` dimensions (currently: horizontal padding 14, vertical 9,
  checkmark icon 16, spacing 6, border-radius 20) and group spacing proportionally to ~60%,
  preserving legibility; apply in ingredient/dish/guest editors.
- i18n: no new user-facing strings expected.

## Tests
- Show-badges: known-negative renders **nothing** (no grey pill); unknown renders a single "?";
  both-unknown → one "?"; positive combinations unchanged. Guest-list pills unchanged.
- Pexels search at creation: the prefill is the full name (not the initial) and the English
  bridge is available for better results.
- Choice-pills render at the reduced size and remain legible (colors + checkmarks).

## Verification (Pixel, internal testing — one AAB)
1. `flutter analyze` + `flutter test` green.
2. On the Pixel:
   - Catalog / menu / PDF show only known characteristics + "?" for unknown, **nothing** for
     known-negative, a single "?" when both axes unknown. Guest list unchanged.
   - Creating a new ingredient/dish → open photo search → the field shows the full, translated
     name (not the initial letter).
   - Choice pills in the editors are smaller, fit on one line, colors + checkmarks still clear.
   - Editing existing entities still works (no regression).

## Out of scope
- No data-model changes.
- Guest-list show-pills (already correct).
- Translation model (stays Sonnet — validated).
- Open-ended restyling beyond the listed items.
