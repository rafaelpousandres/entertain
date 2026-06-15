# Specification 012 — Branding, in-app help, and usability improvements

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read CLAUDE.md, the Data model, and prior specs (esp. 008–011 for the
> shopping accordion, state grouping, and event/menu structure) before
> starting. This round comes from real-use testing and focuses on
> discoverability (branding, help) and consistency (accordions everywhere,
> serving totals). No schema changes.

---

## 1. Goal

Testing surfaced that (a) the logo never appears inside the app, (b) new
users have no onboarding, and (c) the accordion pattern proven in the
shopping panel (Spec 011) reads well and should be applied consistently to
Menu, Dishes, and Ingredients. This Spec also adds serving totals to the
Menu view, which real use showed are needed to sanity-check quantities
against guest count.

Eight items, all UI-layer. No database migrations.

---

## 2. Scope

### 2.1 Logo in the app

The brand logo currently appears nowhere inside the app. Add it in two
places:

- **Settings ▸ General ▸ Entertain card**: the existing app-info card shows
  the logo prominently (alongside app name/version).
- **Settings header**: the logo appears in the header area of the Settings
  screen (small, tasteful — not competing with the section content).

Logo assets are available in the repo / project (the same source used for
the launcher icon and feature graphic). Use an appropriately-sized raster
or vector. Respect the design system spacing.

### 2.2 Splash screen logo

Add the logo to the app's launch/splash screen so it shows briefly on app
start. Use `flutter_native_splash` (or the existing splash mechanism if one
is configured). Keep it simple: logo centered on the app's background
color. Light/dark variants if the design system defines them.

### 2.3 Getting Started card (Settings ▸ General)

Add a telegraphic onboarding card in **Settings ▸ General**, translated to
all three languages (ca/es/en). Keep it **very brief** — the app's
usability does the rest. Content (final wording to be polished, this is the
substance):

> **Getting started**
> 1. Create an event (set type, format, date, guests).
> 2. Create your ingredients and dishes in the catalogs.
> 3. Add dishes to the event's menu.
> 4. Dishes added to an event can be edited without changing the catalog
>    dish — each event keeps its own copy.
> 5. The Shopping tab groups everything to buy by supplier.

Telegraphic, scannable. No long paragraphs. Translate the substance, don't
translate word-for-word if another phrasing reads more naturally per
language.

### 2.4 Per-screen help icon (info pop-up)

Next to the main title of each primary screen, add a small info/help icon.
Tapping it shows a short pop-up (dialog or bubble) with the basic
instructions for that screen.

Screens to cover (the primary ones with a title):
- Events list
- Event detail (Event / Menu / Shopping — one help per tab, or one for the
  screen; implementer's call, but the Shopping help should mention supplier
  grouping and states)
- Dishes catalog
- Ingredients catalog
- Settings (optional — the Getting Started card may suffice here)

Each help text is short (2–4 lines), telegraphic, translated to ca/es/en.
Reuse a single reusable `HelpIconButton` + pop-up widget across all screens
so the pattern is consistent. The help text per screen comes from ARB keys.

### 2.5 Tester manual (GitHub Pages)

Create a short tester manual as a public GitHub Pages page (same Jekyll
setup as privacy/delete-data), in **English**, **one to two pages max**.
Location: `docs/manual/index.md` →
`https://rafaelpousandres.github.io/entertain/manual/`.

Content: a slightly fuller version of the Getting Started card — enough for
a tester to understand the app's flow and main concepts (events, catalogs,
menu, shopping by supplier, the catalog-vs-event-copy distinction) without
hand-holding. The in-app Getting Started card is the telegraphic summary;
this page is the fuller version. Don't duplicate effort — this is the same
material, expanded.

Keep it to one page if possible. No screenshots required (but allowed if
trivial to add).

### 2.6 Menu tab: accordion + dish/serving counts + menu totals

Apply the accordion pattern (Spec 011 §2.8 — all collapsed by default, one
open at a time) to the **Menu tab** of an event, where dishes are grouped
by category (Starters, Mains, Desserts, etc.).

