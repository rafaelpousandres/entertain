# Specification 021 — Suggestions box + usability polish pass

> Build assignment for Claude Code. Read CLAUDE.md, "entertain - Data model.md",
> and the backlog (§5 Suggeriments / §6 Polits). This is a **polish pass**: one
> small new feature (Suggestions) plus a batch of accumulated small fixes, done
> together to avoid spending separate Internal Testing cycles on each.
>
> Migration/Edge-Function changes (if any) shown before push/deploy. One PR.
> Branch: `feat/spec-021-suggestions-and-polish`.

---

## Part A — Suggestions box (new, simple, no AI)

A lightweight way for users to send suggestions/feedback, stored in the DB for
later export. **Deliberately simple**: no in-app AI, no automatic loop. The
intelligent processing (grouping, turning into backlog/specs) is done later by
the owner with Claude at claude.ai, from a DB dump.

- **Location:** Settings (Configuració), **after "Primers passos"**.
- **Title:** **"Suggeriments"**.
- **UI:** a free-text box (multi-line) + a send action. The text field must allow
  the system keyboard's **voice-to-text dictation** (standard Flutter text field
  does; just don't block it).
- **Counter/indicator:** show **how many suggestions the user/group has sent**
  (e.g. "N suggeriments enviats").
- **Persistence:** each suggestion is saved to a new **`suggestions`** table for
  later dump/export. No live processing.

### Migration — `suggestions` table
```sql
create table public.suggestions (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid references public.groups(id) on delete set null,
  user_id    uuid references auth.users(id) on delete set null,
  text       text not null,
  app_version text,           -- captured automatically
  created_at timestamptz not null default now()
);
alter table public.suggestions enable row level security;
-- Users may INSERT their own and READ their group's (for the counter).
create policy suggestions_insert on public.suggestions
  for insert to authenticated with check (public.is_group_member(group_id));
create policy suggestions_select on public.suggestions
  for select to authenticated using (public.is_group_member(group_id));
grant select, insert on table public.suggestions to anon, authenticated;
-- NOTE (house rule): if any Edge Function ever reads/writes this with the
-- service role, add an explicit grant to service_role. Not needed now (client
-- writes directly under RLS).
```
- `app_version` filled from the client (package_info) so the dump has context.
- Counter = `select count(*) ... where group_id = ...` (RLS-allowed).
- Export is manual/SQL for now (owner dumps the table → claude.ai). No admin UI.

### Client
- New entry in Settings after "Primers passos": **"Suggeriments"**.
- Screen: free-text box (hint inviting what's missing / what's broken), send
  button, and the sent-count indicator. On send → insert row → clear box →
  confirm ("Gràcies!") → counter increments. i18n ca/es/en.

---

## Part B — Usability polish (batch)

### B1. AI assistant photo doesn't become the dish cover  🐛
The stock photo the dish assistant (020) attaches automatically **does not show
as the dish's cover/header**, while **manually-added** stock photos **do**. So the
bug is in **how the assistant saves the photo**, not the cover logic or stock
photos in general. **Compare the assistant's `media` insert with the manual
Pexels picker's insert and align them** (likely `position`/ordering, a field the
manual path sets that the assistant doesn't, or insert order/`entity_id`).
- Fix in the `dish-assistant` Edge Function save (the photo step), matching the
  019 manual path. Verify on device that the auto photo becomes the cover.

### B2. Tune the dish-assistant prompt (field placement)  ✨
Claude sometimes misplaces info (seen with Sonnet):
- "Ceba" / "Plàtan" with note "en juliana" / "a rodanxes" → those are **cooking
  steps**, not supplier instructions; the ingredient prep note must NOT contain
  cooking steps (the item is bought whole). Cooking steps go in the dish
  preparation.
- "Formatge Gruyère ratllat" → "ratllat" (a valid supplier instruction) leaked
  **into the name**; name should be "Formatge Gruyère" and "ratllat" the prep
  note.
- **Reinforce in the prompt, with examples:** the ingredient prep note = ONLY a
  supplier instruction (net, a daus, ratllat, filetejat, sense pell…); the name =
  base ingredient, no preparation attached; cooking actions (a rodanxes, en
  juliana, picat, sofregit…) → dish preparation. If in doubt → leave the note
  empty.

### B3. Photo search query in English  ✨
The assistant's Pexels photo query misfires on Catalan/regional dishes ("bacallà
a la llauna" → a pizza). Have Claude produce the **photo query in English** (the
English dish name or main ingredient, e.g. "baked cod"), since Pexels indexes
mainly in English. (Bridges with the multilingual-ingredient English-name idea.)

### B4. "Editable after" hint under the AI-dish action
Under the "Crea un plat amb IA" entry/screen, add a short note that the dish can
be **edited right after creating it** (ingredients, quantities, photo,
preparation). Lowers pressure on generation; clarifies the user has final control.

### B5. Credits card order in Settings
Move the **"Crèdits"** card ("Fotos proporcionades per Pexels") to sit **between
"Primers passos" and "Privadesa i dades"**. Order-only change. *(Note: Part A adds
"Suggeriments" right after "Primers passos" — settle the final Settings order:
suggested → Primers passos · Suggeriments · Crèdits · Privadesa i dades. Confirm
in implementation.)*

### B6. Prefill the stock-photo search field (local + English)
When opening the Pexels search from a dish/ingredient/drink, **prefill** the query
with the entity name. **Important:** the search term should be **local language +
English** (not just Catalan) — English yields far better Pexels results. (The
local-name part can ship now; the English bridge depends on multilingual
ingredient names being available.)

---

## Tests, i18n, verification
- i18n (ca/es/en) for all new strings (Suggestions screen, the "editable after"
  hint, any labels). `flutter gen-l10n`.
- Tests: Suggestions (insert + counter, faked); the assistant-photo-cover fix
  (verify the `media` row matches the manual path's shape); prompt changes are
  behavioural (verify on device). Keep existing suite green.
- `flutter analyze` + `flutter test` green before PR.

### Operator / deploy
- `supabase db push` for the `suggestions` table (shown before push).
- Redeploy `dish-assistant` (B1, B2, B3) after approval. (B6 prefill is
  client-side; no `stock-photos` redeploy needed in this pass.)
- On device: send a suggestion (with dictation) → counter rises; generate a dish
  → photo becomes cover, prep-note/name placement correct, photo relevant;
  Settings order correct.

## Out of scope
- AI processing of suggestions in-app (owner does it at claude.ai from the dump).
- Admin UI / export tooling (manual SQL dump for now).
