-- Specification 007 — Fixes §2.1: phone and email as separate fields on the
-- per-group supplier category configuration.
--
-- Until now `group_supplier_settings` stored a single `channel_address` whose
-- meaning depended on `channel` (WhatsApp → phone, Email → email). That forced
-- the user to keep only one of the two for a given category. This splits the
-- address into two dedicated columns so both can be recorded; `channel` keeps
-- its meaning as the *default* outgoing channel and the composer picks the
-- address that matches it.

alter table public.group_supplier_settings
  add column phone_address text,
  add column email_address text;

-- Migrate existing rows: route the single stored address into the column that
-- matches the row's current channel. Rows with channel null (none) keep their
-- previously typed address as the phone number — the most common case for a
-- WhatsApp-first user who had not yet picked a channel.
update public.group_supplier_settings
  set email_address = channel_address
  where channel = 'email' and channel_address is not null;

update public.group_supplier_settings
  set phone_address = channel_address
  where (channel is distinct from 'email') and channel_address is not null;

-- `channel_address` is left in place but deprecated: the application stops
-- reading and writing it (the two new columns are authoritative). Keeping it
-- avoids a destructive drop while the change is validated on device; it can be
-- removed in a later migration once the split is confirmed in production.
comment on column public.group_supplier_settings.channel_address is
  'Deprecated (Spec 007 Fixes §2.1): superseded by phone_address / email_address. No longer read or written by the app.';
