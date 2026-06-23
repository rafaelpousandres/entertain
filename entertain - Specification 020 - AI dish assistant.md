# Specification 020 — AI dish assistant (generate a dish from a name/description)

> Build assignment for Claude Code. Read CLAUDE.md, "entertain - Data model.md",
> the backlog (§0 AI-native, §1 ingredients multilingües, §2 assistent de plats),
> and **Spec 019** (this reuses its Edge Function + server secret + quota infra).
>
> **Revision v4 — radically simplified.** Earlier versions tried to read recipe
> URLs (scrape/web_fetch). That hit **timeouts** (`WallClockTime`) and **anti-bot
> blocks** (e.g. BBC Good Food returns SITE_BLOCKED). Testing showed Claude
> **generates excellent dishes from its own knowledge**, instantly, including
> from vague descriptions ("a Catalan rabbit stew made with chocolate" →
> conill amb xocolata; "like gazpacho but thicker" → salmorejo). So the whole
> URL/scraping machinery is **dropped**. The assistant now: one free-text field →
> Claude generates the dish card → user reviews → saves. No URLs, no web_fetch,
> no timeout, no photo-rights issue.
>
> Migration from v1 already applied (enum `dish`, `original_locale`,
> service_role grants) — unchanged. Edge Function is rewritten (simpler).
> Nothing pushed/deployed until the user confirms. Branch:
> `feat/spec-020-ai-dish-assistant` (continues).

---

## 1. Goal & flow

One free-text field → a complete, reviewed dish card.

