-- ============================================================================
-- Demo dataset seed — group 1f09045b-cacd-449a-a8a1-c7bdfb5bdc52 (English)
-- Phase 2 content plan: "Fase 2 - Pla de contingut del dataset de demostració.md"
-- (versioned next to this file).
--
-- PURPOSE
--   A rich English demo dataset for screenshots: dietary badges (VGN/VGT/SG/?),
--   guest traffic-light, canonical course order, summary sheet, shopping by
--   urgency + per-supplier sections (incl. custom suppliers with order channel).
--
-- IDEMPOTENT / REGENERABLE
--   Re-running this file leaves the group in the same known state.
--   • EXISTING catalog (61 ingredients, 15 dishes, recipes) and the 3 existing
--     events are kept BY ID (UPSERT by natural key) — so their photos in
--     `media`/Storage stay linked. Only their `diet`/`gluten_free` are (re)set
--     and they're un-soft-deleted.
--   • REGENERABLE content (custom suppliers, drinks, all guests, all event
--     drinks, the future "Summer Garden Party" event + its menu/shopping, and
--     the new "Marinated olives" catalog dish) is DELETED and re-created each
--     run. No hardcoded UUIDs — everything keyed by (group_id + name/title/code).
--
-- SCOPE: touches ONLY this group. Never the system catalog (group_id null),
--   other groups/users, `media`/Storage, or migrations.
--
-- PHOTOS (§7): NOT handled here. Existing photos are preserved (ids kept). New
--   covers/photos are added by hand from the app (Pexels) on the test profile.
--
-- HOW TO RUN: paste into the Supabase SQL Editor, or POST to the Management API
--   database/query endpoint. Transactional: all-or-nothing.
-- ============================================================================

begin;

-- Convenience: the group id is inlined as a literal everywhere below.
-- '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52'

-- ─────────────────────────────────────────────────────────────────────────
-- 1. CATALOG — un-soft-delete + dietary classification (UPSERT by name)
--    diet  : vegan | vegetarian | none | unknown
--    gluten: yes (gluten-free) | no (contains gluten) | unknown
--    'dark chocolate' and 'espresso coffee' are LEFT unknown on purpose (plan
--    §1) so the catalog shows a "?" badge and it propagates to Tiramisu / Yule
--    log.
-- ─────────────────────────────────────────────────────────────────────────
update public.ingredients
set deleted_at = null
where group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and deleted_at is not null;

update public.dishes
set deleted_at = null
where group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and deleted_at is not null;

update public.ingredients i
set diet = v.diet::diet_level,
    gluten_free = v.gf::tri_state
from (values
  ('00 flour','vegan','no'),
  ('apples','vegan','yes'),
  ('arborio rice','vegan','yes'),
  ('avocado','vegan','yes'),
  ('baguette','vegan','no'),
  ('basil','vegan','yes'),
  ('bean sprouts','vegan','yes'),
  ('beef stock','none','yes'),
  ('beef tenderloin','none','yes'),
  ('blueberries','vegan','yes'),
  ('butter','vegetarian','yes'),
  ('capers','vegan','yes'),
  ('carrots','vegan','yes'),
  ('celery stalks','vegan','yes'),
  ('chestnuts','vegan','yes'),
  ('cocoa powder','vegan','yes'),
  ('cream cheese','vegetarian','yes'),
  ('cucumber','vegan','yes'),
  ('dark chocolate','unknown','unknown'),   -- deliberate "?"
  ('dry white wine','vegan','yes'),
  ('espresso coffee','unknown','unknown'),  -- deliberate "?"
  ('feta cheese','vegetarian','yes'),
  ('firm tofu','vegan','yes'),
  ('fresh mint','vegan','yes'),
  ('fresh orange juice','vegan','yes'),
  ('fresh thyme','vegan','yes'),
  ('garlic cloves','vegan','yes'),
  ('heavy cream','vegetarian','yes'),
  ('kalamata olives','vegan','yes'),
  ('ladyfingers','vegetarian','no'),
  ('large eggs','vegetarian','yes'),
  ('lemons','vegan','yes'),
  ('limes','vegan','yes'),
  ('marsala wine','vegan','yes'),
  ('mascarpone','vegetarian','yes'),
  ('mushrooms','vegan','yes'),
  ('olive oil','vegan','yes'),
  ('oysters','none','yes'),
  ('parmesan','vegetarian','yes'),
  ('parsley','vegan','yes'),
  ('pastry flour','vegan','no'),
  ('peanuts','vegan','yes'),
  ('pineapple','vegan','yes'),
  ('potatoes','vegan','yes'),
  ('prosecco','vegan','yes'),
  ('puff pastry','vegetarian','no'),
  ('rice noodles','vegan','yes'),
  ('ricotta','vegetarian','yes'),
  ('saffron threads','vegan','yes'),
  ('sage leaves','vegan','yes'),
  ('smoked salmon','none','yes'),
  ('sourdough bread','vegan','no'),
  ('soy sauce','vegan','no'),
  ('spinach','vegan','yes'),
  ('strawberries','vegan','yes'),
  ('sugar','vegan','yes'),
  ('tomato','vegan','yes'),
  ('truffle oil','vegan','yes'),
  ('veal shanks','none','yes'),
  ('whole goose','none','yes'),
  ('yellow onion','vegan','yes')
) as v(name, diet, gf)
where i.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and i.name = v.name;

