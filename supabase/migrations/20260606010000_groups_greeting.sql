-- Specification 005 — Fixes round 2 §2.1: persist the outgoing-message greeting.
--
-- The first round of fixes made the supplier message privacy-aware but left it
-- with no greeting, so it opened abruptly with the needed-by date line. The
-- greeting is group-level configuration, exactly like the signature added in
-- the previous round, so it lives on `groups` as a parallel column and the two
-- are edited together as a coherent pair in Settings.
--
-- Nullable on purpose, with three meaningful states the client distinguishes:
--   * NULL  — never set; the client seeds the localised default ("Hola," in
--             Catalan) the first time Settings is shown.
--   * ''    — explicitly cleared by the user; no greeting line is emitted.
--   * text  — the user's greeting, inserted at the very start of the message.
alter table public.groups
  add column greeting text;
