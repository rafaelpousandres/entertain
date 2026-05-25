-- Phase 0 — row-level security.
--
-- Single principle (data model §4): a row is accessible if the user is a
-- member of its group. The helper public.is_group_member(uuid) encodes
-- that check once and is reused by every group-scoped policy.
--
-- System content (units; supplier_categories / ingredients with null
-- group_id; translations; system message template) is readable by any
-- authenticated user and writable only by the service role — which
-- bypasses RLS, so we simply do not create permissive write policies for
-- it here.

-- Helper -----------------------------------------------------------------
-- SECURITY DEFINER lets us read memberships without falling into the same
-- RLS policy that's calling the helper. search_path is pinned for safety.
create or replace function public.is_group_member(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.memberships
    where group_id = p_group_id
      and user_id  = auth.uid()
  );
$$;

revoke all on function public.is_group_member(uuid) from public;
grant execute on function public.is_group_member(uuid) to authenticated, anon;

-- Enable RLS on every public table that holds user data. -----------------
alter table public.groups                  enable row level security;
alter table public.profiles                enable row level security;
alter table public.memberships             enable row level security;
alter table public.events                  enable row level security;
alter table public.units                   enable row level security;
alter table public.supplier_categories     enable row level security;
alter table public.ingredients             enable row level security;
alter table public.dishes                  enable row level security;
alter table public.dish_ingredients        enable row level security;
alter table public.event_dishes            enable row level security;
alter table public.event_dish_ingredients  enable row level security;
alter table public.orders                  enable row level security;
alter table public.order_items             enable row level security;
alter table public.translations            enable row level security;
alter table public.message_templates       enable row level security;
alter table public.media                   enable row level security;

-- groups -----------------------------------------------------------------
-- Members may read and rename their group. Creation happens via the
-- auto-provision trigger (definer-rights, bypasses RLS); deletion is an
-- admin/service-role concern in Phase 0.
create policy groups_select on public.groups
  for select to authenticated
  using (public.is_group_member(id));

create policy groups_update on public.groups
  for update to authenticated
  using      (public.is_group_member(id))
  with check (public.is_group_member(id));

-- profiles ---------------------------------------------------------------
-- A profile is visible if it's the caller's own row, or if it shares a
-- group with the caller (a Phase 2 concern but the policy is written now
-- to match the model's principle).
create policy profiles_select on public.profiles
  for select to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1
      from public.memberships me
      join public.memberships them on me.group_id = them.group_id
      where me.user_id = auth.uid()
        and them.user_id = profiles.id
    )
  );

create policy profiles_update_self on public.profiles
  for update to authenticated
  using      (id = auth.uid())
  with check (id = auth.uid());

-- memberships ------------------------------------------------------------
-- The caller can see memberships of groups they belong to. Writes happen
-- via the auto-provision trigger in Phase 0; member management is Phase 2.
create policy memberships_select on public.memberships
  for select to authenticated
  using (public.is_group_member(group_id));

-- events -----------------------------------------------------------------
create policy events_select on public.events
  for select to authenticated
  using (public.is_group_member(group_id));

create policy events_insert on public.events
  for insert to authenticated
  with check (public.is_group_member(group_id));

create policy events_update on public.events
  for update to authenticated
  using      (public.is_group_member(group_id))
  with check (public.is_group_member(group_id));

create policy events_delete on public.events
  for delete to authenticated
  using (public.is_group_member(group_id));

-- units (system catalog) ------------------------------------------------
create policy units_select on public.units
  for select to authenticated
  using (true);

-- supplier_categories ---------------------------------------------------
-- System rows (group_id null) readable by anyone authenticated; group rows
-- gated by membership. Writes only on the caller's own group rows.
create policy supplier_categories_select on public.supplier_categories
  for select to authenticated
  using (
    group_id is null
    or public.is_group_member(group_id)
  );

create policy supplier_categories_insert on public.supplier_categories
  for insert to authenticated
  with check (
    group_id is not null
    and public.is_group_member(group_id)
  );

create policy supplier_categories_update on public.supplier_categories
  for update to authenticated
  using      (group_id is not null and public.is_group_member(group_id))
  with check (group_id is not null and public.is_group_member(group_id));

create policy supplier_categories_delete on public.supplier_categories
  for delete to authenticated
  using (group_id is not null and public.is_group_member(group_id));

-- ingredients -----------------------------------------------------------
create policy ingredients_select on public.ingredients
  for select to authenticated
  using (
    group_id is null
    or public.is_group_member(group_id)
  );

