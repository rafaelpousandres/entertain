-- Specification 008 — §2.3: a free-text name for the concrete supplier behind
-- a category.
--
-- The per-category detail screen already configures a channel, a phone and an
-- email — all of which implicitly belong to a *specific* supplier (the user's
-- chosen fishmonger "Peixos Samba", say) — but there was nowhere to record that
-- supplier's name. The category label ("Peixateria") is shared system content;
-- the concrete supplier name is per-group state, so it lives on the companion
-- `group_supplier_settings` table next to the channel/address, not on the
-- shared `supplier_categories` row.
--
-- Nullable, defaults to NULL for every existing row: a category keeps working
-- without a supplier name, and the value is independent per group (different
-- groups can name the same shared category differently). The Rebost category
-- (the user's own pantry) has no contact details, so the UI hides this field
-- for it; nothing here enforces that — it is purely presentational.
alter table public.group_supplier_settings
  add column supplier_name text;
