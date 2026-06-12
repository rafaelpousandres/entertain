-- Specification 010 §2.2 — new system unit "ampolla" (bottle).
--
-- Real use surfaced that liquids sold in bottles (wine, olive oil, vinegar,
-- sauces) want a countable commercial unit: the user asks for "1 ampolla", not
-- "750 ml". Modelled as `package` magnitude — same family as `packet`, `jar`,
-- `tray` — so it stays distinct from the `l`/`ml` volume units and has no
-- defined size or conversion (base_factor null). A future conversion layer can
-- add package-to-volume equivalence per ingredient if ever needed.
--
-- The code stays Catalan (`ampolla`), matching the system-unit convention; the
-- display name is translated per locale (ca «ampolla» / es «botella» /
-- en «bottle»). Following the count/package convention (Spec 008 Fixes §2.4),
-- the labels are stored in the plural form so the supplier message — where
-- quantities skew above one — reads naturally ("3 ampolles d'oli"); the unit is
-- meaningful and is NOT flagged `omit_in_display`.
--
-- Idempotent: the unit insert skips the code if it already exists, and the
-- translation insert only fires for rows not already translated.

insert into public.units (code, magnitude, base_factor) values
  ('ampolla', 'package', null)
on conflict (code) do nothing;

insert into public.translations (entity_type, entity_id, locale, field, text)
select 'unit'::public.translation_entity_type,
       u.id,
       t.locale::public.profile_locale,
       'name',
       t.text
from public.units u
join (values
  ('ampolla', 'ca', 'ampolles'),
  ('ampolla', 'es', 'botellas'),
  ('ampolla', 'en', 'bottles')
) as t(code, locale, text) on t.code = u.code
where not exists (
  select 1
  from public.translations existing
  where existing.entity_type = 'unit'::public.translation_entity_type
    and existing.entity_id = u.id
    and existing.locale = t.locale::public.profile_locale
    and existing.field = 'name'
);
