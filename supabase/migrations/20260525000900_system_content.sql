-- Phase 0 — system content seed.
--
-- Loads the units catalog, the supplier-categories catalog, and the
-- system (group_id null, is_system true) message template, with their
-- ca/es/en translations via the `translations` table where the model
-- requires it.
--
-- An initial catalog of common ingredients is deferred — explicitly
-- permitted by Specification 002 §2.5. To be revisited on claude.ai when
-- planning the ingredient-picker UX.

-- units catalog ---------------------------------------------------------
-- base_factor is the factor toward the magnitude's canonical unit
-- (g for mass, ml for volume); null for count and package.
insert into public.units (code, magnitude, base_factor) values
  ('g',     'mass',    1),
  ('kg',    'mass',    1000),
  ('ml',    'volume',  1),
  ('l',     'volume',  1000),
  ('unit',  'count',   null),
  ('bunch', 'count',   null),
  ('jar',   'package', null),
  ('tray',  'package', null);

insert into public.translations (entity_type, entity_id, locale, field, text)
select 'unit'::public.translation_entity_type,
       u.id,
       t.locale::public.profile_locale,
       'name',
       t.text
from public.units u
join (values
  ('g',     'ca', 'g'),
  ('g',     'es', 'g'),
  ('g',     'en', 'g'),
  ('kg',    'ca', 'kg'),
  ('kg',    'es', 'kg'),
  ('kg',    'en', 'kg'),
  ('ml',    'ca', 'ml'),
  ('ml',    'es', 'ml'),
  ('ml',    'en', 'ml'),
  ('l',     'ca', 'l'),
  ('l',     'es', 'l'),
  ('l',     'en', 'l'),
  -- Fixes round 2 §2.2: the generic countable unit reads naturally in the
  -- plural in a quantity picker ("3 unitats", not "3 unitat").
  ('unit',  'ca', 'unitats'),
  ('unit',  'es', 'unidades'),
  ('unit',  'en', 'units'),
  ('bunch', 'ca', 'manat'),
  ('bunch', 'es', 'manojo'),
  ('bunch', 'en', 'bunch'),
  ('jar',   'ca', 'pot'),
  ('jar',   'es', 'tarro'),
  ('jar',   'en', 'jar'),
  ('tray',  'ca', 'safata'),
  ('tray',  'es', 'bandeja'),
  ('tray',  'en', 'tray')
) as t(code, locale, text) on t.code = u.code;

-- supplier categories catalog -------------------------------------------
insert into public.supplier_categories (group_id, code, is_system) values
  (null, 'fishmonger',  true),
  (null, 'butcher',     true),
  (null, 'greengrocer', true),
  (null, 'supermarket', true);

insert into public.translations (entity_type, entity_id, locale, field, text)
select 'supplier_category'::public.translation_entity_type,
       sc.id,
       t.locale::public.profile_locale,
       'name',
       t.text
from public.supplier_categories sc
join (values
  ('fishmonger',  'ca', 'Peixateria'),
  ('fishmonger',  'es', 'Pescadería'),
  ('fishmonger',  'en', 'Fishmonger'),
  ('butcher',     'ca', 'Carnisseria'),
  ('butcher',     'es', 'Carnicería'),
  ('butcher',     'en', 'Butcher'),
  ('greengrocer', 'ca', 'Fruiteria'),
  ('greengrocer', 'es', 'Frutería'),
  ('greengrocer', 'en', 'Greengrocer'),
  ('supermarket', 'ca', 'Supermercat'),
  ('supermarket', 'es', 'Supermercado'),
  ('supermarket', 'en', 'Supermarket')
) as t(code, locale, text) on t.code = sc.code
where sc.group_id is null;

-- system message template (one row per locale) -------------------------
-- The model carries `locale` as a column on message_templates, so each
-- locale is its own row rather than a translation entry.
insert into public.message_templates (group_id, locale, header, footer, is_system) values
  (null, 'ca',
    'Bon dia! Voldria fer la comanda següent:',
    'Moltes gràcies!',
    true),
  (null, 'es',
    '¡Buenos días! Quisiera hacer el siguiente pedido:',
    '¡Muchas gracias!',
    true),
  (null, 'en',
    'Hi! I''d like to place the following order:',
    'Thanks!',
    true);
