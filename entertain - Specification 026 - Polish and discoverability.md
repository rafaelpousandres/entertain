# Spec 026 — Polish & discoverability

Branch: `feat/spec-026-polish-discoverability` · One PR · Migration shown before `db push`.
One coherent pass (no atomizing). Groups four items: a tips/hints screen on entry (content stored
in the DB, editable without rebuilding), a localized splash slogan, dietary badges in the catalog,
and two clean-ups (dead code + orphan translations).

## Context

The app now has rich functionality (specs 020–025) but much of it is **undiscovered** by users.
This pass improves discoverability and visual clarity, and clears two small debts left from 025:

- **Hints on entry** — a friendly, dismissable tips screen shown once each time the app opens,
  teaching real features. Content lives in the **database**, so hints can be edited/added without
  shipping a new build.
- **Localized splash slogan** — the tagline follows the app locale (ca/es/en).
- **Dietary badges** — show each ingredient's/dish's dietary classification in the catalog with a
  compact symbol (VGN / VGT / gluten-free), full text on detail.
- **Clean-ups** — remove the dead `menu_add_target.dart` (+ its test); sweep orphan `translations`
  rows left when an entity is deleted.

---

## Part A — Hints on entry

### A.1 Storage — DB-backed (editable without a rebuild)

A new `hints` table holds the hint set; the multilingual text reuses the existing `translations`
infrastructure (the same merge pattern as catalog names, Spec 025), so each hint has ca/es/en.

- `hints` columns: `id uuid pk`, `key text unique` (stable identifier, e.g. `photos`,
  `ai_recipe`), `kind text` (`welcome` | `tip`, default `tip`), `created_at`.
- Hint **text** per locale: store via the `translations` table (add `'hint'` to the
  `translation_entity_type` enum; `field = 'text'`), exactly like catalog entities. The client
  merges `translation[appLocale] ?? translation[ca]` (fallback to Catalan).
- **Seed migration** loads the initial set (the tips + 1 welcome, see A.5) as rows + their three
  translations. After that, hints are editable directly in the DB (insert/edit/delete a row + its
  translations) — no app rebuild needed.
- **RLS:** read-only for all (`anon, authenticated`); no client writes. Grant `select` to
  `anon, authenticated`. (Editing is done by Rafael directly in the DB / dashboard.)
- No `active` flag and no activation workflow (deliberately simple — the app is in internal
  testing, and the upcoming features ship shortly, so a hint briefly preceding its feature is
  harmless). At the public-production step, simply don't seed hints for features not yet live in
  that channel.

### A.2 Behaviour

- Shown **once per app open**, over the home, as a dismissable card/sheet (NOT the splash — the
  splash stays brief; this is a separate surface on entry).
- **One hint per open**, chosen **at random** from the `tip` hints.
- **First-ever open:** show the **welcome** hint first (`kind = 'welcome'`), not a random tip.
- A **"Més…"** link/arrow advances to another hint (random next) so the user can browse more before
  closing — including from the welcome hint (it must not be a dead end).
- A **close** button (X / "Entesos") dismisses the screen for this session.
- A **checkbox "No mostrar més pistes"** on the screen sets a persistent preference (default ON =
  hints shown). When OFF, the screen never appears on open.
- The same preference is **re-settable from Settings** (a toggle "Mostra pistes en obrir",
  default ON), so a user who turned them off can turn them back on.

### A.3 Tone

