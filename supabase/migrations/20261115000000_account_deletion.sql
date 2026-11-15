-- ============================================================================
-- Spec 035 §D — in-app account deletion (server side, SQL half)
--
-- Apple (App Review Guideline 5.1.1(v)) and Google Play require that a user
-- can delete their account, and the data that goes with it, from inside the
-- app. Entertain's account is anonymous and auto-provisioned: one auth user,
-- one profile, one membership, one group that owns all the content.
--
-- This migration adds THREE FUNCTIONS and nothing else. It creates no table,
-- alters no table, touches no existing row, and changes no existing policy or
-- grant. The functions are callable only by `service_role` — i.e. only by the
-- `delete-account` Edge Function, which identifies the caller from their JWT
-- and never accepts a user or group id from the client.
--
--   * _account_sole_groups(user)     groups the user is the ONLY member of.
--   * account_storage_objects(user)  the Storage objects those groups own
--                                    (the Edge Function removes them through
--                                    the Storage API — blobs cannot be deleted
--                                    from SQL).
--   * delete_account_data(user)      hard-deletes every row those groups own,
--                                    in one transaction, children first.
--
-- Why not a plain `delete from groups` and let ON DELETE CASCADE do the rest:
-- three foreign keys are ON DELETE RESTRICT (dish_ingredients.ingredient_id,
-- orders.supplier_category_id, event_dish_ingredients.supplier_category_id),
-- so the cascade can abort depending on the order Postgres walks it. And
-- `media`, `translations` and `suggestions` do not hang off the group by a
-- cascading key at all. Hence an explicit, FK-ordered delete — the same shape
-- as `clear_demo_data` (Spec 033).
--
-- Shared groups: today every group has exactly one member. If a group ever has
-- more, deleting one member's account must not destroy the others' data — so
-- such a group is left intact and only the caller's membership is removed.
--
-- The shared demo photos live once under `demo/` in each bucket and are
-- referenced (not copied) by every user's demo `media` rows: the rows are
-- deleted here, the shared blobs are never listed for removal.
-- ============================================================================

-- Groups whose only member is p_user_id ------------------------------------
create or replace function public._account_sole_groups(p_user_id uuid)
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select m.group_id
  from public.memberships m
  where m.user_id = p_user_id
    and not exists (
      select 1 from public.memberships o
      where o.group_id = m.group_id and o.user_id <> p_user_id
    );
$$;

-- Storage objects owned by the account ---------------------------------------
-- Everything stored under one of the group's entities — `{entity_id}/…` (the
-- current layout) or the legacy `{entity_id}.jpg` — in the four photo buckets,
-- found by listing `storage.objects` (so blobs no `media` row points at any
-- more are caught too), plus every non-demo path a `media` row references, plus
-- the group's folder in `photo-staging`.
create or replace function public.account_storage_objects(p_user_id uuid)
returns table(bucket text, path text)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  -- Fail closed. The buckets always hold at least the shared demo photos, so an
  -- empty view of storage.objects means this function cannot see the table
  -- (row-level security) — and returning "nothing to remove" would silently
  -- leave the user's photos behind. Abort instead; nothing has been deleted yet.
  if not exists (select 1 from storage.objects) then
    raise exception 'account_storage_objects: storage.objects is not readable';
  end if;

  return query
  with g as (
    select x as id from public._account_sole_groups(p_user_id) x
  ),
  ent as (
    select 'event-photos'::text as bucket, 'event'::text as etype, e.id
      from public.events e where e.group_id in (select id from g)
    union all
    select 'dish-photos', 'dish', d.id
      from public.dishes d where d.group_id in (select id from g)
    union all
    select 'ingredient-photos', 'ingredient', i.id
      from public.ingredients i where i.group_id in (select id from g)
    union all
    select 'drink-photos', 'drink', k.id
      from public.drinks k where k.group_id in (select id from g)
  )
  select o.bucket_id::text, o.name::text
    from storage.objects o
    join ent on ent.bucket = o.bucket_id
   where o.name not like 'demo/%'
     and (split_part(o.name, '/', 1) = ent.id::text
          or split_part(o.name, '.', 1) = ent.id::text)
  union
  select ent.bucket, m.path
    from public.media m
    join ent on ent.etype = m.entity_type::text and ent.id = m.entity_id
   where m.path not like 'demo/%'
  union
  select o.bucket_id::text, o.name::text
    from storage.objects o
   where o.bucket_id = 'photo-staging'
     and split_part(o.name, '/', 1) in (select id::text from g);
end;
$$;

