# Spec 027 — Event summary sheet (PDF)

Branch: one PR. Client-side PDF generation (Flutter). No DB migration for the core feature.
This pass also folds in two carried-over polish items from Spec 026 (see §9), so a single AAB
validates everything together.

## Context

From an event's screen, the user can generate a **summary sheet**: a self-contained PDF that
gathers the whole event — branding, all the data, guests, the full menu (dishes with recipes and
ingredients, drinks), suppliers, and the shopping list — to print for the kitchen or share with
whoever helps organize. The PDF is built **on the device** (offline, immediate) and can be saved to
Files or shared via the system sheet.

Design principle throughout: **common sense** — never show an empty section, never force an empty
list; show each item with whatever it has.

## A. Trigger & delivery

- A **"Crea full resum"** action on the event screen (Esdeveniment tab — e.g. an action in the app
  bar or a button in the event detail).
- On tap: build the PDF (show a progress indicator while it generates — see §C on why this matters),
  then present the system **share/save sheet** so the user can save to Files, print, send by
  WhatsApp/email, etc. Both "save to Files" and "share" are covered by the platform sheet.
- Generated in the **app's current language**.

## B. Document structure (top to bottom)

Visual language matches the manual / getting-started guide: Entertain logo, green/orange palette,
clean section headers. Reuses the **dietary badges** (VGN/VGT/SG pills from Spec 026) where dishes
and ingredients appear.

1. **Cover / header**
   - Entertain logo + the slogan ("La vida és reunir-se al voltant d'una taula." / localized).
   - Event **name** as the title.
   - Event **photo** (if any).
   - Key data: date, time, place, number of guests (comensals), format (assegut/bufet), type
     (dinar/sopar), notes.

2. **Convidats** (omit the whole section if there are no guests)
   - Guest list grouped by state (confirmat / pendent / excusat) with subtotals and total.
   - The over-capacity note if it applies (confirmats > comensals).

3. **Menú**
   - **Dishes:** each dish with its photo (if any), servings, dietary badges, the ingredient list
     with quantities, and the step-by-step preparation.
     - *Common sense:* a **bought (comprat) dish** with no ingredients/recipe shows just its name,
       servings, supplier and photo — no empty ingredient/recipe blocks.
   - **Drinks:** each drink with its photo (if any), quantity and supplier. (Drinks have no dietary
     badges — out of scope per Spec 026.)
   - Menu totals: number of dishes, servings, servings per guest.

