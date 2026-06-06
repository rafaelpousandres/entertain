-- Specification 006 — Fixes §2.3
-- A unit may be flagged "omitted from display": when an ingredient line uses
-- such a unit, the supplier-message composer renders the line without the unit
-- and without the "de" connector ("3 ous", not "3 unitats de ous"). Modelling
-- this as a flag (rather than special-casing the composer) lets future units be
-- suppressed the same way without code changes.

alter table public.units
  add column omit_in_display boolean not null default false;

-- The generic countable unit (code 'unit', magnitude 'count', displayed as
-- "unitat(s)") is the placeholder for pieces/items; suppress it from message
-- text so countable ingredients read as natural Catalan.
update public.units set omit_in_display = true where code = 'unit';
