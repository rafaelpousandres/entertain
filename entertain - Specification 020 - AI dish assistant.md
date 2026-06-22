# Specification 020 — AI dish assistant (recipe from a name)

> Build assignment for Claude Code. Read CLAUDE.md, "entertain - Data model.md",
> the backlog (§0 AI-native, §1 ingredients multilingües, §2 assistent de plats),
> and **Spec 019** — this is the first consumer of the AI side of the
> 019 infrastructure (Edge Function + server secret + quota/entitlement). It
> validates that the quota design generalizes beyond stock photos.
>
> The **migration** (if any) and the **Edge Function** are shown for approval;
> nothing is pushed/deployed until the user confirms. One PR; commit the spec
> with the code. Branch: `feat/spec-020-ai-dish-assistant`.

---

## 1. Goal & flow

Turn "what's the dish called?" into a complete, editable dish. The user types a
name; **Claude does all the work** (search, scrape, verify, adapt, normalize);
the app presents up to **3 viable options**; the user picks one; it is **saved
directly** as a normal, editable dish.

Example: user types **"Sípia a la bruta"** → up to 3 verified-viable options →
user picks #1 → a full dish is created and saved (name, ingredients with
quantities, servings, recipe in the dish's *preparation* field, photo).

**Confirmed stances:**
- **Direct save**, no pre-save review gate. The user edits afterwards if needed.
  (Rationale: minimal friction, "Claude does all the work".)
- Claude returns only options it deems **viable** (coherent, cookable). Fewer
  than 3 is fine.

---

## 2. What Claude produces per option

A structured dish:
- **name** (canonical dish name; multilingual — see §4).
- **servings** (`base_servings`).
- **ingredients**: each with **quantity + unit + ingredient**, mapped to
  Entertain's model as far as possible (see §3). Each ingredient is multilingual
  (§4).
- **recipe → the dish's *preparation* field.** The recipe (summarized,
  translated) goes into the **existing dish-level preparation field** — **no new
  column**. Plain monolithic text, **not** split into steps (the field is plain
  text already). *Clarified: "preparation" here is the dish-level preparation
  (the recipe), distinct from per-ingredient preparation below.*
- **photo**: hybrid web→Pexels (see §5).
- (internal) provenance/notes: source + confidence, for debugging/traceability.

**Per-ingredient preparation (secondary, best-effort, NOT priority).**
In Entertain, *ingredient* preparation is a **purchase instruction to the
supplier** ("clean and cut into rings"), **not** a recipe step. If the recipe
clearly implies an ingredient must be bought with a special preparation, and it
can be extracted cleanly, the assistant **may** also fill the ingredient's
preparation. **With caution**: never invent it, and never confuse a recipe step
with a supplier instruction. If unclear → leave empty. Low priority; the dish
preparation (the recipe) is what matters.

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

## 6. Architecture — reuses Spec 019 infrastructure

- **Edge Function** (new, e.g. `dish-assistant`): input = dish name + locale +
  the group's ingredient/unit catalogs. Calls the **Anthropic API** with the key
  as a **server secret** `ANTHROPIC_API_KEY` (never on the client — same pattern
  as `PEXELS_API_KEY`). Returns the up-to-3 structured options. A **save** action
  persists the chosen option: create new ingredients as needed (with i18n
  names), create the dish (with preparation = recipe), attach the photo via the
  019 pipeline, optionally fill per-ingredient preparation (best-effort).
- **Quota/entitlement:** reuse the generic quota (Spec 019) with a new
  `quota_key = 'dish_assistant'`. **Limits (decided): free 3/month → premium
  50/month.** Consumed on a **successful save** (not on search/preview), via the
  same `consume_quota`/`release_quota` RPCs. Default constant (3) mirrored in
  Edge + client.
- **Premium seam:** at the limit → the same limit-reached message pattern as 019
  (paywall seam, no upsell yet).
- **Two clients** inside the function as in 019 (user-scoped for identity/RLS
  reads; service-role for quota RPCs + privileged writes).

---

## 7. Client (Flutter)

- **Entry points:** wherever a dish can be added, **if feasible**; if that's hard
  to wire everywhere, **at minimum the dish catalog next to "New dish"**
  (the "Crea un plat amb IA" action, working title). The Spec-018 add-to-menu
  "create new" flow is a natural second home if cheap.
- **Screen:** a name field → "Cerca" → up to 3 option cards (name, key
  ingredients, servings, photo, short summary) + remaining quota
  ("Queden N de 3 aquest mes") → tap an option → saves → opens the new dish (or
  returns to the originating flow). Limit-reached → the seam message.
- **Locale** passed through (ca/es/en) so Claude works and writes in the user's
  language (and stores the others).

---

## 8. i18n, tests, verification

- **i18n (ca/es/en):** entry action label, screen (name hint, loading/empty/
  error, option cards), remaining-quota string, limit-reached message. Strings
  in the three ARBs + `flutter gen-l10n`.
- **Tests (Flutter, no live Supabase — fakes/overrides like 019):**
  - Quota math for `dish_assistant` (free 3 default; exhausted at limit).
  - Mapping/parse helpers (pure): option JSON → dish model; ingredient matching
    against a provided catalog (existing vs. new); multilingual-name parsing with
    original-language mark.
  - Client wiring (faked function): picking an option calls save, on success
    opens/refreshes; `QuotaExceededException` surfaces the seam message.
  - Edge Function (Deno) logic verified by design + on-device run (not in
    Flutter CI), as in 019.
- `flutter analyze` + `flutter test` green before the PR.

### Operator steps (after merge; one at a time)
1. Create/own an **Anthropic API key**; `supabase secrets set ANTHROPIC_API_KEY=…`.
2. `supabase functions deploy dish-assistant`.
3. (No new quota seeding needed — `dish_assistant` uses the generic quota; free
   default applies with no entitlement row.)
4. On the Pixel (Internal Testing): "Crea un plat amb IA" → "Sípia a la bruta" →
   pick an option → dish saved with ingredients, servings, recipe in preparation,
   photo; new ingredients carry ca/es/en names; quota decrements; limit blocks.

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
- **URL input mode** (paste a URL instead of a name) — later; same pipeline, a
  second input. The name flow is primary (the backlog reframed the old "URL
  importer" around this).
- **Batch backfill** of translations for existing ingredients (follow-up).
- Broader i18n of dishes/drinks/all catalog entities.
- Event wizard (separate backlog item / Spec).
- Billing/price (the quota seam is here; price is the Billing Spec).
- A pre-save ambiguity-review UI.

---

## Notes
- First consumer of the AI side of the 019 infra; proves the quota/entitlement
  design generalizes.
- Data-model doc to update after (ingredient i18n + original mark; any new
  provenance).
