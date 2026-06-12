-- Specification 010 §2.6 — drop the unused `events.status` column.
--
-- `events.status` (enum planning / confirmed / done) has been dead since Spec
-- 008 §2.4, when event status (in_preparation / ready / past) became a value
-- *derived* at the UI layer from the event date and its ingredient states. The
-- column was never read or written after that. Spec 010 removes the app's last
-- residual references (the Event model field, its selectColumns, and the
-- vestigial EventStatus enum / formatter) and this migration drops the column
-- so the schema matches.
--
-- Irreversible (the planning/confirmed/done values are discarded), but the data
-- carried no meaning the app uses — the derived status fully replaces it.
--
-- The `event_status` enum type itself is intentionally left in place: dropping
-- it is a separate concern and the type is harmless once unreferenced. (It can
-- be removed in a later cleanup if desired.)

alter table public.events drop column if exists status;
