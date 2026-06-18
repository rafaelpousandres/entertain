# Specification 015 — Minor polish batch

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read CLAUDE.md before starting. A batch of small, independent fixes
> accumulated during validation. Group them in one branch / one release.

---

## 1. Optional time on the order's needed-by date

`orders.needed_by_date` (type `date`) is the active order delivery/needed-by
field. The user wants to optionally attach a **time**: an order can specify
just a date, or a date **and** a time.

**Model (Option B — separate nullable time field)**:
- Add `orders.needed_by_time` — type `time`, nullable.
- `needed_by_date` stays as is. The **nullability of `needed_by_time` is the
  flag**: null → date only; set → date + time. No extra boolean.

**UI**: where the needed-by date is set, add an **optional** time control
(e.g. an "Add time" affordance / a time picker that can be left empty).
Leaving it empty stores null.

**Message**: the supplier message includes the time when present:
- with time → "… 20 June at 13:00" (localised format, ca/es/en);
- without → "… 20 June" (current behaviour).

## 2. Rebost: no "Cap proveïdor" label

The Rebost (pantry) category shows "Cap proveïdor" in the Suppliers list,
which wrongly suggests a supplier can/should be added. The Rebost is
special — it holds things already at home; the supplier concept does not
apply (its supplier config is already hidden elsewhere). 

Change: for the Rebost category, do **not** show "Cap proveïdor". Either omit
the supplier summary line entirely for Rebost, or show a text that reflects
"no orders / things you already have at home" (ca/es/en). Implementer picks
the cleaner of the two; flag if unsure.

## 3. Splash duration

The native splash currently shows for a fraction of a second (the app loads
fast). Make the logo visible for a **minimum of ~1 second** before the app
content appears. Keep it subtle; do not artificially delay much beyond 1s.

## 4. Remove dead column `orders.delivery_deadline`

`orders.delivery_deadline` (type `text`) is dead: always null, superseded by
`needed_by_date`. Drop it.

This is a **destructive migration** (DROP COLUMN), but the column is empty
(no data lost). Per house rule, **show the migration before push** and apply
consciously. Confirm in the plan that nothing in the codebase reads or writes
`delivery_deadline` before dropping it.

**Keep (do not touch)**: `orders.message_header`, `orders.message_footer`
(latent per-order message override), `ingredients.package_equiv_unit_id`
(latent, may be needed by the future URL importer). These are intentionally
empty, not dead.

---

## 5. Acceptance criteria

1. Migration: adds `orders.needed_by_time` (time, nullable); drops
   `orders.delivery_deadline`. Shown before push. The add is additive; the
   drop is on an empty column.
2. Order UI lets the user optionally set a time alongside the needed-by date;
   empty time stores null.
3. Supplier message shows date+time when time is set, date only otherwise;
   localised ca/es/en.
4. Rebost no longer shows "Cap proveïdor".
5. Splash logo visible ~1s minimum.
6. No code references `delivery_deadline` after the drop.
7. flutter analyze clean; flutter test passes; a test for the message
   date/time formatting (with and without time).

## 6. Notes

- New i18n strings (time-related, any Rebost text) in ca/es/en.
- Migration mixes one additive change and one drop; keep both in a single
  migration file, clearly commented.

Branch: `feat/spec-015-minor-polish`.
