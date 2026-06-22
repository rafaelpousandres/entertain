# Specification 020 — AI dish assistant (recipe from a name)

> Build assignment for Claude Code. Read CLAUDE.md, "entertain - Data model.md",
> the backlog (§0 AI-native, §1 ingredients multilingües, §2 assistent de plats),
> and **Spec 019** — this is the first consumer of the AI side of the
> 019 infrastructure (Edge Function + server secret + quota/entitlement). It
> validates that the quota design generalizes beyond stock photos.
>
> **Revision v3 (two input paths).** Same two-phase processing, now with **two
> ways to reach a URL**, on the same screen:
> - **By name** (Path A): type a dish name → Claude suggests 3 {title,url} → pick
>   one → process it.
> - **By URL** (Path B): paste a recipe URL directly → process it (skips the
>   suggest phase). This folds the old backlog "URL importer" in cleanly.
> Both paths converge on the **same `process` action** (the costly phase); only
> the input differs. **Quota is charged on `process`, identically for both
> paths.** See §1.
>
> **Revision v2 (two-phase).** First build timed out (`WallClockTime`) processing
> 3 whole recipes at once. Flow split into **suggest (cheap) → process one
> (charges quota)**. Migration already applied in v1 (enum `dish`,
> `original_locale`, service_role grants) — unchanged.
>
> The **Edge Function** changes are shown for approval; nothing pushed/deployed
> until confirmed. Branch: `feat/spec-020-ai-dish-assistant` (continues).

---

## 1. Goal & flow — TWO PHASES, TWO INPUT PATHS

> **Revised after first build.** The original single-shot design (Claude fully
> processes 3 whole recipes, user picks one) **timed out** the Edge Function
> (`reason: WallClockTime`). The flow is now **two phases**: suggest cheaply,
> process only the chosen one. v3 adds a **second input path** (paste a URL
> directly) that skips the suggest phase.

There are **two ways to reach a recipe URL**, both on the **same screen**:

**Path A — by name** (name field, top):
1. **Suggest (fast, free, no quota).** User types a name ("caldereta de
   llagosta") → Claude returns **up to 3 suggestions**, each = **title +
   clickable URL** (opens in the external browser via `url_launcher` so the user
   can view the real recipe). Claude finds 3 good source URLs (may use
   web_search); it does **not** read/adapt them here → fast, no timeout.
2. User picks one → goes to **Process** (below).

**Path B — by URL** (URL field, below the name field):
- User already has a recipe URL → pastes it → goes **directly to Process**,
  skipping suggest. (This is the old "URL importer" idea, folded in.)

**Process (both paths converge here; charges quota).**
- Claude processes **that one recipe**: fetch + verify + adapt + normalize →
  name (multilingual), servings, ingredients mapped to the catalog, recipe text,
  photo. One recipe → well under the time limit.
- **Saved directly** as a normal, editable dish (no pre-save review gate).
- **Quota is consumed here** (the `dish_assistant` slot), on a successful save,
  **identically for Path A and Path B** — suggesting is free; producing the dish
  costs, however the URL was reached.

Example A: "caldereta de llagosta" → 3 title+URL suggestions → pick #2 → process
→ dish saved. Example B: paste `https://…/caldereta-llagosta` → process → dish
saved.

**Confirmed stances:**
- **Two phases** (suggest → process); **two input paths** (name, URL) on one
  screen, converging on `process`.
- **Direct save** of the processed dish; editable afterwards.
- Quota on `process`, same for both paths.

---

## 2. What Claude produces

### Phase 1 — suggestions (per call: up to 3)
Each suggestion is minimal:
- **title** (recipe name as found).
- **url** (the source recipe page; clickable → external browser).
- (optional) nothing else required. Keep Phase 1 cheap and fast.

### Phase 2 — the processed dish (the chosen recipe only)
A structured dish:
- **name** (canonical dish name; multilingual — see §4).
- **servings** (`base_servings`).
- **ingredients**: each with **quantity + unit + ingredient**, mapped to
  Entertain's model as far as possible (see §3). Each ingredient multilingual
  (§4).
- **recipe → the dish's *preparation* field** (`dishes.preparation`, existing
  text column — **no new column**). Plain monolithic text, not split into steps.
  *Dish-level preparation (the recipe), distinct from per-ingredient preparation.*
- **photo**: hybrid web→Pexels (§5) — prefer the chosen recipe's own image.
- **source url** stored as provenance (we now always have the exact source).
- (internal) provenance/confidence notes.

**Per-ingredient preparation (secondary, best-effort, NOT priority).**
In Entertain, *ingredient* preparation is a **purchase instruction to the
supplier** ("clean and cut into rings"), **not** a recipe step
(`ingredients.prep_description`, existing). If the recipe clearly implies an
ingredient must be bought with a special preparation and it extracts cleanly,
the assistant **may** fill it. With caution; if unclear → leave empty.