Hints use a warm, inviting voice — **"Sabies que…"** / **"Recorda que…"**, never the imperative.
(e.g. *"Sabies que pots demanar a l'IA que et munti un menú sencer?"* rather than *"Munta un menú
amb IA"*.) The welcome hint is a friendly greeting that points to the catalog as the starting
point.

### A.4 Client

- Data layer `lib/features/hints/`: `Hint{id,key,kind,text}` model with `selectColumns` + locale
  merge (reuse the `_translationNames`-style helper); repository `listActiveHints(localeCode)`;
  a provider `hintsProvider.family<…, String>` keyed by locale.
- Preference: a persisted bool `hintsEnabled` (default true) via the existing local-prefs mechanism
  (same as other app settings); exposed to the entry screen and to Settings.
- UI: `HintsOnEntry` surface shown from the home's init when `hintsEnabled` and not yet shown this
  session; picks welcome-first-ever-then-random; "Més…" advances; close + checkbox wired.
- Settings: add the "Mostra pistes en obrir" toggle.
- Session guard: a simple in-memory "already shown this session" flag so it appears once per open,
  not on every navigation back to home.

### A.5 Seed hint set (≥ 20 tips + welcome) — ca (es/en filled to match)

Welcome: *"Benvingut a Entertain! Comença pel catàleg —és la base de tot. Toca «Més…» per descobrir
què pots fer."*

Tips (final wording polished at build; es/en are faithful translations):
1. Sabies que pots afegir fotos als plats, begudes i ingredients, des de les teves o d'un banc de fotos en línia?
2. Sabies que, si no tens la recepta, pots demanar-la a l'IA i t'afegeix el plat amb els ingredients automàticament?
3. Sabies que l'IA et pot muntar un menú sencer? Respon unes preguntes i te'l proposa.
4. Recorda que pots marcar els ingredients com a vegà, vegetarià o sense gluten —els plats ho hereten.
5. Sabies que pots filtrar el catàleg per dieta o per cuinat/comprat?
6. Sabies que pots portar la llista de convidats de cada esdeveniment, amb els seus estats?
7. Recorda que pots enviar les invitacions per WhatsApp, SMS o correu, directament des de l'app.
8. Sabies que pots afegir convidats des dels contactes del telèfon, sense escriure'ls a mà?
9. Sabies que pots afegir proveïdors des dels contactes del telèfon?
10. Sabies que pots enviar la comanda a cada proveïdor amb un missatge ja preparat?
11. Recorda que la llista de la compra es genera sola, agrupada per proveïdor.
12. Sabies que els noms de plats, begudes i ingredients es tradueixen sols al català, castellà i anglès?
13. Sabies que Entertain ajusta les quantitats segons el nombre de comensals?
14. Recorda que pots crear plats comprats fets, no només cuinats a casa.
15. Sabies que pots editar qualsevol plat que l'IA t'ha creat, com qualsevol altre?
16. Recorda que pots posar una foto també als ingredients, no només als plats.
17. Sabies que pots reutilitzar tot el catàleg a tots els esdeveniments, sense tornar a començar?
18. Sabies que Entertain t'avisa si confirmes més convidats dels que havies previst?
19. Recorda que pots escriure i editar el text de la invitació abans d'enviar-la.
20. Sabies que pots triar el format de racions (individual o per compartir) a cada esdeveniment?
21. Sabies que a cada pantalla tens la icona ? amb explicacions?
22. Sabies que pots desactivar aquestes pistes quan vulguis, i tornar-les a activar des de Configuració?
23. Sabies que pots afegir articles extra a la llista de la compra, a més dels que surten dels plats?
24. Sabies que una categoria de proveïdor pot ser una botiga, una parada de mercat o una secció del supermercat —com tu organitzis les teves compres?
25. Sabies que pots posar fotos també als teus esdeveniments?
26. Sabies que pots generar un document resum d'un esdeveniment, amb tots els plats, receptes i convidats, per imprimir o compartir?
27. Sabies que la pantalla de compra té un mode pensat per fer servir al supermercat, marcant el que ja tens?

---

## Part B — Localized splash slogan

The splash shows the slogan in the **app locale**:
- ca: *"La vida és reunir-se al voltant d'una taula"*
- es: *"La vida es reunirse alrededor de una mesa"*
- en: *"Life is gathering around a table"* (the official foodappslab tagline)

Implementation: three i18n strings (app ARB, not the DB — it's a fixed brand line, not editable
content), shown on the splash via `Localizations.localeOf(context)`. Keep the splash brief; this is
just the existing slogan, now localized.

---

## Part C — Dietary badges in the catalog (VGN / VGT / gluten-free)

Show each item's dietary classification as a compact badge in the **ingredient** and **dish**
catalog lists; full text on the detail screen.

### C.1 The symbol (design requirement — to iterate, not assume)

A unified mark that integrates the dietary letters **into a leaf-shaped "V"** (the letters are part
of the symbol, not a separate label beside an icon), for low ambiguity at list size:
- **VGN** = vegan · **VGT** = vegetarian · a **crossed-wheat** mark = gluten-free (the international
  coeliac symbol).

This is a **graphic-design task**: a leaf-V integrating "VGN"/"VGT" must read clearly at small
size. Do **not** ship an improvised, illegible icon — propose 1–2 design options (SVG/asset) for
review and iterate. The crossed-wheat (gluten-free) has a recognised international form; reproduce a
clean version. Badges use the app's green/orange palette where appropriate.

### C.2 Where & rules

- **Ingredient list:** badge from the ingredient's own `diet` / `gluten_free` (Spec 025 fields).
- **Dish list:** badge from the dish's **effective** dietary status (derived from ingredients, or
  manual for ingredient-less dishes — Spec 025 logic).
- **Only positive, known classifications show a badge:** vegan → VGN; vegetarian → VGT; gluten-free
  → wheat mark. `unknown` and `none` show **no badge** (no clutter, no false signal).