**Per-category header** (visible when collapsed) shows:
`{category} · {N} plats · {M} racions`
- **N plats**: number of dishes in that category for this event. Add the
  word "plats"/"platos"/"dishes" after the number (currently only the bare
  number shows).
- **M racions**: sum of the `servings` of the dishes in that category for
  this event.

**Menu totals** — a summary line **above all category panels**, below the
three tabs, before the first category:
`{total dishes} plats · {total racions} racions · {ratio} racions per persona`
- **Total dishes**: sum across all categories.
- **Total racions**: sum of all dishes' servings across all categories.
- **Racions per persona**: total racions ÷ event's guest count, **one
  decimal**, decimal separator per locale (comma for ca/es, point for en).
  If guest count is zero, show the dishes/racions but omit the ratio (avoid
  division by zero).

Translate "plats", "racions", "racions per persona" to ca/es/en.

### 2.7 Dishes catalog: accordion + "plats" label

Apply the accordion pattern to the **Dishes catalog** (grouped by category).
The category header, when collapsed, shows the count **with the word
"plats"** after it: `Starters · 4 plats` (currently just the bare number).

All collapsed by default, one open at a time, consistent with §2.6 and
Spec 011 §2.8.

### 2.8 Ingredients catalog: group by supplier + accordion + count

The Ingredients catalog is currently a flat list. Change it to **group
ingredients by supplier category** (butcher, fishmonger, greengrocer,
supermarket, pantry), in an accordion (all collapsed by default, one open
at a time).

Each supplier-category header shows the count with the word "ingredients":
`Greengrocer · 9 ingredients`.

Grouping key: the ingredient's `default_supplier_category_id`. Ingredients
are sorted within each group (alphabetical, consistent with the current
catalog sort).

---

## 3. Out of scope

No schema changes. No changes to the shopping panel (Spec 011 stands). The
parked items from Spec 011 §3 remain parked. Phase 1 / Phase 2 roadmap
items (stock photos, recipe import, payments, iOS) are not touched here.

---

## 4. Acceptance criteria

1. Logo appears in Settings ▸ General Entertain card and in the Settings
   header.
2. Logo appears on the splash screen at app start.
3. Getting Started card in Settings ▸ General, in ca/es/en, telegraphic.
4. Help icon next to the title of each primary screen; tapping shows a
   short translated pop-up.
5. Tester manual live at `…/entertain/manual/`, English, ≤2 pages.
6. Menu tab: accordion (collapsed default, one open); each category header
   shows `{N} plats · {M} racions`; menu totals line above the panels with
   dishes, racions, and racions/persona (1 decimal, locale separator;
   ratio omitted if guests = 0).
7. Dishes catalog: accordion; category headers show `{N} plats`.
8. Ingredients catalog: grouped by supplier in an accordion; headers show
   `{N} ingredients`.
9. All new strings translated to ca/es/en.
10. flutter analyze clean; tests pass; new tests for the serving-total
    calculation (§2.6) including the guests = 0 case and locale decimal
    formatting.

---

## 5. Notes for the implementer

Suggested order (small → large):
1. §2.1 Logo in Settings (assets + card + header).
2. §2.2 Splash logo.
3. §2.7 Dishes accordion + label (smallest accordion change).
4. §2.8 Ingredients group-by-supplier accordion.
5. §2.6 Menu accordion + counts + totals (the serving math is the only
   non-trivial logic — reuse the shopping accordion widget and the
   number-formatting pipeline from Spec 007/008).
6. §2.3 Getting Started card.
7. §2.4 Per-screen help (reusable HelpIconButton + ARB-driven text).
8. §2.5 Tester manual page (no app code).

Reuse, don't reinvent: the accordion behavior already exists from Spec 011
(§2.8) — generalize it into a shared widget if not already, and apply to
Menu, Dishes, Ingredients. The serving-total formatting reuses the existing
decimal/locale handling.

Branch: `feat/spec-012-branding-help-usability`.

Stop and ask the owner if:
- The logo assets need a variant that doesn't exist (e.g. monochrome for the
  header, or light/dark splash).
- A screen's help text scope is ambiguous (one help per event-detail tab vs
  one for the screen).
