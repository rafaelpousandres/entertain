# entertain — Design system

> Draft for review and approval. Version 0.4.
> Derived from visual direction **A** (warm). Light theme. Scope: MVP. This is the
> single reference for all mockups and, later, for implementation.

---

## 1. Personality

Warm and domestic, like a cookbook. Cream paper background, a serif for titles,
a terracotta accent, and soft cards with rounded corners. A calm, welcoming tone,
free of visual noise.

---

## 2. Color

Light theme (the only one in the MVP). The identifiers are token names; a dark
theme is out of scope for the MVP, but the token structure allows adding one
later.

Two accents with distinct roles: **terracotta** (`accent`) is the color of
primary actions; **teal** (`accent-secondary`) is the secondary and contrast
accent, applied consistently across the whole app (category headers, icon
circles, selected states, secondary buttons). Terracotta always owns the screen's
primary action.

| Token | Hex | Use |
|---|---|---|
| `bg` | `#FBF5EA` | App background (cream). |
| `surface` | `#FFFFFF` | Cards, list rows, sheets. |
| `surface-soft` | `#F3E7CF` | Icon circles, soft fills, neutral pills. |
| `border` | `#EDE2CC` | Card borders and separators. |
| `text-primary` | `#412402` | Titles and primary text. |
| `text-secondary` | `#8A7256` | Metadata, supporting text. |
| `text-tertiary` | `#A8946F` | Hints, tertiary text. |
| `accent` | `#D85A30` | Primary actions (buttons). |
| `accent-strong` | `#993C1D` | Pressed state of the primary accent. |
| `on-accent` | `#FFF6EE` | Text and icons on `accent`. |
| `accent-secondary` | `#0F6E56` | Secondary accent (teal): category icons, selected states, secondary actions. |
| `accent-secondary-soft` | `#E1F5EE` | Soft teal fill: icon badges, icon circles. |
| `disabled` | `#CDBC97` | Inactive elements, chevrons. |
| `success` | `#3B6D11` | "Bought" state. |
| `warning` | `#BA7517` | Warnings, attention. |
| `danger` | `#A32D2D` | "Out of stock" state, errors. |

---

## 3. Typography

Two families:

- **Serif (display)** — event and screen titles: **Fraunces**.
- **Sans (body)** — everything else: **Nunito Sans**.

Scale:

| Style | Family | Size | Weight |
|---|---|---|---|
| Display | Serif | 24 px | 400 |
| Section title | Serif | 20 px | 400 |
| List item / body | Sans | 15 px | 400 |
| Label | Sans | 13 px | 500 |
| Secondary / caption | Sans | 12–13 px | 400 |
| Button | Sans | 15 px | 500 |

Two weights: regular (400) and medium (500). Always sentence case (never title
case or small caps). Minimum size 12 px.

---

## 4. Spacing and shape

- **Spacing scale:** 4, 8, 12, 16, 20, 24, 32 px.
- **Screen margin:** 16–20 px horizontal.
- **Corner radius:** card 14 px · button and field 12 px · pill and icon circle
  full.
- **Borders:** 1 px, color `border`. No shadows or gradients.

---

## 5. Components

- **Screen structure:** `bg` background; top bar (header) and bottom action bar
  are **fixed**; only the central content scrolls. The bottom bar's primary
  action is always accessible.
- **Card / list row:** `surface`, 1 px `border`, radius 14, padding 11–13 px.
  Content: optional leading element (icon), primary + secondary text, trailing
  chevron.
- **Primary button:** `accent` fill, `on-accent` text, radius 12, height ~48 px,
  icon + label; full width in action bars.
- **Secondary button:** 1 px `accent-secondary` outline, transparent
  background, `accent-secondary` text.
- **Section header:** category icon badge (`accent-secondary-soft` background,
  `accent-secondary` icon) + label (`accent-secondary`, weight 500) + optional
  count. It is **collapsible**: tapping it folds or unfolds the category
  (chevron up = expanded, down = collapsed). Applies to the dish catalog, the
  ingredient catalog, and an event's menu.
- **Icon circle (header actions):** 34 px, `accent-secondary-soft` background,
  `accent-secondary` icon.
- **Selection control:** circle — empty with `disabled` border when not
  selected; filled `accent-secondary` with a white check mark when selected.
- **Form field:** `surface` background, 1 px `border`, radius 12, label above in
  `text-secondary`.
- **Status chip (shopping list):** small pill — pending (neutral), bought
  (`success`), out of stock (`danger`).

---

## 6. Iconography

- Outline style. Recommendation: **Material Symbols Outlined**, native to
  Flutter (no external dependency).
- Category → icon mapping (concept; exact names fixed at implementation):
  aperitif → cheese · starters → salad · main → kitchen utensils · dessert →
  cake · drinks → glass · other → cutlery.

---

## 7. Notes

- **Typographic families:** confirmed — Fraunces (display) and Nunito Sans
  (body).
- **Dark theme:** out of scope for the MVP.
- When development begins, this system is propagated to the repository as a
  Flutter theme (design tokens) and reflected in `CLAUDE.md`.