-- Hard-delete everything the account owns ------------------------------------
-- One transaction (a function body is atomic): either all of it goes or none.
-- Returns what happened: 'deleted' (the user's own group[s] and all their
-- data), 'left_shared_group' (only memberships removed — the group has other
-- members), or 'nothing' (no membership: an earlier run already did the work,
-- which is what makes a retry safe).
create or replace function public.delete_account_data(p_user_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_groups uuid[];
  v_had_membership boolean;
begin
  if p_user_id is null then
    raise exception 'delete_account_data: p_user_id is required';
  end if;

  select exists (select 1 from public.memberships where user_id = p_user_id)
    into v_had_membership;
  select coalesce(array_agg(x), '{}')
    into v_groups
    from public._account_sole_groups(p_user_id) x;

  -- Suggestions are free text the user wrote: they go with the account
  -- (director decision, Spec 035 plan §2) rather than staying behind unowned.
  delete from public.suggestions
   where user_id = p_user_id or group_id = any(v_groups);

  if cardinality(v_groups) > 0 then
    -- Polymorphic rows first (no FK ties them to their entity).
    delete from public.media m
     where (m.entity_type::text = 'event' and m.entity_id in
              (select id from public.events where group_id = any(v_groups)))
        or (m.entity_type::text = 'dish' and m.entity_id in
              (select id from public.dishes where group_id = any(v_groups)))
        or (m.entity_type::text = 'ingredient' and m.entity_id in
              (select id from public.ingredients where group_id = any(v_groups)))
        or (m.entity_type::text = 'drink' and m.entity_id in
              (select id from public.drinks where group_id = any(v_groups)));

    -- The AFTER DELETE triggers of Spec 026 remove these too; done explicitly
    -- so the guarantee does not depend on a trigger staying in place.
    delete from public.translations t
     where (t.entity_type::text = 'dish' and t.entity_id in
              (select id from public.dishes where group_id = any(v_groups)))
        or (t.entity_type::text = 'ingredient' and t.entity_id in
              (select id from public.ingredients where group_id = any(v_groups)))
        or (t.entity_type::text = 'drink' and t.entity_id in
              (select id from public.drinks where group_id = any(v_groups)));

    -- Events and everything under them, children first.
    delete from public.order_items oi
     where oi.order_id in (
       select o.id from public.orders o
       join public.events e on e.id = o.event_id
       where e.group_id = any(v_groups));
    delete from public.orders o
     where o.event_id in (select id from public.events where group_id = any(v_groups));
    delete from public.event_dish_ingredients edi
     where edi.event_dish_id in (
       select ed.id from public.event_dishes ed
       join public.events e on e.id = ed.event_id
       where e.group_id = any(v_groups));
    delete from public.event_drinks ek
     where ek.event_id in (select id from public.events where group_id = any(v_groups));
    delete from public.event_guests where group_id = any(v_groups);
    delete from public.event_dishes ed
     where ed.event_id in (select id from public.events where group_id = any(v_groups));
    delete from public.events where group_id = any(v_groups);

    -- Catalog, children first (recipe lines hold a RESTRICT key on ingredients).
    delete from public.dish_ingredients di
     where di.dish_id in (select id from public.dishes where group_id = any(v_groups))
        or di.ingredient_id in (select id from public.ingredients where group_id = any(v_groups));
    delete from public.dishes where group_id = any(v_groups);
    delete from public.drinks where group_id = any(v_groups);

    -- Suppliers. System rows (group_id null) are never matched.
    delete from public.group_supplier_settings where group_id = any(v_groups);
    delete from public.ingredients where group_id = any(v_groups);
    delete from public.supplier_categories where group_id = any(v_groups);
    delete from public.message_templates where group_id = any(v_groups);

    -- Quota bookkeeping.
    delete from public.quota_usage where group_id = any(v_groups);
    delete from public.quota_entitlements where group_id = any(v_groups);
  end if;

  -- Identity inside the app's schema. The auth user itself is removed by the
  -- Edge Function through the Auth admin API, right after this returns.
  delete from public.memberships where user_id = p_user_id;
  delete from public.groups where id = any(v_groups);
  delete from public.profiles where id = p_user_id;

  return case
    when cardinality(v_groups) > 0 then 'deleted'
    when v_had_membership then 'left_shared_group'
    else 'nothing'
  end;
end;
$$;

-- Service role only: never callable with a user's own session ---------------
revoke all on function public._account_sole_groups(uuid)   from public, anon, authenticated;
revoke all on function public.account_storage_objects(uuid) from public, anon, authenticated;
revoke all on function public.delete_account_data(uuid)     from public, anon, authenticated;
grant execute on function public._account_sole_groups(uuid)    to service_role;
grant execute on function public.account_storage_objects(uuid) to service_role;
grant execute on function public.delete_account_data(uuid)     to service_role;
