-- Phase 0 — shopping: orders and order_items.
--
-- orders.supplier_id is included as a nullable uuid column without a FK
-- constraint: the `suppliers` table is a Phase 1 entity (per the data
-- model's phased activation table). The Phase 1 migration that creates
-- `suppliers` will add the FK constraint on this column.

create table public.orders (
  id                    uuid primary key default gen_random_uuid(),
  event_id              uuid not null references public.events(id)              on delete cascade,
  supplier_category_id  uuid not null references public.supplier_categories(id) on delete restrict,
  supplier_id           uuid,
  delivery_deadline     text,
  message_header        text,
  message_footer        text,
  status                public.order_status not null default 'draft',
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  unique (event_id, supplier_category_id)
);

create index orders_event_id_idx              on public.orders (event_id);
create index orders_supplier_category_id_idx  on public.orders (supplier_category_id);
create index orders_supplier_id_idx           on public.orders (supplier_id);

create trigger trg_orders_updated_at
  before update on public.orders
  for each row execute function public.set_updated_at();

-- order_items ------------------------------------------------------------
-- ingredient_id is nullable because the model preserves a name snapshot
-- and the catalog row may be deleted afterwards.
create table public.order_items (
  id              uuid primary key default gen_random_uuid(),
  order_id        uuid not null references public.orders(id) on delete cascade,
  ingredient_id   uuid references public.ingredients(id)     on delete set null,
  ingredient_name text not null,
  quantity        numeric not null,
  unit_id         uuid not null references public.units(id)  on delete restrict,
  prep_note       text,
  status          public.order_item_status not null default 'pending',
  sort_order      integer not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index order_items_order_id_idx       on public.order_items (order_id);
create index order_items_ingredient_id_idx  on public.order_items (ingredient_id);
create index order_items_unit_id_idx        on public.order_items (unit_id);

create trigger trg_order_items_updated_at
  before update on public.order_items
  for each row execute function public.set_updated_at();