---

## 3. The hard part — unit & ingredient mapping

The known-difficult core (flagged by the owner). Recipe language is messy
("1 sípia mitjana", "un raig d'oli", "all al gust"); Entertain uses a **canonical
unit catalog** + a **per-group ingredient catalog**.

**Approach:** Claude receives, as context, the group's **ingredient catalog**
(names + ids, in the relevant languages) and the **unit catalog** (canonical
units), and does the best mapping itself:
- **Existing ingredient** → map to its catalog id; estimate a sensible quantity
  in a catalog unit ("una sípia mitjana" → Sípia, ~400 g; "un raig d'oli" →
  Oli, ~15 ml). Estimates are acceptable — the user edits later.
- **New ingredient** (not in catalog) → **create it** as part of saving (with a
  sensible default unit and, if inferable, a supplier category) **and with its
  multilingual names — see §4**. No blocking, no confirmation (direct-save).
- **Vague quantities** ("al gust", "un pessic") → a small sensible amount or a
  light note; never fail the whole import over one line.

Because everything is saved directly, there is no ambiguity-resolution UI here;
correctness rests on (a) giving Claude the catalogs so it maps to existing
entries instead of duplicating, and (b) easy post-hoc editing. (This is the main
risk area vs. the owner's "a single error casts doubt on everything" principle;
an optional lightweight review step could be added later if direct-save proves
too loose. Out of scope now.)

---

## 4. Multilingual ingredients (i18n) — folded in from backlog §1

This Spec is where ingredient i18n starts, because the assistant creates
ingredients and is the natural place to fill translations.

**Model:** each ingredient stores its **name in ca/es/en** (or more), with a
mark of **which language is the original** (what the source/user actually wrote)
vs. which are **AI-derived translations** (traceability/confidence: derived
translations may be wrong; the original is the reference). Reuse the existing
`translations` table if it fits, else dedicated fields — **[decide in plan]**.

**Rule (decided): always the three languages** (ca/es/en), original marked.
Whatever the creation language, generate the other two; no ingredient is left
incomplete. English is also the bridge for better stock-photo search.

**Store ≠ search ≠ display (decided):**
- **Store** all three (or more).
- **Search** (stock photos): send only **the user's language + English** (or
  English alone) — not all three; the third would be noise.
- **Display**: each user sees the ingredient **only in their language**; the
  other names exist for i18n and as a search bridge, not to show together.

**Who fills them:** the assistant fills the three names when it creates a new
ingredient. **Existing ingredients** (already in catalogs without translations):
a **batch backfill** pass with AI — **out of scope for this Spec** (capture as a
follow-up; this Spec only guarantees i18n for ingredients it creates).

**Scope note:** dishes (and drinks) could also become multilingual later;
**this Spec covers ingredients** (and the dish name as produced by the
assistant). Broader i18n of all catalog entities is a separate effort.

---

## 5. Photo — hybrid web → Pexels  [rights-aware]

Each option ideally carries a photo:
- **Try the source recipe's photo first** (visually exact). Identify it via the
  page's `og:image` / recipe JSON-LD; download server-side; store with
  provenance (source url/author if available).
- **Fallback to the Spec 019 Pexels pipeline** (illustrative photo by dish name)
  when no usable web image is found or it can't be fetched.

**Rights note (informed decision by owner).** Copying a third-party recipe photo
into a paid product carries copyright risk (recipe photos are usually
copyrighted). The owner has chosen the **hybrid** path (web first, Pexels
fallback) as an informed decision; provenance is stored so an image's source is
always traceable, and the Pexels fallback is always rights-clean. (If this ever
needs to be tightened, switching to Pexels-only is a one-line change.)

Photos are stored via the **019 pipeline** (download → upload to the entity
bucket → `media` row with provenance), reusing what already works.

---

## 6. Architecture — reuses Spec 019 infrastructure, two actions

- **Edge Function `dish-assistant`** with **two actions** matching the phases:
  - **`suggest`** (no quota): input = dish name + locale. Calls Claude
    (`claude-sonnet-4-6`) to return **up to 3 {title, url}** suggestions. May use
    `web_search`. **Must NOT fetch/adapt** the recipes — keep it light and fast
    (this is what fixes the timeout). Returns quickly. *(Only Path A uses this.)*
  - **`process`** (charges quota): input = a recipe `url` (+ optional name,
    locale). **Used by both input paths** — Path A passes the picked suggestion's
    URL, Path B passes the user-pasted URL; the action is identical.
    `consume_quota` (`quota_key='dish_assistant'`, default 3) → Claude fetches &
    adapts **that one** recipe (`web_fetch` for the page + og:image) → structured
    dish → create new ingredients (with i18n) → create dish (preparation =
    recipe, multilingual name) → `dish_ingredients` → hybrid photo (the recipe's
    image first, Pexels fallback via the 019 pipeline) → return dish_id + usage.
    `release_quota` on any failure. One recipe → well under the wall-clock limit.
