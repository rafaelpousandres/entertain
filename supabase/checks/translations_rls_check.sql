-- ============================================================================
-- READ-ONLY live check for the `translations` SELECT policy.
--
-- Run against a database AFTER 20261118000000_translations_select_scoped.sql
-- (SQL editor, or `supabase db query --linked -f <this file>`). It changes
-- nothing: it impersonates the most recently created member inside the
-- statement's own transaction and raises an exception — failing loudly — if:
--   • a SELECT policy on translations is open (`using (true)`), or
--   • that user can see a name translation of another group's catalog, or
--   • that user cannot see every translation of their own catalog, or
--   • system content (units, supplier categories, hints) is not readable.
-- On success it prints one NOTICE with the counts.
-- ============================================================================
do $$
declare
  v_user uuid;
  v_group uuid;
  v_open int;
  v_foreign bigint;
  v_own_expected bigint;
  v_own_seen bigint;
  v_units bigint;
  v_cats bigint;
  v_hints bigint;
  v_units_all bigint;
  v_hints_all bigint;
begin
  select count(*) into v_open from pg_policies
   where schemaname = 'public' and tablename = 'translations'
     and cmd in ('SELECT', 'ALL') and coalesce(qual, 'true') = 'true';
  if v_open > 0 then
    raise exception 'translations has % open SELECT policy(ies)', v_open;
  end if;

  select m.user_id, m.group_id into v_user, v_group
    from public.memberships m order by m.created_at desc limit 1;

  -- Ground truth, computed as the owner (RLS not applied).
  select count(*) into v_own_expected from public.translations t
   where t.field = 'name' and (
     (t.entity_type = 'ingredient' and t.entity_id in (select id from public.ingredients where group_id = v_group))
     or (t.entity_type = 'dish' and t.entity_id in (select id from public.dishes where group_id = v_group))
     or (t.entity_type = 'drink' and t.entity_id in (select id from public.drinks where group_id = v_group)));
  select count(*) into v_units_all from public.translations where entity_type = 'unit';
  select count(*) into v_hints_all from public.translations where entity_type = 'hint';

  -- Become that user for the rest of this transaction.
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_user::text, true);
  set local role authenticated;

  select count(*) into v_own_seen from public.translations t
   where t.field = 'name' and t.entity_type in ('ingredient', 'dish', 'drink');
  select count(*) into v_units from public.translations where entity_type = 'unit';
  select count(*) into v_cats from public.translations where entity_type = 'supplier_category';
  select count(*) into v_hints from public.translations where entity_type = 'hint';

  reset role;

  -- Everything the user saw beyond their own catalog would be someone else's
  -- (there are no system dishes/drinks; system ingredients are counted apart).
  select v_own_seen - v_own_expected - count(*) into v_foreign
    from public.translations t
   where t.field = 'name' and t.entity_type = 'ingredient'
     and t.entity_id in (select id from public.ingredients where group_id is null);

  if v_foreign <> 0 then
    raise exception 'translations leak/gap: user sees % catalog rows vs % own (diff %)',
      v_own_seen, v_own_expected, v_foreign;
  end if;
  if v_units <> v_units_all or v_hints <> v_hints_all or v_cats = 0 then
    raise exception 'system content not fully readable: units %/%, hints %/%, categories %',
      v_units, v_units_all, v_hints, v_hints_all, v_cats;
  end if;

  raise notice 'OK — own catalog translations %/%, units %, supplier categories %, hints %',
    v_own_seen, v_own_expected, v_units, v_cats, v_hints;
end;
$$;