4. **Compra** (omit if there's nothing to buy)
   - Shopping list **grouped by supplier**, with quantities already calculated.
   - Per line: item, quantity/unit. (Keep it a clean list; the live order-state machine is an app
     concern, not part of a printed summary — show the list, not the per-item state.)
   - Bought dishes and drinks appear as single lines, as in the app.

5. **Footer**
   - "Fotos d'stock proporcionades per Pexels." + generated-on date.

All photos are included: event, every dish, every ingredient, every drink (per the decision to
include everything). See §C for the performance implication.

## C. Performance & images (point of attention)

Including **all** images (event + every dish + every ingredient + every drink) on a device-generated
PDF means fetching and embedding potentially dozens of images. To keep generation reasonable and the
file from getting huge:

- **Downscale images before embedding** (e.g. cap the longest edge at ~800–1000 px / a sane DPI for
  print); don't embed full-resolution originals.
- Embed from the **already-cached** cover/photo paths where possible (the app already resolves cover
  paths via `entityCoverPathsProvider`); avoid re-downloading if a local cache exists.
- Show a **progress indicator** (and keep the UI responsive) while building — generation may take a
  few seconds with many images.
- If, with real data, ingredient photos prove to bloat the document without adding value, revisit
  "all ingredient photos" then — but build it as specified first and judge on real output.

## D. Implementation notes (Flutter)

- Use the Flutter **`pdf`** package (+ `printing` for the share/save sheet). Add the dependencies.
- A `lib/features/events/summary/` area: an `EventSummaryPdfBuilder` that takes the event aggregate
  (event + guests + menu dishes/drinks with their resolved recipes/ingredients + shopping list) and
  returns the PDF bytes; a small service to trigger build + present the share sheet.
- Reuse existing data: the event detail already loads guests, menu (per-event dish copies with
  scaled quantities), and the shopping list (grouped by supplier). The summary reads the **same**
  resolved data the screens show — no recomputation, no divergence.
- Dietary badges: render the same VGN/VGT/SG pills (text + Entertain colors) used in the catalog
  (Spec 026), drawn as PDF widgets.
- Branding constants (colors, logo asset) reused from the app theme so the PDF matches the app.
- i18n: all static labels (section titles, "Convidats", "Menú", "Compra", field labels, footer) via
  ARB so the document follows the app language. Dish/ingredient/drink names already come localized
  from the catalog.

## E. Edge cases (common sense)

- No guests → omit Convidats.
- No shopping items → omit Compra.
- Bought dish (no ingredients/recipe) → name + servings + supplier + photo only.
- Dish with no photo / ingredient with no photo → just omit the image, no placeholder.
- Unknown/none dietary → no badge (same rule as Spec 026).
- Very long event (many dishes) → the PDF simply flows to as many pages as needed.

## Tests

- `EventSummaryPdfBuilder` produces non-empty PDF bytes for a representative event (dishes with
  recipes + a bought dish + drinks + guests + shopping list).
- Section omission: an event with no guests yields a PDF without the Convidats section; same for an
  empty shopping list.
- Image downscaling helper caps dimensions as specified.
- Dietary badge rendering in the PDF matches `dietaryBadgesFor` (vegan→VGN only, etc.).
- Localized labels: the document's static labels follow the selected locale.

## Verification

1. `flutter analyze` + `flutter test` green.
2. On the Pixel 8 Pro: from an event with a full menu (cooked + bought dishes, drinks, photos),
   guests in several states, and a shopping list across suppliers → "Crea full resum" builds the
   PDF, the share/save sheet appears, and the saved PDF shows: branding + slogan + event photo +
   data; guests by state; each dish with photo, badges, ingredients, recipe; drinks; shopping list
   by supplier; footer. Check an event with no guests omits that section; check generation time and
   file size are acceptable with all images.

## §9 — Folded-in polish from Spec 026 (same branch/AAB, validated together)

These two were captured in the backlog as carried-over polish; they ride along in this pass to save
a test cycle.

- **(a) "Entertain" on the splash.** Add the brand name to the splash, stacked above the logo:
  "Entertain" (bold, brand green #1F6B52) on top · logo centered · slogan below (as is). Use an
  `Align` so the **logo stays at its exact center** — don't shift it, to preserve the seamless
  handover from the native splash. If keeping the logo centered while fitting the name above doesn't
  look right, propose it rather than moving the logo.

- **(b) Hints DB sync.** The source file `Entertain - Hints (seed).md` is already at 40 hints
  (1 welcome + 39 tips) on main, but the **DB still has the original 44**. A migration syncs them:
  - Delete the rows for the 4 retired keys (`menu_add_button`, `hints_toggle`, `event_status`,
    `photos_pexels`) **and their translations** (the Spec 026 trigger doesn't cover `kind='hint'`,
    so delete `translations` rows explicitly).
  - Update the text (ca/es/en) of the 4 rewritten keys (`photos_three`, `event_format`,
    `config_suggestions`, `menu_adhoc`) to match the source file.
  - Idempotent; regenerable from the source file (extend `gen_hints_seed.py` or a sibling script).
  - **Show the migration before `db push`.**

## Out of scope

- Server-side PDF generation (decided: client-side for now).
- Editing/customizing what the summary includes (it's all-in by design).
- Drinks dietary badges (parked since Spec 026).
- The per-item shopping **state** in the printed sheet (the live state machine stays an app concern).
