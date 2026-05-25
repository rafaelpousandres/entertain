-- Phase 0 — cross-cutting: translations, message_templates, media.

-- translations -----------------------------------------------------------
-- Polymorphic association by (entity_type, entity_id). No FK constraints
-- to the referenced tables because entity_type identifies the parent
-- table; integrity is maintained at the application layer (cleanup runs
-- when system content is reseeded).
create table public.translations (
  id          uuid primary key default gen_random_uuid(),
  entity_type public.translation_entity_type not null,
  entity_id   uuid not null,
  locale      public.profile_locale not null,
  field       text not null,
  text        text not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (entity_type, entity_id, locale, field)
);

create index translations_entity_idx
  on public.translations (entity_type, entity_id);

create trigger trg_translations_updated_at
  before update on public.translations
  for each row execute function public.set_updated_at();

-- message_templates ------------------------------------------------------
-- System default has group_id null and is_system = true; per-group
-- overrides carry a group_id.
create table public.message_templates (
  id         uuid primary key default gen_random_uuid(),
  group_id   uuid references public.groups(id) on delete cascade,
  locale     public.profile_locale not null,
  header     text not null,
  footer     text not null,
  is_system  boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- At most one system default per locale, and at most one custom template
-- per (group, locale).
create unique index message_templates_system_locale_idx
  on public.message_templates (locale)
  where group_id is null;

create unique index message_templates_group_locale_idx
  on public.message_templates (group_id, locale)
  where group_id is not null;

create index message_templates_group_id_idx on public.message_templates (group_id);

create trigger trg_message_templates_updated_at
  before update on public.message_templates
  for each row execute function public.set_updated_at();

-- media ------------------------------------------------------------------
-- Polymorphic association via (owner_type, owner_id). Storage object lives
-- in Supabase Storage; storage_path is the bucket-relative path.
create table public.media (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.groups(id) on delete cascade,
  owner_type   public.media_owner_type not null,
  owner_id     uuid not null,
  kind         public.media_kind not null,
  storage_path text not null,
  caption      text,
  sort_order   integer not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index media_group_id_idx on public.media (group_id);
create index media_owner_idx    on public.media (owner_type, owner_id);

create trigger trg_media_updated_at
  before update on public.media
  for each row execute function public.set_updated_at();