1. **Input:** a single free-text field — **"Nom o breu descripció"**. The user
   types a dish name *or* a short description ("guisat català de conill amb
   xocolata", "com el gaspatxo però més espès", "carbonara").
2. **Generate:** Claude (**Haiku**) identifies the dish and generates a full
   **dish card from its own knowledge** — no web access. It also suggests an
   illustrative **stock photo** (Pexels, via the 019 pipeline). This is where the
   real cost is, so **quota is charged here** (see §5).
3. **Review:** the generated card is shown to the user (name, description,
   category, base servings, acquisition mode, ingredients, preparation, photo).
   **New ingredients** (not yet in the catalog) are **visibly marked** as "will
   be created". The user chooses **Desa** (save) or **Descarta** (discard).
4. **Save:** on Desa, the dish is created in the catalog (creating any new
   ingredients), exactly like a manually-created dish — fully editable
   afterwards. On Descarta, nothing is persisted (but quota was already charged
   at generate — the AI work was delivered).

**Confidence/honesty.** For dishes Claude doesn't reliably know (e.g. obscure
regional dishes like "doteni"), it must **generate but flag low confidence in the
description** rather than inventing with false certainty. Never present an
uncertain recipe as verified. (Aligns with "a single error casts doubt on
everything displayed".)

**No URLs, no scraping, no web_fetch.** Removed entirely — they caused the
timeouts and blocks, and Claude's own knowledge is better for this.

---

## 2. The dish card Claude produces

Matches Entertain's dish model (confirmed fields):
- **name** — canonical dish name. Multilingual ca/es/en + `original_locale`
  (the assistant writes in the user's language and stores the other two; see §4).
- **description** — one-line subtitle (`dishes.description`). For low-confidence
  dishes, note the uncertainty here.
- **category** — one of the app's categories (aperitius / entrants / plats
  principals / postres / begudes / altres).
- **base_servings**.
- **acquisition mode** — normally *cuinat a casa* (the assistant generates
  recipes); the model's existing field.
- **ingredients** — list, each: **ingredient (name) · quantity · unit ·
  supplier category · prep note**. Mapped to the catalog (see §3).
- **preparation** (`dishes.preparation`, existing text column) — **clear,
  consecutive numbered steps**, an easy-to-follow recipe. Because Claude writes
  it from scratch (not copied from a source), it can structure it well: numbered
  steps as plain text in the field (e.g. "1. …\n2. …\n3. …"). **No new column**
  — it's formatted text inside the existing field.
- **photo** — an illustrative stock photo suggestion (Pexels, by dish name),
  attached via the 019 pipeline (download → storage → media with provenance).

**Per-ingredient prep note = supplier instruction, NOT a recipe step.** In
Entertain, an ingredient's prep note tells the *supplier* how to provide it
("net", "a daus", "ratllat", "a rodanxes"), it is **not** a cooking step. The
assistant fills it only when it's a genuine purchase instruction; recipe actions
go in `preparation`, never here. If none applies → leave empty. *(This was a
correction during design: don't put "mòlt al moment" / "per a la picada" here.)*

---

## 3. Ingredients — map to catalog, else create  (much easier now)

Because **Claude generates the card** (rather than decoding scraped web text),
ingredient mapping is far easier: Claude picks catalog ingredients *as it
writes*, instead of reverse-engineering messy source text.

The Edge Function passes Claude, as context: the group's **ingredient catalog**
(group + system: id + names in the relevant languages) and the **unit catalog**
(canonical units). Claude then:
- **Existing ingredient** → reference it by **catalog id**, and express the
  quantity in that ingredient's **canonical unit** (adapt: if catalog "Oli
  d'oliva" is in ml, output ml). Avoids duplicates.
- **New ingredient** (not in catalog) → mark as **new**; the function **creates
  it** with Claude's **best estimate** (sensible default unit + inferred supplier
  category) **and multilingual names** (§4). Available for future dishes.
- **Review transparency:** in the review card, **new ingredients are visibly
  marked** ("es crearà") so the user sees what will be added to the catalog
  before confirming.
- Vague amounts → a sensible amount; never fail the whole card over one line.

Everything is reviewed before saving, so an occasional odd estimate is caught at
review or edited afterwards.

---

## 4. Multilingual names (ingredients + dish) — from backlog §1

The assistant stores names in **ca/es/en**, marking the **original** language vs
AI-derived translations (traceability; the original is the reference).
- **Model:** reuse the `translations` table (enum already has `ingredient`; v1
  added `dish`), `field='name'`, one row per locale; plus `original_locale` on
  `ingredients`/`dishes` (v1 migration, applied).
- **Rule (decided): always the three languages** (ca/es/en), original marked.
- **Store ≠ display:** all three are **stored**; **display stays in the original
  for now** — localized display + backfill of existing entries is **Spec 021**,
  out of scope here (as agreed). English stored also serves as the stock-photo
  search bridge.

---

## 5. Architecture — reuses Spec 019, one action

- **Edge Function `dish-assistant`** — one action, **`generate`**:
  input = free text (name/description) + locale. Steps:
  1. Resolve caller + group (user client, RLS).
  2. **`consume_quota`** (service role) `quota_key='dish_assistant'`, default 3.
     **Charged here** (generation is the costly step). Returns NULL at cap →
     **402 limit_reached** (paywall seam).
  3. Load catalogs (ingredients group+system, units, supplier categories).
  4. Call Claude **`claude-haiku-4-5`** (Haiku — cheap/fast; the task is pure
     generation now, no web). Structured output → the dish card (§2) with
     ingredients mapped/new, multilingual names, numbered-steps preparation, a
     **Pexels photo query** (or chosen photo).
  5. Fetch the **stock photo** via the 019 Pexels pipeline (server-side) — this
     photo is **part of the dish_assistant operation and does NOT touch the
     `stock_photos` quota**. (One assistant call = one recipe + its photo, a
     single `dish_assistant` charge.)
  6. Return the **card for review** (not yet persisted) + usage. On generation
     **failure** (error / can't produce) → **`release_quota`** (don't charge a
     failed generation).
- **Save is a separate step** (client-initiated on *Desa*): persist the dish
  (create new ingredients with i18n, dish with preparation + multilingual name,
  `dish_ingredients`, attach the already-fetched photo). *Discard* persists
  nothing. (Quota already charged at generate, by design — the AI work was
  delivered.)
  - Implementation note: the function may return the fully-formed card and do the
    DB writes on a second `save` call, OR stage and commit — Claude Code picks the
    cleaner approach, but **quota is charged at generate**, **photo is free of
    the stock_photos quota**, and **discard leaves no dish/ingredients behind**.
- `ANTHROPIC_API_KEY` + `PEXELS_API_KEY` server-only (both set). Two clients as
  in 019. `verify_jwt = true`.
- **Quota/entitlement:** generic 019 quota, `quota_key='dish_assistant'`, **free
  3/month → premium 50/month**. Default constant (3) mirrored Edge + client.
- **Model cost note:** **Haiku** to start (cheap, ample for known dishes). If
  identification/quality on obscure dishes proves weak, bump to Sonnet 4.6 — a
  one-line change. (Web removed, so the task is light → Haiku fits.)

---

## 6. Client (Flutter)

- **Entry point:** the dish catalog, next to "Nou plat" — a **"Crea un plat amb
  IA"** action **with the AI symbol** (see §7 usability).
- **Screen:**
  - One **free-text field** ("Nom o breu descripció") + a generate action
    (with AI symbol). Header shows remaining quota ("Queden N de 3 aquest mes").
  - On generate → loading state → show the **review card**: name, description,
    category, servings, acquisition, ingredients (with **new ones marked**),
    numbered preparation, photo. Two buttons: **Desa** / **Descarta**.
  - **Desa** → save → open the new dish (editable). **Descarta** → back to the
    field (quota already spent). Limit reached → seam message.
- **Locale** passed through (ca/es/en).

---

## 7. Usability — consistency + AI symbol  (requested)

Current inconsistency to fix: the AI entry was a small green link while normal
actions are large orange buttons — confusing.
- **Harmonize** the AI actions with the app's button system (size, color,
  hierarchy) so the AI entry reads as a first-class action, consistent with
  "Nou plat" etc., not an afterthought link.