-- ─────────────────────────────────────────────────────────────────────────
-- 1b. EXISTING EVENTS — fill in a credible time + (fictitious) location.
--     Time by type: dinners in the evening, the brunch at midday. The existing
--     3 events are kept (not recreated), so this is a plain UPDATE by title.
-- ─────────────────────────────────────────────────────────────────────────
update public.events e
set event_time = v.t::time, location_name = v.loc
from (values
  ('Christmas Eve Dinner',   '20:00', 'Rosewood Cottage'),
  ('Garden Brunch',          '11:30', 'Linden Terrace'),
  ('Italian Sunday Dinner',  '19:30', 'Casa Bianchi')
) as v(title, t, loc)
where e.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and e.title = v.title;

-- ─────────────────────────────────────────────────────────────────────────
-- 2. NEW APERITIF CATALOG DISH — "Marinated olives" (regenerable)
--    Built from existing ingredients so badges derive (vegan + gluten-free).
-- ─────────────────────────────────────────────────────────────────────────
delete from public.dish_ingredients
where dish_id in (select id from public.dishes
                  where group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52'
                    and name = 'Marinated olives');
delete from public.dishes
where group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and name = 'Marinated olives';

-- Fixed id (Spec: regenerable, orphan-free) so its seed cover photo path stays
-- valid across re-runs.
insert into public.dishes
  (id, group_id, name, category, base_servings, acquisition_mode, original_locale,
   diet, gluten_free, preparation)
values
  ('d0d0d0d0-0000-4000-8000-000000000001',
   '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52', 'Marinated olives', 'aperitif', 4,
   'cooked', 'en', 'unknown', 'unknown',
   'Toss the olives with olive oil, lemon zest, thyme and a pinch of chilli. Let them marinate for an hour before serving.');

insert into public.dish_ingredients (dish_id, ingredient_id, quantity, unit_id, sort_order)
select d.id, i.id, v.qty, i.default_unit_id, v.so
from (values ('kalamata olives', 300, 0),
             ('olive oil', 50, 1),
             ('lemons', 1, 2),
             ('fresh thyme', 5, 3)) as v(name, qty, so)
join public.dishes d
  on d.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and d.name = 'Marinated olives'
join public.ingredients i
  on i.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and i.name = v.name
     and i.deleted_at is null;

-- ─────────────────────────────────────────────────────────────────────────
-- 3. DELETE the regenerable blocks (FK-safe order), scoped to this group
--    The future event goes FIRST: its shopping lines reference the custom
--    supplier categories, so the suppliers must be deleted last.
-- ─────────────────────────────────────────────────────────────────────────
-- The future event + its menu (children first)
delete from public.event_dish_ingredients
where event_dish_id in (
  select ed.id from public.event_dishes ed
  join public.events e on e.id = ed.event_id
  where e.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and e.title = 'Summer Garden Party');
delete from public.event_dishes
where event_id in (select id from public.events
                   where group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and title = 'Summer Garden Party');
delete from public.events
where group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and title = 'Summer Garden Party';