- A dish that is vegan shows VGN only (not VGT too — vegan implies vegetarian; one badge, the
  strongest).
- **Detail screen:** show the full text ("Vegà", "Vegetarià", "Sense gluten") so the compact badge
  is always backed by a clear label.

### C.3 Client

- A small reusable `DietaryBadges(diet, glutenFree)` widget rendering the symbol(s) from assets.
- Catalog list rows (ingredient + dish) embed it; detail screens show the text form.
- Pure helper `dietaryBadgesFor(diet, glutenFree)` → which badges to show (tested: vegan→[VGN],
  vegetarian→[VGT], gluten-free adds wheat, unknown/none→[]).

---

## Part D — Clean-up: remove dead `menu_add_target.dart`

Spec 025 replaced the adaptive add-button logic; `menu_add_target.dart` (and `menu_add_target`'s
test) became dead code, left in place to avoid out-of-scope deletion. Remove both now. Confirm no
remaining references before deleting; `flutter analyze` + tests stay green.

---

## Part E — Clean-up: sweep orphan translations

`translations` is polymorphic (no FK to `entity_id`), so deleting an ingredient/dish/drink leaves
its translation rows orphaned (noted in 025's `deleteIngredient`). This pass:

1. **One-off sweep** of existing orphans: a guarded SQL/maintenance step that deletes
   `translations` rows whose `entity_id` no longer exists in the matching entity table (per
   `entity_type`). Show the SQL (with a pre-count) before running; run once.
2. **Prevent new orphans:** on entity delete, the repository also deletes that entity's translation
   rows (best-effort, same transaction or immediately after), so future deletes don't accumulate
   orphans. (Keep it simple; `translations` has no cascade, so this is an explicit delete.)

---

## Data — migration `supabase/migrations/<ts>_hints.sql`

```sql
-- Hints catalog (content; text lives in translations)
create table public.hints (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  kind text not null default 'tip' check (kind in ('welcome','tip')),
  created_at timestamptz not null default now()
);
alter table public.hints enable row level security;
create policy hints_read on public.hints for select to anon, authenticated using (true);
grant select on table public.hints to anon, authenticated;

-- Hints join the i18n model
alter type public.translation_entity_type add value if not exists 'hint';

-- (separate migration / after enum commit) seed rows + their ca/es/en translations
```

(The enum `add value 'hint'` is its own statement, committed before any seed that uses it — same
pattern as Spec 020's `'dish'` and 025's `'drink'`.) The **seed** (hint rows + translations) goes in
a following migration so it can use the new enum value. **service_role grant audit:** no Edge
Function touches `hints`; the seed is plain SQL → no `service_role` grant needed.

---

## i18n (ca/es/en) — `lib/l10n/app_{ca,es,en}.arb`

Splash slogan (3 locales); Settings toggle label ("Mostra pistes en obrir"); hints-screen chrome
("No mostrar més pistes", "Més…", "Entesos"); dietary full-text labels for detail
("Vegà"/"Vegetarià"/"Sense gluten") if not already present. Hint **bodies** are NOT in ARB — they
live in the DB. Run `flutter gen-l10n`.

## Tests

- `dietaryBadgesFor`: vegan→[VGN]; vegetarian→[VGT]; gluten-free adds wheat; vegan+gluten-free→
  [VGN, wheat]; unknown/none→[].
- Hint locale merge: returns app-locale text, falls back to ca.
- Hint selection: first-ever → welcome; subsequent → random tip; `hintsEnabled=false` → screen
  suppressed.
- Settings toggle round-trips the persisted preference.
- Orphan-sweep helper (pure, over a faked set) deletes only rows with no matching entity.
- widget: dietary badge renders on a catalog row; hints screen "Més…" advances and close dismisses.

## Verification

1. `flutter gen-l10n` + `flutter analyze` + `flutter test` green.
2. Show the hints migration + seed; on approval `supabase db push`. Run the orphan-translations
   sweep SQL once (after showing the pre-count).
3. On the Pixel 8 Pro: on first open after install, the **welcome** hint shows, with "Més…" to
   browse; on later opens, a **random** tip shows once per open; the **checkbox** hides them and
   **Settings** turns them back on. The **splash slogan** shows in the device language (switch
   language to verify). **Dietary badges** appear on ingredient and dish lists (VGN/VGT/wheat),
   only for positive/known classifications, with full text on detail. Editing a hint row in the DB
   changes what the app shows (no rebuild).

## Out of scope (this pass)

Hints analytics / per-hint dismissal; admin UI for editing hints (done directly in the DB);
animated splash; dietary badges on drinks (drinks' dietary set stays parked); any change to the
025 dietary model.
