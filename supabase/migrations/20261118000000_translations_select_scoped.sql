-- ============================================================================
-- translations — scope the SELECT policy (was `using (true)`)
--
-- PROBLEM
--   `translations_select` let every authenticated user read EVERY row. Since
--   Spec 025 the table also holds the names of each group's own ingredients,
--   dishes and drinks, so:
--     • privacy: any user could read every other group's catalog names;
--     • correctness: the client reads "all name translations of a type for a
--       locale" in one request, and the API caps a response at 1000 rows. With
--       5570 ingredient rows per locale in production, recent accounts no
--       longer received their own rows and saw the untranslated base names.
--
-- NEW RULE — a row is readable when the thing it translates is readable:
--   • unit, hint            → system content, readable by everyone;
--   • supplier_category,
--     ingredient,
--     message_template      → system rows (group_id null) or the caller's group;
--   • dish, drink           → the caller's group (these have no system rows).
--   Mirrors the SELECT policies of the parent tables.
--
-- STRUCTURE ONLY: replaces one policy. No row of any table is created, changed
-- or deleted. The service role (Edge Functions) and SECURITY DEFINER functions
-- (seed_demo, clear_demo_data, the cleanup triggers) bypass RLS and are
-- unaffected. Clients never write this table (no INSERT/UPDATE/DELETE policy).
--
-- The membership lookup is written as an uncorrelated sub-select so Postgres
-- resolves the caller's readable entity ids once per query (hashed) instead of
-- once per translation row.
-- ============================================================================

drop policy if exists translations_select on public.translations;

create policy translations_select on public.translations
  for select to authenticated
  using (
    entity_type in ('unit', 'hint')
    or (
      entity_type = 'supplier_category'
      and entity_id in (
        select sc.id from public.supplier_categories sc
        where sc.group_id is null
           or sc.group_id in (
             select m.group_id from public.memberships m
             where m.user_id = (select auth.uid())
           )
      )
    )
    or (
      entity_type = 'ingredient'
      and entity_id in (
        select i.id from public.ingredients i
        where i.group_id is null
           or i.group_id in (
             select m.group_id from public.memberships m
             where m.user_id = (select auth.uid())
           )
      )
    )
    or (
      entity_type = 'dish'
      and entity_id in (
        select d.id from public.dishes d
        where d.group_id in (
          select m.group_id from public.memberships m
          where m.user_id = (select auth.uid())
        )
      )
    )
    or (
      entity_type = 'drink'
      and entity_id in (
        select dr.id from public.drinks dr
        where dr.group_id in (
          select m.group_id from public.memberships m
          where m.user_id = (select auth.uid())
        )
      )
    )
    or (
      entity_type = 'message_template'
      and entity_id in (
        select mt.id from public.message_templates mt
        where mt.group_id is null
           or mt.group_id in (
             select m.group_id from public.memberships m
             where m.user_id = (select auth.uid())
           )
      )
    )
  );