-- All guests + event drinks of every event in the group
delete from public.event_guests
where group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52';
delete from public.event_drinks
where event_id in (select id from public.events where group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52');

-- Catalog drinks of the group
delete from public.drinks
where group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52';

-- Custom suppliers LAST (now unreferenced): settings first, then the categories.
delete from public.group_supplier_settings
where group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52';
delete from public.supplier_categories
where group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52';  -- only group rows; system (null) untouched

-- ─────────────────────────────────────────────────────────────────────────
-- 4. CUSTOM SUPPLIERS (group categories + order-channel settings)
--    Contact data is INVENTED and clearly fictitious (555 numbers, .example).
-- ─────────────────────────────────────────────────────────────────────────
insert into public.supplier_categories (group_id, code, is_system, name) values
  ('1f09045b-cacd-449a-a8a1-c7bdfb5bdc52', 'sunrise_market', false, 'Sunrise Market'),
  ('1f09045b-cacd-449a-a8a1-c7bdfb5bdc52', 'blue_fin',       false, 'Blue Fin Fishmonger'),
  ('1f09045b-cacd-449a-a8a1-c7bdfb5bdc52', 'vineyard_wines', false, 'Vineyard Wines');

insert into public.group_supplier_settings
  (group_id, supplier_category_id, channel, channel_address, phone_address, email_address, supplier_name, is_default)
select '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52', sc.id, v.channel::message_channel,
       v.addr, v.phone, v.email, v.sname, true
from (values
  ('sunrise_market', 'whatsapp', '+15550142',            '+1 555-0142', null,                    'Sunrise Market'),
  ('blue_fin',       'email',    'orders@bluefin.example', null,        'orders@bluefin.example', 'Blue Fin Fishmonger'),
  ('vineyard_wines', 'whatsapp', '+15550173',            '+1 555-0173', null,                    'Vineyard Wines')
) as v(code, channel, addr, phone, email, sname)
join public.supplier_categories sc
  on sc.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and sc.code = v.code;

-- Concrete suppliers for the SYSTEM categories used in the shopping so each
-- section can generate an order message. Fictitious contacts. (Pantry needs
-- none; the system "fishmonger" isn't used here — the custom Blue Fin covers
-- fish.) These settings are keyed to the system category (group_id null).
insert into public.group_supplier_settings
  (group_id, supplier_category_id, channel, channel_address, phone_address, email_address, supplier_name, is_default)
select '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52', sc.id, v.channel::message_channel,
       v.addr, v.phone, v.email, v.sname, true
from (values
  ('greengrocer', 'whatsapp', '+15550188',               '+1 555-0188', null,                       'Green Valley Produce'),
  ('butcher',     'email',    'orders@primecuts.example', null,         'orders@primecuts.example', 'Prime Cuts Butchery'),
  ('supermarket', 'whatsapp', '+15550210',               '+1 555-0210', null,                       'Hillside Supermarket')
) as v(code, channel, addr, phone, email, sname)
join public.supplier_categories sc
  on sc.group_id is null and sc.code = v.code;

-- ─────────────────────────────────────────────────────────────────────────
-- 5. CATALOG DRINKS (8) — no dietary fields exist on drinks (parked feature),
--    so drinks carry no badges. Created for the menu / Begudes section.
-- ─────────────────────────────────────────────────────────────────────────
-- Fixed ids (regenerable, orphan-free) so each drink's seed cover path is stable.
-- Default supplier = Supermarket (system) per Spec 030 §E (new drinks → Supermarket),
-- so they don't render uncategorised.
insert into public.drinks (id, group_id, name, supplier_category_id, denomination, original_locale)
select v.id::uuid, '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52', v.name,
       (select id from public.supplier_categories where group_id is null and code = 'supermarket'),
       v.denom, 'en'
from (values
  ('a0a0a0a0-0000-4000-8000-000000000001', 'Still water',      'bottle'),
  ('a0a0a0a0-0000-4000-8000-000000000002', 'Sparkling water',  'bottle'),
  ('a0a0a0a0-0000-4000-8000-000000000003', 'Red wine (Rioja)', 'bottle'),
  ('a0a0a0a0-0000-4000-8000-000000000004', 'White wine',       'bottle'),
  ('a0a0a0a0-0000-4000-8000-000000000005', 'Craft beer',       'bottle'),
  ('a0a0a0a0-0000-4000-8000-000000000006', 'Orange juice',     'bottle'),
  ('a0a0a0a0-0000-4000-8000-000000000007', 'Cola',             'can'),
  ('a0a0a0a0-0000-4000-8000-000000000008', 'Espresso',         'unit')
) as v(id, name, denom);

-- ─────────────────────────────────────────────────────────────────────────
-- 6. FUTURE EVENT — "Summer Garden Party" (today + 7), buffet lunch, 10 guests
-- ─────────────────────────────────────────────────────────────────────────
-- Fixed id (regenerable, orphan-free) so its cover photo path stays valid.
insert into public.events
  (id, group_id, title, type, format, event_date, event_time, location_name, guest_count, notes)
values ('e0e0e0e0-0000-4000-8000-000000000001',
        '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52', 'Summer Garden Party',
        'lunch', 'buffet', current_date + 7, '13:00', 'Willowbrook Garden', 10,
        'Outdoor buffet in the garden — relaxed afternoon with friends.');

-- Menu: one dish per (catalog dish, course) — copied as event snapshots.
-- Greek salad is placed in the Starter course for this event (snapshot
-- category override; its catalog category is "other").
insert into public.event_dishes
  (event_id, source_dish_id, dish_name, category, servings, acquisition_mode, sort_order)
select e.id, d.id, d.name, v.cat::dish_category, 10, 'cooked', v.so
from (values
  ('Marinated olives',                       'aperitif', 0),
  ('Smoked salmon platter',                  'starter',  1),
  ('Greek salad',                            'starter',  2),
  ('Osso buco with saffron risotto',         'main',     3),
  ('Homemade ravioli with butter and sage',  'main',     4),
  ('Tiramisu',                               'dessert',  5),
  ('Fresh fruit salad',                      'dessert',  6)
) as v(dish, cat, so)
join public.events e
  on e.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and e.title = 'Summer Garden Party'
join public.dishes d
  on d.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and d.name = v.dish and d.deleted_at is null;

-- Copy each menu dish's recipe into event_dish_ingredients (snapshots).
insert into public.event_dish_ingredients
  (event_dish_id, ingredient_id, ingredient_name, quantity, unit_id, prep_note, sort_order, state, reference_servings)
select ed.id, di.ingredient_id, ing.name, di.quantity, di.unit_id, di.prep_note,
       di.sort_order, 'to_order'::ingredient_state, dsh.base_servings
from public.event_dishes ed
join public.events e on e.id = ed.event_id
join public.dishes dsh on dsh.id = ed.source_dish_id
join public.dish_ingredients di on di.dish_id = dsh.id
join public.ingredients ing on ing.id = di.ingredient_id
where e.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and e.title = 'Summer Garden Party';

-- ─────────────────────────────────────────────────────────────────────────
-- 7. SHOPPING (§6) — spread the future event's lines across all 5 states and
--    several suppliers (custom + system + pantry). Order: buckets, then a
--    catch-all for anything still unassigned.
-- ─────────────────────────────────────────────────────────────────────────
-- at_home → Pantry (system "pantry")
update public.event_dish_ingredients set
  state = 'at_home',
  supplier_category_id = (select id from public.supplier_categories where group_id is null and code = 'pantry')
where event_dish_id in (select ed.id from public.event_dishes ed join public.events e on e.id = ed.event_id
                        where e.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and e.title = 'Summer Garden Party')
  and ingredient_name in ('olive oil','sugar','garlic cloves','butter','fresh thyme','sage leaves','truffle oil');

-- received → Greengrocer (system)
update public.event_dish_ingredients set
  state = 'received',
  supplier_category_id = (select id from public.supplier_categories where group_id is null and code = 'greengrocer')
where event_dish_id in (select ed.id from public.event_dishes ed join public.events e on e.id = ed.event_id
                        where e.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and e.title = 'Summer Garden Party')
  and ingredient_name in ('tomato','basil','cucumber','lemons','parsley','kalamata olives','strawberries',
                          'blueberries','pineapple','fresh mint','spinach','carrots','celery stalks','yellow onion');

-- ordered → Sunrise Market (custom)
update public.event_dish_ingredients set
  state = 'ordered',
  supplier_category_id = (select id from public.supplier_categories where group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and code = 'sunrise_market')
where event_dish_id in (select ed.id from public.event_dishes ed join public.events e on e.id = ed.event_id
                        where e.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and e.title = 'Summer Garden Party')
  and ingredient_name in ('arborio rice','saffron threads','mascarpone','ladyfingers','cocoa powder',
                          'heavy cream','parmesan','ricotta','large eggs','feta cheese','00 flour','pastry flour');

-- missing → Blue Fin Fishmonger (custom)
update public.event_dish_ingredients set
  state = 'missing',
  supplier_category_id = (select id from public.supplier_categories where group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and code = 'blue_fin')
where event_dish_id in (select ed.id from public.event_dishes ed join public.events e on e.id = ed.event_id
                        where e.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and e.title = 'Summer Garden Party')
  and ingredient_name in ('smoked salmon','oysters');

-- to_order → Vineyard Wines (custom) for wines/coffee
update public.event_dish_ingredients set
  state = 'to_order',
  supplier_category_id = (select id from public.supplier_categories where group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and code = 'vineyard_wines')
where event_dish_id in (select ed.id from public.event_dishes ed join public.events e on e.id = ed.event_id
                        where e.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and e.title = 'Summer Garden Party')
  and ingredient_name in ('dry white wine','marsala wine','prosecco','espresso coffee');

-- to_order → Butcher (system) for meats
update public.event_dish_ingredients set
  state = 'to_order',
  supplier_category_id = (select id from public.supplier_categories where group_id is null and code = 'butcher')
where event_dish_id in (select ed.id from public.event_dishes ed join public.events e on e.id = ed.event_id
                        where e.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and e.title = 'Summer Garden Party')
  and ingredient_name in ('veal shanks','beef stock','beef tenderloin','whole goose');

-- catch-all: anything still unassigned → to_order at the Supermarket (system)
update public.event_dish_ingredients set
  state = 'to_order',
  supplier_category_id = (select id from public.supplier_categories where group_id is null and code = 'supermarket')
where event_dish_id in (select ed.id from public.event_dishes ed join public.events e on e.id = ed.event_id
                        where e.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and e.title = 'Summer Garden Party')
  and supplier_category_id is null;

-- ─────────────────────────────────────────────────────────────────────────
-- 8. GUESTS — the §4 matrix (state × restriction). Each guest appears in the
--    future event and a subset of the existing events. Note: the model has no
--    "unknown" diet for guests, so "unknown" and "none" both store all-false
--    (rendered identically — no diet pill); the traffic-light state differs.
--    diet flags: vegetarian / vegan / gluten_free.
-- ─────────────────────────────────────────────────────────────────────────
insert into public.event_guests
  (event_id, group_id, name, state, diet_vegetarian, diet_vegan, diet_gluten_free)
select e.id, '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52', v.name, v.state, v.veg, v.vegan, v.gf
from (values
  -- Summer Garden Party (future) — all 10, full matrix
  ('Summer Garden Party','Sarah Mitchell','confirmat', true,  false, false),
  ('Summer Garden Party','James Carter',  'pendent',   false, false, true ),
  ('Summer Garden Party','Emma Thompson', 'confirmat', false, true,  false),
  ('Summer Garden Party','Michael Brennan','excusat',  false, false, false),
  ('Summer Garden Party','Olivia Hayes',  'pendent',   false, false, false),
  ('Summer Garden Party','David Okafor',  'confirmat', false, false, false),  -- unknown→all false
  ('Summer Garden Party','Sophia Russo',  'confirmat', false, false, true ),
  ('Summer Garden Party','Liam Walsh',    'pendent',   false, true,  false),
  ('Summer Garden Party','Grace Bennett', 'excusat',   true,  false, false),
  ('Summer Garden Party','Noah Adams',    'confirmat', false, false, false),
  -- Christmas Eve Dinner (subset of 7, mixed states)
  ('Christmas Eve Dinner','Sarah Mitchell','confirmat', true,  false, false),
  ('Christmas Eve Dinner','James Carter',  'pendent',   false, false, true ),
  ('Christmas Eve Dinner','Emma Thompson', 'confirmat', false, true,  false),
  ('Christmas Eve Dinner','Michael Brennan','excusat',  false, false, false),
  ('Christmas Eve Dinner','Olivia Hayes',  'pendent',   false, false, false),
  ('Christmas Eve Dinner','David Okafor',  'confirmat', false, false, false),
  ('Christmas Eve Dinner','Sophia Russo',  'confirmat', false, false, true ),
  -- Garden Brunch (subset of 6)
  ('Garden Brunch','Emma Thompson', 'confirmat', false, true,  false),
  ('Garden Brunch','Liam Walsh',    'pendent',   false, true,  false),
  ('Garden Brunch','Grace Bennett', 'excusat',   true,  false, false),
  ('Garden Brunch','Noah Adams',    'confirmat', false, false, false),
  ('Garden Brunch','Olivia Hayes',  'pendent',   false, false, false),
  ('Garden Brunch','Sophia Russo',  'confirmat', false, false, true ),
  -- Italian Sunday Dinner (subset of 6)
  ('Italian Sunday Dinner','James Carter',  'pendent',   false, false, true ),
  ('Italian Sunday Dinner','Michael Brennan','excusat',  false, false, false),
  ('Italian Sunday Dinner','David Okafor',  'confirmat', false, false, false),
  ('Italian Sunday Dinner','Liam Walsh',    'pendent',   false, true,  false),
  ('Italian Sunday Dinner','Grace Bennett', 'excusat',   true,  false, false),
  ('Italian Sunday Dinner','Noah Adams',    'confirmat', false, false, false)
) as v(ev, name, state, veg, vegan, gf)
join public.events e
  on e.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and e.title = v.ev and e.deleted_at is null;

-- ─────────────────────────────────────────────────────────────────────────
-- 9. EVENT DRINKS — a few per event, referencing the catalog drinks.
--    (Garden Brunch already has a "Mimosa" as a dish; prosecco is a catalog
--    ingredient, not a catalog drink, so it's not added here as a drink.)
-- ─────────────────────────────────────────────────────────────────────────
insert into public.event_drinks
  (event_id, source_drink_id, drink_name, supplier_category_id, quantity, denomination, state, sort_order)
select e.id, d.id, d.name, d.supplier_category_id, v.qty, d.denomination, 'received'::ingredient_state, v.so
from (values
  ('Summer Garden Party','Red wine (Rioja)', 6, 0),
  ('Summer Garden Party','White wine',       6, 1),
  ('Summer Garden Party','Craft beer',      12, 2),
  ('Summer Garden Party','Still water',      8, 3),
  ('Summer Garden Party','Sparkling water',  6, 4),
  ('Summer Garden Party','Orange juice',     4, 5),
  ('Christmas Eve Dinner','Red wine (Rioja)',6, 0),
  ('Christmas Eve Dinner','White wine',      4, 1),
  ('Christmas Eve Dinner','Still water',     8, 2),
  ('Garden Brunch','Sparkling water',        6, 0),
  ('Garden Brunch','Orange juice',           4, 1),
  ('Garden Brunch','White wine',             4, 2),
  ('Italian Sunday Dinner','Red wine (Rioja)',6, 0),
  ('Italian Sunday Dinner','Still water',    6, 1)
) as v(ev, drink, qty, so)
join public.events e
  on e.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and e.title = v.ev and e.deleted_at is null
join public.drinks d
  on d.group_id = '1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and d.name = v.drink and d.deleted_at is null;

commit;

-- ============================================================================
-- VERIFY (after running):
--   select diet, count(*) from ingredients
--     where group_id='1f09045b-cacd-449a-a8a1-c7bdfb5bdc52' and deleted_at is null group by diet;
--   select count(*) from drinks  where group_id='1f09045b-cacd-449a-a8a1-c7bdfb5bdc52';      -- 8
--   select count(*) from event_guests where group_id='1f09045b-cacd-449a-a8a1-c7bdfb5bdc52'; -- 29
--   select state, count(*) from event_dish_ingredients edi
--     join event_dishes ed on ed.id=edi.event_dish_id
--     join events e on e.id=ed.event_id
--     where e.title='Summer Garden Party' group by state;  -- all 5 states present
-- ============================================================================