create policy ingredients_insert on public.ingredients
  for insert to authenticated
  with check (
    group_id is not null
    and public.is_group_member(group_id)
  );

create policy ingredients_update on public.ingredients
  for update to authenticated
  using      (group_id is not null and public.is_group_member(group_id))
  with check (group_id is not null and public.is_group_member(group_id));

create policy ingredients_delete on public.ingredients
  for delete to authenticated
  using (group_id is not null and public.is_group_member(group_id));

-- dishes ----------------------------------------------------------------
create policy dishes_select on public.dishes
  for select to authenticated
  using (public.is_group_member(group_id));

create policy dishes_insert on public.dishes
  for insert to authenticated
  with check (public.is_group_member(group_id));

create policy dishes_update on public.dishes
  for update to authenticated
  using      (public.is_group_member(group_id))
  with check (public.is_group_member(group_id));

create policy dishes_delete on public.dishes
  for delete to authenticated
  using (public.is_group_member(group_id));

-- dish_ingredients (group via dish) -------------------------------------
create policy dish_ingredients_all on public.dish_ingredients
  for all to authenticated
  using (
    exists (
      select 1 from public.dishes d
      where d.id = dish_ingredients.dish_id
        and public.is_group_member(d.group_id)
    )
  )
  with check (
    exists (
      select 1 from public.dishes d
      where d.id = dish_ingredients.dish_id
        and public.is_group_member(d.group_id)
    )
  );

-- event_dishes (group via event) ----------------------------------------
create policy event_dishes_all on public.event_dishes
  for all to authenticated
  using (
    exists (
      select 1 from public.events e
      where e.id = event_dishes.event_id
        and public.is_group_member(e.group_id)
    )
  )
  with check (
    exists (
      select 1 from public.events e
      where e.id = event_dishes.event_id
        and public.is_group_member(e.group_id)
    )
  );

-- event_dish_ingredients (group via event_dish → event) -----------------
create policy event_dish_ingredients_all on public.event_dish_ingredients
  for all to authenticated
  using (
    exists (
      select 1
      from public.event_dishes ed
      join public.events e on e.id = ed.event_id
      where ed.id = event_dish_ingredients.event_dish_id
        and public.is_group_member(e.group_id)
    )
  )
  with check (
    exists (
      select 1
      from public.event_dishes ed
      join public.events e on e.id = ed.event_id
      where ed.id = event_dish_ingredients.event_dish_id
        and public.is_group_member(e.group_id)
    )
  );

-- orders (group via event) ----------------------------------------------
create policy orders_all on public.orders
  for all to authenticated
  using (
    exists (
      select 1 from public.events e
      where e.id = orders.event_id
        and public.is_group_member(e.group_id)
    )
  )
  with check (
    exists (
      select 1 from public.events e
      where e.id = orders.event_id
        and public.is_group_member(e.group_id)
    )
  );

-- order_items (group via order → event) ---------------------------------
create policy order_items_all on public.order_items
  for all to authenticated
  using (
    exists (
      select 1
      from public.orders o
      join public.events e on e.id = o.event_id
      where o.id = order_items.order_id
        and public.is_group_member(e.group_id)
    )
  )
  with check (
    exists (
      select 1
      from public.orders o
      join public.events e on e.id = o.event_id
      where o.id = order_items.order_id
        and public.is_group_member(e.group_id)
    )
  );

-- translations (system content) -----------------------------------------
create policy translations_select on public.translations
  for select to authenticated
  using (true);

-- message_templates -----------------------------------------------------
-- System default + caller's group rows are readable; writes restricted to
-- the caller's own group rows.
create policy message_templates_select on public.message_templates
  for select to authenticated
  using (
    group_id is null
    or public.is_group_member(group_id)
  );

create policy message_templates_insert on public.message_templates
  for insert to authenticated
  with check (
    group_id is not null
    and public.is_group_member(group_id)
  );

create policy message_templates_update on public.message_templates
  for update to authenticated
  using      (group_id is not null and public.is_group_member(group_id))
  with check (group_id is not null and public.is_group_member(group_id));

create policy message_templates_delete on public.message_templates
  for delete to authenticated
  using (group_id is not null and public.is_group_member(group_id));

-- media -----------------------------------------------------------------
create policy media_all on public.media
  for all to authenticated
  using      (public.is_group_member(group_id))
  with check (public.is_group_member(group_id));
