-- Specification 013 — Supplier selection at purchase.
--
-- Makes the purchase flow supplier-aware. Until now `group_supplier_settings`
-- held at most ONE row per (group, category) — the Spec 005 table shipped a
-- `unique (group_id, supplier_category_id)` constraint that was never dropped,
-- so the whole stack (model, providers, settings UI, message composer) assumed
-- one supplier per category. This Spec turns it into N suppliers per category
-- with one marked default, and starts recording the chosen supplier on orders.
--
-- Structural decisions (Spec §2.1 left the model choice to the implementer):
--
--   * The default lives on `group_supplier_settings` as a boolean `is_default`
--     (Option b), NOT as an FK on `supplier_categories` (Option a). The system
--     supplier categories are SHARED content (one "Butcher" row for every
--     group, `group_id` null / `is_system` true), so a per-group default cannot
--     live on them. `group_supplier_settings` is the only per-group home for it.
--   * A PARTIAL unique index enforces "at most one default per (group,
--     category)" at the database level — cleaner than app-only enforcement.
--   * `orders.supplier_id` (a dormant, always-null `uuid` with no FK since
--     Phase 0) is repurposed to point at the chosen `group_supplier_settings`
--     row, with `on delete set null` so deleting a supplier never orphans
--     historical orders (which already snapshot `sent_channel` / `sent_address`).
--
-- Additive and non-destructive: dropping a uniqueness constraint and adding a
-- nullable column / index / FK touches no row data. The destructive-migration
-- stop does not apply; the file is still shown to the owner before `db push`.

-- 1. Allow several suppliers per (group, category) -----------------------
-- Drop the one-per-pair uniqueness from Spec 005. `if exists` keeps this
-- idempotent and safe whether or not the constraint is still present.
alter table public.group_supplier_settings
  drop constraint if exists group_supplier_settings_group_id_supplier_category_id_key;

-- 2. Mark the default supplier per category ------------------------------
alter table public.group_supplier_settings
  add column is_default boolean not null default false;

-- 3. Backfill: the existing sole row of each (group, category) becomes its
-- default — EXCEPT truly-empty rows. The exclusion predicate is the exact
-- complement of the §2.5 manual cleanup DELETE (rows with no name, no channel
-- and no addresses), so a soon-to-be-deleted empty row is not made default,
-- while an unnamed-but-channel-configured supplier still becomes the default.
-- `distinct on` guards against the unlikely case of pre-existing duplicates
-- (it would mark only one per pair, keeping the partial index in §4 valid).
update public.group_supplier_settings g
  set is_default = true
  from (
    select distinct on (group_id, supplier_category_id) id
    from public.group_supplier_settings
    where supplier_name   is not null
       or channel         is not null
       or phone_address   is not null
       or email_address   is not null
    order by group_id, supplier_category_id, created_at
  ) keep
  where g.id = keep.id;

-- 4. Enforce at most one default per (group, category) -------------------
create unique index group_supplier_settings_default_per_category
  on public.group_supplier_settings (group_id, supplier_category_id)
  where is_default;

-- 5. Record the chosen supplier on the order -----------------------------
-- The column has existed since Phase 0 but was always null and unconstrained.
-- Point it at the concrete supplier; `set null` on delete preserves order
-- history (the contact is also snapshotted on the order itself).
alter table public.orders
  add constraint orders_supplier_id_fkey
  foreign key (supplier_id) references public.group_supplier_settings(id)
  on delete set null;
