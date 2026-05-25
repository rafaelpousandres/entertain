-- Phase 0 — core access tables: groups, profiles, memberships.
-- A profile is the app-side extension of auth.users; a group is the
-- isolation unit for all user data; a membership is the user↔group link
-- that RLS depends on.

-- groups -----------------------------------------------------------------
create table public.groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null default 'My group',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create trigger trg_groups_updated_at
  before update on public.groups
  for each row execute function public.set_updated_at();

-- profiles ---------------------------------------------------------------
-- profiles.id mirrors auth.users.id; the cascade keeps profile rows in
-- sync if a user is deleted at the auth layer. Soft-delete via deleted_at
-- still applies for the app's own "remove this user" flow.
create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text,
  locale        public.profile_locale not null default 'ca',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);

create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- memberships ------------------------------------------------------------
create table public.memberships (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid not null references public.groups(id)   on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  role       public.membership_role not null default 'owner',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (group_id, user_id)
);

create index memberships_user_id_idx  on public.memberships (user_id);
create index memberships_group_id_idx on public.memberships (group_id);

create trigger trg_memberships_updated_at
  before update on public.memberships
  for each row execute function public.set_updated_at();