- `ANTHROPIC_API_KEY` server-only; `verify_jwt = true`. Two clients as in 019
  (user-scoped for identity/RLS reads; service-role for quota RPCs + writes).
  The function loads the group catalogs itself (minimal client payload).
- **Quota/entitlement:** generic 019 quota, `quota_key='dish_assistant'`, **free
  3/month → premium 50/month**, consumed on a successful `process`. Default
  constant (3) mirrored Edge + client.
- **Timeout note:** both actions are sized to stay under the Edge Function
  wall-clock limit — `suggest` does no fetching, `process` handles a single
  recipe. (The original single-shot 3-recipe design exceeded it.)
- **Premium seam:** at the limit → the same limit-reached message as 019.

---

## 7. Client (Flutter)

- **Entry points:** wherever a dish can be added if feasible; at minimum the dish
  catalog next to "New dish" ("Crea un plat amb IA", working title).
- **Screen — one screen, two input paths:**
  - **Top: name field** → "Cerca" → calls `suggest` → shows **up to 3
    suggestions**, each a **title + clickable URL** opening in the **external
    browser** (`url_launcher`). Each suggestion has a **"Crea aquest plat"**
    action → calls `process` with that URL.
  - **Below: URL field** ("o enganxa una URL de recepta") → a **"Crea des
    d'aquesta URL"** action → calls `process` directly with the pasted URL
    (skips suggest).
  - A header shows remaining quota ("Queden N de 3 aquest mes") — informational;
    only `process` consumes it.
  - `process` success → opens the new dish; `QuotaExceededException` → the
    limit-reached seam message. A loading state during `process` (real work).
- Basic URL validation on Path B (looks like an http(s) URL) before calling.
- **Locale** passed through (ca/es/en).

---

## 8. i18n, tests, verification

- **i18n (ca/es/en):** entry action label, screen (name hint, loading/empty/
  error, option cards), remaining-quota string, limit-reached message. Strings
  in the three ARBs + `flutter gen-l10n`.
- **Tests (Flutter, no live Supabase — fakes/overrides like 019):**
  - Quota math for `dish_assistant` (free 3 default; exhausted at limit).
  - Parse helpers (pure): suggestion JSON → {title,url} list; processed-dish JSON
    → dish model; ingredient matching against a provided catalog (existing vs.
    new); multilingual-name parsing with original-language mark.
  - Client wiring (faked function): `suggest` returns title+URL list (no quota);
    picking one calls `process`, on success opens/refreshes; the URL opens via
    url_launcher; `QuotaExceededException` surfaces the seam message.
  - Edge Function (Deno) logic verified by design + on-device run (not in
    Flutter CI), as in 019.
- `flutter analyze` + `flutter test` green before the PR.

### Operator steps
1. `ANTHROPIC_API_KEY` secret — **done** (set in v1).
2. `supabase functions deploy dish-assistant` — redeploy the two-phase version.
3. (No quota seeding — generic quota; free default applies with no entitlement.)
4. On the Pixel (Internal Testing):
   - **Path A:** "Crea un plat amb IA" → "caldereta de llagosta" → **3 title+URL
     suggestions appear quickly** (no timeout); open a URL in the browser; tap
     "Crea aquest plat" on one → that recipe is processed and saved (ingredients,
     servings, recipe in preparation, photo); new ingredients carry ca/es/en
     names; quota decrements by one.
   - **Path B:** paste a recipe URL into the URL field → "Crea des d'aquesta URL"
     → same processing + save; quota decrements by one.
   - Limit blocks at the cap (both paths).

---

## 9. Migration

**Likely none** (to confirm in plan):
- Recipe → existing dish preparation field (no new column).
- Per-ingredient preparation → existing field.
- Multilingual ingredient names → **reuse `translations` if it fits**; only if
  it doesn't, an additive change (shown before push). The original-language mark
  may need a small additive column/field. **[decide in plan]**
- `dish_assistant` quota → no schema change (generic quota from 019).

If any additive migration is needed, show it before `db push`.

---

## 10. Out of scope (this Spec)
- **Batch backfill** of translations for existing ingredients (follow-up).
- Broader i18n of dishes/drinks/all catalog entities (display = Spec 021).
- Event wizard (separate backlog item / Spec).
- Billing/price (the quota seam is here; price is the Billing Spec).
- A pre-save ambiguity-review UI.

*(Note: URL input is now IN scope as Path B — the old "URL importer" idea is
folded into this Spec as the second input path.)*

---

## Notes
- First consumer of the AI side of the 019 infra; proves the quota/entitlement
  design generalizes.
- Data-model doc to update after (ingredient i18n + original mark; any new
  provenance).