- **AI symbol always present when AI is used.** Put the AI symbol on every
  AI-driven action/entry (the catalog entry, the generate button, anywhere the
  assistant is invoked) — consistently, so the user always knows when AI is in
  play. (The AI symbol idea was good; the execution just needs to be consistent.)

---

## 8. i18n, tests, verification

- **i18n (ca/es/en):** entry label, field hint ("Nom o breu descripció"),
  generate button, loading/empty/error, review card labels, "es crearà" marker,
  Desa/Descarta, remaining-quota, limit-reached. ARBs + `flutter gen-l10n`.
- **Tests (Flutter, no live Supabase — fakes/overrides like 019):**
  - Quota math `dish_assistant` (free 3 default; exhausted at limit).
  - Parse: generation JSON → dish-card model; ingredient mapping (existing id vs
    new-flagged); multilingual-name parse with original mark; numbered-steps
    preparation preserved.
  - Client wiring (faked function): generate → review card shown with new
    ingredients marked; Desa → save/open; Descarta → nothing saved;
    `QuotaExceededException` → seam.
- `flutter analyze` + `flutter test` green before PR.

### Operator steps
- `ANTHROPIC_API_KEY` + `PEXELS_API_KEY` — **done**.
- `supabase functions deploy dish-assistant` — redeploy the v4 (generate) version.
- On the Pixel (Internal Testing): "Crea un plat amb IA" → type "carbonara" →
  card appears **fast** (no timeout) → review (new ingredients marked) → Desa →
  dish saved with ingredients, numbered preparation, photo; quota decrements.
  Try a vague description ("com el gaspatxo però més espès") → salmorejo. Try an
  obscure one → low-confidence note, no invented certainty. Limit blocks at cap.

---

## 9. Migration
**None.** v1 migration (enum `dish`, `original_locale`, service_role grants) is
applied and sufficient. `dish_assistant` reuses the generic 019 quota. No schema
change.

---

## 10. Out of scope
- URL/scraping input (**removed** — caused timeouts/blocks; Claude's knowledge is
  better here).
- Localized **display** + backfill of existing entries → **Spec 021**.
- Broader i18n of drinks/all catalog entities.
- Event wizard (separate Spec).
- Billing/price (quota seam is here).
- Multiple photo alternatives to choose from (could be a later refinement; for
  now one suggested photo, changeable after save via the normal picker).

## Notes
- First AI feature; validates the 019 quota generalizes (now with a second
  `quota_key`).
- The radical simplification (knowledge-generation vs URL-scraping) came from
  live testing — keep that as the design rationale.
- Data-model doc: ingredient/dish i18n + original mark already noted; no new
  schema here.
