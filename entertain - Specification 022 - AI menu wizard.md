# Specification 022 — AI menu wizard (create / complete a menu)

> Build assignment for Claude Code. Read CLAUDE.md, "entertain - Data model.md",
> the backlog (§2 "Wizard de menú amb IA"), and **Specs 019 + 020** — this reuses
> the AI/Edge-Function/quota infra (019) and the dish assistant (020) for the new
> dishes it proposes.
>
> Migration/Edge-Function shown before push/deploy. One PR. Branch:
> `feat/spec-022-ai-menu-wizard`.

---

## 1. Goal & flow

On an event's **Menú** tab, an AI action that **proposes or completes the whole
menu**, using the event's parameters and a few questions.

- **Entry point:** on the **Menú** tab, a button **above "+ Afegeix plat"**,
  styled like "Crea un plat amb IA" (first-class button, **AI symbol**).
- **Adaptive label by context:**
  - menu **empty** → **"Crea un menú amb IA"**.
  - menu **already has dishes/drinks** → **"Completa el menú amb IA"**.
  - Callable **at any time**, even mid-way; it **respects what's already there**.
- **Context + questions:** starts from the **event parameters** (# people,
  servings format, …) and asks **a few multiple-choice questions** (meal type,
  formality, dietary restrictions, season…) **+ one open free-text answer**. Then
  it proposes the menu.
- **Proposal mixes catalog + new dishes:** the proposal can include **existing
  catalog dishes** and **new AI-created dishes** (reusing the 020 assistant). The
  user reviews, can accept/reject items, then they're added to the event menu.
- **"Spotify" model:** like Spotify adding new songs to a playlist that's already
  playing, the wizard **completes** the menu — it complements what's there, never
  silently replaces it.

---

## 2. The proposal

The wizard returns a proposed menu = an ordered set of **items**, each either:
- **catalog dish** (reference an existing `dishes.id` from the group catalog), or
- **new dish** (a full dish card as in 020 — name, ingredients, servings,
  preparation, photo — created on accept), or
- **drink** suggestions (optional; same idea, from catalog or new).

For "Completa" mode, the proposal is **additive**: it sees the current menu and
proposes **complementary** items (e.g. a starter and a dessert if only a main is
present), avoiding duplicates/clashes.

**Review UI:** the user sees the proposed items (catalog vs new clearly marked,
like the 020 "es crearà" badge for new dishes), can **deselect** any, then
**confirm** → selected items are added to the event menu (new dishes created in
the catalog first, then added), with quantities from the event's people/format.

---

## 3. Questions

Keep it short (2–4 questions) so it's fast:
- **Multiple-choice** (single or multi-select), e.g.: meal type (dinar / sopar /
  aperitiu / …), formality (informal / festiu / …), dietary constraints (cap /
  vegetarià / sense gluten / …), season/ingredients to feature.
- **One open free-text** answer ("alguna cosa més que vulguis?") for anything the
  options don't cover.
- Defaults pulled from the event where possible (# people, format). Don't ask
  what's already known.
- (Future) tie dietary questions to guest restrictions once §1B guests/RSVP and
  §1 dietary attributes exist.

---

## 4. Architecture — reuses 019/020

- **Edge Function `menu-wizard`** (or an action on the dish-assistant function —
  Claude Code picks the cleaner split):
  - **`propose`** (charges quota): input = event_id + the question answers +
    locale. Resolve group (RLS). `consume_quota` `quota_key='menu_wizard'`
    (default = free limit, see below). Load: event params, current menu (for
    "completa"), the group dish/drink catalog, ingredient/unit catalogs. Call
    Claude **`claude-sonnet-4-6`** (same model choice as 020 — quality matters)
    → a proposed menu (catalog refs + new dish cards). Return for review (not yet
    persisted). `release_quota` on failure.
  - **`accept`** (no extra quota): persist the user's selected items — create new
    dishes (reusing the 020 persist path: ingredients w/ i18n, preparation,
    photo) and add all selected dishes/drinks to the event menu with quantities.
- **Quota:** generic 019 quota, **`quota_key='menu_wizard'`**, **free 2/month →
  premium 15/month** (decided). Charged on `propose` (the costly step). Default
  constant (2) mirrored Edge + client.
- `ANTHROPIC_API_KEY` server-only (set). `verify_jwt=true`. Two clients as in 019.
- **service_role grants:** the function reads/writes via service role — ensure
  grants exist for every table it touches (events, menu/event-dishes, dishes,
  ingredients, dish_ingredients, drinks, translations, units, supplier_categories,
  media, quota_*). Most were granted in 019/020; **audit and add any missing one
  in the migration** (house rule — this pattern bit us repeatedly: service_role
  needs explicit table grants).

---

## 5. Client (Flutter)

- **Menú tab:** add the adaptive AI button above "+ Afegeix plat" (AI symbol),
  label "Crea un menú amb IA" / "Completa el menú amb IA" by menu state.
- **Wizard screen:** a few question controls (multi-choice + one free text) +
  a generate action; remaining quota header ("Queden N de 2 aquest mes").
- **Proposal review:** list of proposed items, catalog vs new marked, deselect
  toggles, a confirm action → adds to menu, opens/refreshes the Menú tab.
  Limit reached → seam message. Loading state during propose (real work).
- Locale passed through (ca/es/en).

---

## 6. Migration
- New `quota_key='menu_wizard'` needs **no schema change** (generic 019 quota).
- Only a migration if the audit (§4) finds a table the function touches without a
  `service_role` grant. Show before push.

## 7. i18n, tests, verification
- i18n ca/es/en: button labels (both states), questions, review UI, quota,
  limit. `flutter gen-l10n`.
- Tests (faked): quota math (`menu_wizard`, free 2); propose parse (catalog ref
  vs new dish); "completa" excludes/complements current menu; accept adds
  selected items + creates new dishes; QuotaExceededException → seam.
- `flutter analyze` + `flutter test` green before PR.
- On device: empty menu → "Crea un menú amb IA" → questions → proposal (mix of
  catalog + new) → confirm → menu filled with correct quantities. Non-empty menu
  → "Completa el menú amb IA" → complementary proposal, no duplicates. Limit
  blocks at cap.

## 8. Out of scope
- Guest-restriction-aware proposals (until §1B guests/RSVP + §1 dietary exist) —
  the dietary *question* can ship now; per-guest matching later.
- Billing/price (quota seam only).
- Reordering/structuring the menu by courses (could be a later refinement).

## Notes
- Third consumer of the 019 quota infra (after stock_photos, dish_assistant) —
  further validates the generic design.
- Reuses the 020 dish-creation path for new dishes; keep that shared, not
  duplicated.
