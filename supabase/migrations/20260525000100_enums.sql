-- Phase 0 — enum types.
-- Only the enums referenced by Phase 0 tables are created here. Enums whose
-- only consumers are later-phase tables (persons.rsvp_status, tasks.type,
-- payment_method, etc.) will be added in the migration that creates those
-- tables, to keep this migration scoped to Phase 0.

create type public.profile_locale         as enum ('ca','es','en');
create type public.membership_role        as enum ('owner','host','shopper','cook','guest','supplier');

create type public.event_type             as enum ('lunch','dinner','other');
create type public.event_format           as enum ('seated','buffet','other');
create type public.event_status           as enum ('planning','confirmed','done');

create type public.dish_category          as enum ('aperitif','starter','main','dessert','drink','other');

create type public.unit_magnitude         as enum ('mass','volume','count','package');

create type public.order_status           as enum ('draft','sent');
create type public.order_item_status      as enum ('pending','bought','unavailable');

-- Polymorphic media owner. The full set of owner kinds from the model lives
-- in the enum from day one even though only event/dish/ingredient are
-- exercised in Phase 0 — phases activate subsets without redesigning enums.
create type public.media_owner_type       as enum ('event','dish','ingredient','person','supplier','material','receipt');
create type public.media_kind             as enum ('photo','video');

create type public.translation_entity_type as enum ('unit','supplier_category','ingredient','message_template');
