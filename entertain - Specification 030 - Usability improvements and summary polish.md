# Spec 030 — Usability improvements & summary polish

Branch: implemented **together with Spec 028** in one pass → one AAB, one internal-testing
round, one PR. The two are independent (028 = in-person shopping; 030 = these usability +
PDF-polish items); folding them avoids a second test cycle.

These come from **real use** of the app. Three usability fixes + a polish pass on the event
summary PDF (Spec 027).

---

## A. Pantry always last in supplier lists

In any supplier-ordered list, **El rebost (pantry)** must always appear **last**, not in
alphabetical position. Currently a newly added ingredient can push the pantry into the middle
(alphabetical). The pantry is not a real supplier (it's "what you already have at home"), so it
belongs at the end of every supplier-grouped list (shopping screen — both modes — and anywhere
suppliers are listed in order).

- Sort: real suppliers in their normal order; **pantry pinned to the end**.

---

## B. Add a photo from the creation screen (not only edit)

Photos are essential to the app. Today, creating a new dish or ingredient and then adding a
photo requires: create → save → go to the catalog → edit → add photo. That round-trip is
friction.

- The **photo control must be available on the initial creation screen** for both **dishes**
  and **ingredients** (the same photo control already used on the edit screen), so a photo can
  be added **at creation time**.
- Same behavior as edit (camera / gallery / online collection; the cover becomes the first
  photo). On save, the photo persists with the newly created entity — no second trip to the
  catalog.

---

## C. Extended dietary badges (unknown & negative)

Today badges show **only positive, known** classifications (Spec 026). To let the user **verify
everything is informed**, badges now express all three states per axis. The goal: an unclassified
aspect is **visible at a glance** (a black "?") so the user can complete it.

**All badges share the same pill shape. Background color encodes the state; letter color is
chosen per badge for legibility (not all white):**

Two axes, **at most one badge each** → **max 2 badges**:

**Diet axis (vegetarian/vegan):**
- Vegan → **dark green** bg, **white** letters, "VGN".
- Vegetarian → **light green** bg, **dark-green** letters, "VGT" (kept from Spec 026 — good
  contrast; do NOT switch to white on light green).
- Known **not** vegetarian/vegan → **light-grey** bg, **darker-grey** letters, "VGT".

**Gluten axis:**
- Gluten-free → **orange** bg, **white** letters, "SG".
- Known **has gluten** → **light-grey** bg, **darker-grey** letters, "SG".

**Unknown — the "?" badge (transversal):**
- If **either** axis is unknown → a single **"?"** badge, **black** bg, **white** "?", **no
  VGT/SG letters**. It means "something is unknown, so this can't be fully classified."
- The "?" appears **once**, covering whichever axis/axes are unknown.

Note on letter color: legibility wins over uniformity. Strong-background badges (dark green,
orange, black) take white letters; soft-background badges (light green, light grey) take a
tone-on-tone darker letter. This also creates a useful visual hierarchy — strong assertions
(is vegan / is gluten-free / is unknown) read loud; nuances (is vegetarian / is not) read soft;
the black "?" stands out so the user spots what's left to classify.

**Combinatorics (exactly):**
- Both axes unknown → **1 badge: "?"**.
- Diet known (pos/neg) + gluten unknown → **2 badges: VGN/VGT(green) or VGT(grey)** + **"?"**.
- Diet unknown + gluten known (pos/neg) → **2 badges: "?"** + **SG(orange) or SG(grey)**.
- Both known → **2 badges**: each axis its color (green/orange if positive, grey if negative).

Examples (from the user):
- Known not vegetarian, gluten unknown → **VGT grey + "?" black**.
- Known has gluten, diet unknown → **"?" black + SG grey**.

**Where:** everywhere positive badges already appear — catalog lists, menu, and the summary PDF.

**Colors:** vegan `#1F6B52` bg / white text; vegetarian light green `#CFE7DD` bg / dark-green
`#1F6B52` text; gluten `#D6603A` bg / white text; **negative** light-grey bg / darker-grey text;
**"?"** black bg / white text.

**Derivation unchanged (Spec 026):** dishes derive from ingredients conservatively; "unknown"
propagates (any unknown ingredient → dish diet unknown → "?"). Bought dishes use their own value.
The same `dietaryBadgesFor` logic extends to emit the unknown/negative cases; reuse the pure
helper + tests.

---

## D. Event summary PDF — presentation polish (Spec 027 follow-up)

Keep all content (including ingredient photos + badges — they're information). The goal is
**better layout**, more professional, **not removing** information.

1. **Recipe step line-height:** compress the vertical spacing between recipe steps. Currently
   steps in separate lines get too much air, stretching recipes (e.g. the rice) over far more
   space than needed. Tighten to a clean, readable step list.
2. **Ingredient badges placement:** badges currently float far right with a large empty gap
   from the ingredient text, looking detached. Place them **close to / right after** the
   ingredient name + quantity, neatly aligned, so each row reads as one unit. Ingredient photos
   stay (small leading thumbnail), but the row must be **well laid out** (photo · name · qty ·
   badges, balanced — not photo · name … big gap … badges).
3. **Section spacing:** make vertical spacing between sections regular; add a bit more air
   between the "Compra" title and its first supplier header (backlog item).
4. **Header block:** refine the event-data block (Data/Hora/Lloc/…) alignment and spacing for a
   cleaner, more professional look.
5. **File name = event name:** the saved/shared PDF file must be named after the **event name
   with its original capitalization and spaces** (e.g. "Dinar Maduixer 260614.pdf"), not the
   current lowercased, hyphenated form. Preserve spaces and uppercase.
6. Apply the extended badges (§C) in the PDF too (unknown "?" / grey negatives), same rules.

This is a **bounded** polish pass — the items above, then stop (no open-ended restyling).

---

## E. Deprecate "Begudes" as a supplier category; default drinks to Supermercat

"Begudes" as a **supplier** is a conceptual leftover — drinks are a product *type*, not a *place
you buy at*. New drinks currently default their supplier to "Begudes". Change this:

- **New drinks default to the "Supermercat" supplier category** (already exists).
- **Deprecate "Begudes"** as a supplier category. It appears to be a **system** category, so
  deprecation likely touches the **system seed**, not just the user's data. CC must verify
  whether "Begudes" is a system or user-created category and handle accordingly.
- **Migration (two parts):**
  1. **Remove "Begudes" from the system** (seed) so new/empty setups don't show it.
  2. **Migrate existing drinks** that point to "Begudes" → "Supermercat", then remove the
     "Begudes" category. Don't orphan any drink.
- This is a **DB migration over real data** → show the SQL before `db push` (the project rule).
- Verify there are no other entities (beyond drinks) pointing to "Begudes" before removing it;
  if there are, migrate them too (common sense — nothing left dangling).

---

## Implementation notes
- §A: pantry sort — pin the pantry/rebost group to the end in the supplier ordering used by the
  shopping screen(s).
- §B: reuse the existing photo widget/flow from the edit screen on the create screen for dish
  and ingredient; ensure the pending photo is attached to the entity created on save.
- §C: extend `dietaryBadgesFor` (or its presentation) to return the per-axis state
  (positive/negative/unknown) and a possible transversal "?"; the badge widget renders bg color
  by state, white text always. Update `DietaryBadges` + the PDF badge drawing + tests. Keep the
  "vegan shows only VGN" rule (vegan implies vegetarian — still one diet badge).
- §D: PDF builder layout tweaks in `lib/features/events/summary/event_summary_pdf_builder.dart`;
  filename in the service (`Printing.sharePdf(filename:)`) from the event name (sanitize only
  what the platform forbids, keep spaces/case).
- §E: change the new-drink default supplier to "Supermercat"; a DB migration that (1) drops
  "Begudes" from the system seed and (2) reassigns drinks (and any other entity) pointing to
  "Begudes" → "Supermercat", then removes the category. Verify category origin (system/user)
  first; show SQL before push.
- i18n: no new user-facing strings expected beyond existing badge abbreviations.

## Tests
- Pantry sorts last even after adding an ingredient that would otherwise reorder it.
- Creating a dish/ingredient with a photo from the create screen persists the photo (no edit trip).
- `dietaryBadgesFor` extended: both-unknown→["?"]; diet-neg+gluten-unknown→["VGT"grey,"?"];
  gluten-known+diet-unknown→["?","SG"...]; both-known positive/negative combinations; vegan→["VGN"].
- Badge widget renders correct bg per state, white text.
- PDF filename equals the event name with spaces/case preserved.
- New drinks default to the Supermercat supplier; no drink remains pointing to "Begudes" after
  migration; "Begudes" is gone from the system.

## Verification (validated together with Spec 028, one AAB)
1. `flutter analyze` + `flutter test` green.
2. On the Pixel: pantry shows last in shopping lists; create a new ingredient → add photo on
   the creation screen → it's saved with the photo; dishes/ingredients show ?/grey badges where
   applicable across catalog, menu and PDF; generate a summary → recipes are tighter, ingredient
   rows read cleanly with badges next to the text, sections evenly spaced, the file is named
   after the event (spaces + capitals).

## Out of scope
- Open-ended restyling of the PDF beyond the listed items.
- Changing the dietary derivation logic (only the badge presentation extends).
- Drinks dietary badges (still out, per Spec 026).
