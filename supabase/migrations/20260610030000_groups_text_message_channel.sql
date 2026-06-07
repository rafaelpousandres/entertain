-- Specification 008 — §2.9: a group-level "text message channel" setting.
--
-- The supplier dispatch's "text" channel has so far meant WhatsApp specifically.
-- In some regions SMS is the norm instead. This makes the underlying app a
-- group preference: when a supplier category's preferred channel is the text
-- channel, the dispatch resolves at send time to SMS or WhatsApp based on this
-- column. The chat-bubble icon shown in the UI is unchanged — it represents
-- "text message" regardless of which app the group has configured.
--
-- Group-level configuration, so it lives on `groups` alongside `signature` and
-- `greeting`. Default 'whatsapp' preserves the current behaviour for every
-- existing group with no data migration needed. A CHECK constraint keeps the
-- value to the two supported channels; new values (Line, WeChat, Telegram,
-- Signal) are out of scope for this round but can be added by widening the
-- constraint later without touching existing data.
--
-- The per-supplier `message_channel` enum keeps its `whatsapp` value
-- (deliberately not refactored to a generic `text` this round — see Spec §3);
-- it is now read as "use the group's configured text channel".
alter table public.groups
  add column text_message_channel text not null default 'whatsapp'
    check (text_message_channel in ('sms', 'whatsapp'));
