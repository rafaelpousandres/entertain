-- Phase 0 — auto-provision the profile, group, and membership the first
-- time a user appears in auth.users. Required so RLS works from day one
-- for anonymous sign-ins, before any UI exists to set up a group.
--
-- The function is SECURITY DEFINER so it can write to public tables in
-- the same transaction as the auth insert. search_path is pinned to
-- public to avoid trigger-injection vectors.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group_id uuid;
begin
  insert into public.profiles (id)
    values (new.id)
    on conflict (id) do nothing;

  insert into public.groups default values
    returning id into v_group_id;

  insert into public.memberships (group_id, user_id, role)
    values (v_group_id, new.id, 'owner');

  return new;
end;
$$;

revoke all on function public.handle_new_user() from public;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
