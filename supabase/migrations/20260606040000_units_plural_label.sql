-- Specification 006 — Fixes round 2 §2.2
-- The generic countable unit (code 'unit') was seeded with a singular label
-- ("unitat" / "unidad"). In a quantity picker the natural reading is plural
-- ("3 unitats", not "3 unitat"), so update the display label of this unit to
-- the plural form in all three supported locales. Data-only change; the seed
-- file (20260525000900_system_content.sql) carries the plural form for fresh
-- databases, and this migration corrects already-provisioned projects.

update public.translations t
set text = case t.locale
  when 'ca'::public.profile_locale then 'unitats'
  when 'es'::public.profile_locale then 'unidades'
  when 'en'::public.profile_locale then 'units'
  else t.text
end
from public.units u
where t.entity_type = 'unit'::public.translation_entity_type
  and t.entity_id = u.id
  and u.code = 'unit'
  and t.field = 'name';
