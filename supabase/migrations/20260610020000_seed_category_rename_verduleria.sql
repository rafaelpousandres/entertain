-- Specification 008 — §2.6: rename the seed supplier category "Fruiteria" to
-- "Verduleria".
--
-- In real Catalan retail the one-stop shop for fruit *and* vegetables is the
-- verduleria, so the seed label is updated to the more useful real-world name.
-- Only the localised display labels change; the category row itself (its `id`,
-- `code = 'greengrocer'`, `is_system` flag) is untouched, so every ingredient,
-- per-group setting and event line already linked to it keeps working and shows
-- the new label automatically.
--
-- The display names of system categories live in `translations` (service-role
-- writes only), one row per locale. English is already "Greengrocer", which is
-- the intended term, so only ca/es are updated.
update public.translations t
set text = 'Verduleria'
from public.supplier_categories sc
where t.entity_type = 'supplier_category'
  and t.entity_id = sc.id
  and sc.code = 'greengrocer'
  and sc.group_id is null
  and t.locale = 'ca'
  and t.field = 'name';

update public.translations t
set text = 'Verdulería'
from public.supplier_categories sc
where t.entity_type = 'supplier_category'
  and t.entity_id = sc.id
  and sc.code = 'greengrocer'
  and sc.group_id is null
  and t.locale = 'es'
  and t.field = 'name';

-- English stays "Greengrocer" (already correct); kept here as an idempotent
-- no-op-style guard in case an older seed used "Fruit shop".
update public.translations t
set text = 'Greengrocer'
from public.supplier_categories sc
where t.entity_type = 'supplier_category'
  and t.entity_id = sc.id
  and sc.code = 'greengrocer'
  and sc.group_id is null
  and t.locale = 'en'
  and t.field = 'name';
