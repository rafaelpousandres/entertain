-- Specification 005 — shopping lists and supplier messages.
--
-- Extends the Phase 0 shopping schema so an event's menu can be turned into
-- per-supplier orders and sent through a configured channel. Three pieces:
--
--   1. Per-group, per-category messaging configuration (channel + address).
--   2. The metadata of an actual send, captured on each `orders` row.
--   3. A group-level signature appended to every outgoing message.
--
-- Structural decisions taken here (left open by the Spec, see PR body):
--
--   * `supplier_categories` is system-shared content (the built-in
--     categories carry `group_id` null and `is_system` true, readable by
--     everyone, writable only by the service role). Per-group configuration
--     must NOT live on those shared rows, so it goes in the companion table
--     `group_supplier_settings(group_id, supplier_category_id, channel,
--     channel_address)` rather than as nullable columns on the shared table.
--   * The signature is group-scoped configuration, so it lives on `groups`
--     alongside the rest of the group-level config (its UI default falls
--     back to `profiles.display_name`, resolved in the client).
--   * `orders` loses its `unique (event_id, supplier_category_id)`
--     constraint: Spec §2.4 requires *multiple* successive orders per
--     (event, category) as the menu grows between sends.

-- 1. Channel enum -------------------------------------------------------
-- Shared by the per-category configuration and the send metadata. A proper
-- enum keeps it consistent with the codebase's enum-typed columns.
create type public.message_channel as enum ('whatsapp', 'email');

grant usage on type public.message_channel to anon, authenticated;

-- 2. Per-group, per-category messaging configuration --------------------
-- One row per (group, category) the group has configured. Both the channel
-- and the address are nullable: a row may exist with channel 'none' (null)
-- yet keep a previously typed address, and vice versa.
create table public.group_supplier_settings (
  id                    uuid primary key default gen_random_uuid(),
  group_id              uuid not null references public.groups(id)             on delete cascade,
  supplier_category_id  uuid not null references public.supplier_categories(id) on delete cascade,
  channel               public.message_channel,
  channel_address       text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  unique (group_id, supplier_category_id)
);

create index group_supplier_settings_group_id_idx
  on public.group_supplier_settings (group_id);
create index group_supplier_settings_category_id_idx
  on public.group_supplier_settings (supplier_category_id);

create trigger trg_group_supplier_settings_updated_at
  before update on public.group_supplier_settings
  for each row execute function public.set_updated_at();

-- RLS: group-scoped like every other user-data table (data model §4).
alter table public.group_supplier_settings enable row level security;

create policy group_supplier_settings_all on public.group_supplier_settings
  for all to authenticated
  using      (public.is_group_member(group_id))
  with check (public.is_group_member(group_id));

grant select, insert, update, delete
  on table public.group_supplier_settings
  to anon, authenticated;

-- 3. Send metadata on orders --------------------------------------------
-- Nullable: an order materialised before this Spec, or any future draft,
-- has not been sent. They are set together at send time (Spec §2.4).
alter table public.orders
  add column sent_at      timestamptz,
  add column sent_channel public.message_channel,
  add column sent_address text;

-- Spec §2.4: a single (event, category) may accumulate several orders as
-- the user adds more items between sends. Drop the one-per-pair constraint
-- that the Phase 0 migration created inline.
alter table public.orders
  drop constraint if exists orders_event_id_supplier_category_id_key;

-- 4. Group signature ----------------------------------------------------
-- Group-level configuration; the client defaults an empty value to the
-- owner's profiles.display_name when first shown.
alter table public.groups
  add column signature text;
