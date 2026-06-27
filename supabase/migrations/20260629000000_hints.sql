-- Spec 026 Part A — hints catalog (DB-backed, editable without a rebuild) and
-- Part E.2 — server-side cleanup of orphan translations on hard deletes.

-- Hints catalog. The localized hint text lives in `translations` (same i18n model
-- as catalog names), one row per locale with field = 'text'.
create table public.hints (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  kind text not null default 'tip' check (kind in ('welcome', 'tip')),
  created_at timestamptz not null default now()
);

alter table public.hints enable row level security;

-- Read-only for everyone; no client writes (editing is done directly in the DB).
create policy hints_read on public.hints
  for select to anon, authenticated using (true);
grant select on table public.hints to anon, authenticated;

-- Hints join the existing i18n model. Own statement, committed here before the
-- seed migration (20260629000100) uses the value — same pattern as 'dish'/'drink'.
alter type public.translation_entity_type add value if not exists 'hint';

-- Part E.2 — prevent FUTURE orphan translations.
-- `translations` is polymorphic (no FK to entity_id), so a HARD delete of an
-- ingredient/dish/drink (e.g. an ON DELETE CASCADE from a group removal) leaves
-- its translation rows behind. The app only ever SOFT-deletes catalog rows (sets
-- deleted_at), and the anon/authenticated roles cannot write `translations`
-- (read-only), so this cleanup belongs server-side: an AFTER DELETE trigger that
-- runs as the definer and removes the matching translations. (The one-off sweep
-- of pre-existing orphans is a separate maintenance step, run once by hand.)
create or replace function public.delete_entity_translations()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
as $$
begin
  delete from public.translations
   where entity_type = tg_argv[0]::public.translation_entity_type
     and entity_id = old.id;
  return old;
end;
$$;

create trigger trg_ingredients_del_translations
  after delete on public.ingredients
  for each row execute function public.delete_entity_translations('ingredient');

create trigger trg_dishes_del_translations
  after delete on public.dishes
  for each row execute function public.delete_entity_translations('dish');

create trigger trg_drinks_del_translations
  after delete on public.drinks
  for each row execute function public.delete_entity_translations('drink');
