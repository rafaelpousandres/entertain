-- Specification 008 — Fixes (post-real-use) §2.4
-- New abstract countable units for real ingredients: "paquet" (a packet of x)
-- and "llauna" (a can of z). Entered while logging real ingredients where the
-- existing catalog had no countable abstract unit for them.
--
-- Modelled as `count` magnitude (like the generic "unit"): they have no defined
-- size and no conversion to mass/volume, and quantities round up to the next
-- whole integer when an event-dish is scaled (you can't buy half a packet) —
-- this is exactly the `count` rounding rule from Spec 008 §2.10.
--
-- The project owner explicitly accepts the size ambiguity (a "paquet" of one
-- ingredient may be 100 g and of another 1 kg; the context lives in the
-- ingredient, not the unit).
--
-- NOTE on "pot": the original spec listed three units (paquet, pot, llauna),
-- but the seed already ships a `jar` unit displayed as «pot» (ca). Per the
-- project owner's decision, "pot" is dropped here to avoid a duplicate label in
-- the unit picker; only paquet and llauna are added.
--
-- Display labels are stored in the plural form, matching the existing
-- count-unit convention (the generic `unit` is seeded as «unitats», Spec 006
-- §2.2) so the supplier shopping message — where quantities skew above one —
-- reads naturally ("3 llaunes de pèsols"). These units are *not* flagged
-- `omit_in_display`: unlike the generic "unit", the word is meaningful and must
-- appear in the message line.
--
-- Idempotent: the unit inserts skip codes that already exist, and the
-- translation insert only fires for the freshly inserted rows.

insert into public.units (code, magnitude, base_factor) values
  ('packet', 'count', null),
  ('can',    'count', null)
on conflict (code) do nothing;

insert into public.translations (entity_type, entity_id, locale, field, text)
select 'unit'::public.translation_entity_type,
       u.id,
       t.locale::public.profile_locale,
       'name',
       t.text
from public.units u
join (values
  ('packet', 'ca', 'paquets'),
  ('packet', 'es', 'paquetes'),
  ('packet', 'en', 'packets'),
  ('can',    'ca', 'llaunes'),
  ('can',    'es', 'latas'),
  ('can',    'en', 'cans')
) as t(code, locale, text) on t.code = u.code
where not exists (
  select 1
  from public.translations existing
  where existing.entity_type = 'unit'::public.translation_entity_type
    and existing.entity_id = u.id
    and existing.locale = t.locale::public.profile_locale
    and existing.field = 'name'
);
