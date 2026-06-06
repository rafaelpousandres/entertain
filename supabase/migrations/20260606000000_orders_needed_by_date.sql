-- Specification 005 — Fixes §2.6: persist the user's needed-by date.
--
-- The supplier message screen lets the user pick the date by which they need
-- the goods (Fixes §2.5). That date is the only one shared with the supplier;
-- the event's own date is private and no longer leaks into the message. We
-- persist the chosen value on the order so the send is a faithful record of
-- what was promised.
--
-- Nullable: a needed-by date is optional (it defaults to the day before the
-- event in the UI, but the user may clear it), and orders materialised before
-- this migration have none.
alter table public.orders
  add column needed_by_date date;
