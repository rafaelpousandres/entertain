-- Specification 021 Part A — Suggestions box.
--
-- A lightweight feedback channel: users send free-text suggestions that are
-- stored for a later manual dump (owner → claude.ai). Deliberately simple — no
-- in-app AI, no live processing. The client writes rows directly under RLS; the
-- counter ("N suggeriments enviats") is a plain count over the group's rows.
--
-- Two-layer access model, same as the rest of the schema: the table-level
-- GRANT lets the request reach RLS, and the membership policies gate which rows
-- each caller may insert/read. `app_version` is filled by the client
-- (package_info) so the dump carries the app version each suggestion came from.
--
-- NOTE (house rule): no GRANT to service_role here on purpose — no Edge
-- Function touches this table; the client writes it directly under RLS. If that
-- ever changes, add the explicit service_role grant (SELECT and/or DML) in the
-- migration that introduces the function, per CLAUDE.md.

create table public.suggestions (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid references public.groups(id) on delete set null,
  user_id     uuid references auth.users(id) on delete set null,
  text        text not null,
  app_version text,           -- captured automatically from the client
  created_at  timestamptz not null default now()
);

alter table public.suggestions enable row level security;

-- Users may INSERT their own and READ their group's (for the counter).
create policy suggestions_insert on public.suggestions
  for insert to authenticated with check (public.is_group_member(group_id));
create policy suggestions_select on public.suggestions
  for select to authenticated using (public.is_group_member(group_id));

grant select, insert on table public.suggestions to anon, authenticated;
