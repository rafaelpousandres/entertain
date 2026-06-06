-- Specification 007 — Fixes round 2 §2.3: add a "Compartir" (share) preferred
-- channel for supplier categories.
--
-- Until now the preferred channel was WhatsApp, Email, or null ("Cap" — no
-- channel configured). A null channel already falls back to the OS share sheet
-- at dispatch time, but "Cap" (not configured) and an explicit "Compartir"
-- choice are semantically different preferences and must be storable apart.
--
-- Extend the message_channel enum with a third value `share`. This is purely
-- additive: existing nulls keep meaning "Cap", and existing 'whatsapp' /
-- 'email' rows are untouched. No data migration is needed.
--
-- Note: `add value` cannot run inside the same transaction that later *uses*
-- the new value; this migration only declares it, so it is safe on its own.

alter type public.message_channel add value if not exists 'share';
