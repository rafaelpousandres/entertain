# Entertain — Help & onboarding texts (Spec 012)

> Final copy for §2.3 (Getting Started card), §2.4 (per-screen help
> pop-ups), and §2.5 (tester manual). Claude Code integrates these verbatim
> into ARB files and the GitHub Pages manual. Tone: telegraphic, warm,
> no jargon. The app's usability does the rest.

---

## §2.3 — Getting Started card (Settings ▸ General)

### CA
**Primers passos**
1. Crea un esdeveniment: tipus, format, data i convidats.
2. Omple els catàlegs d'ingredients i plats.
3. Afegeix plats al menú de l'esdeveniment.
4. Els plats afegits a un esdeveniment es poden editar sense tocar el plat
   del catàleg: cada esdeveniment en guarda una còpia pròpia.
5. La pestanya Compra ho agrupa tot per proveïdor.

### ES
**Primeros pasos**
1. Crea un evento: tipo, formato, fecha e invitados.
2. Rellena los catálogos de ingredientes y platos.
3. Añade platos al menú del evento.
4. Los platos añadidos a un evento se pueden editar sin tocar el plato del
   catálogo: cada evento guarda su propia copia.
5. La pestaña Compra lo agrupa todo por proveedor.

### EN
**Getting started**
1. Create an event: type, format, date, and guests.
2. Fill in your ingredient and dish catalogs.
3. Add dishes to the event's menu.
4. Dishes added to an event can be edited without changing the catalog
   dish — each event keeps its own copy.
5. The Shopping tab groups everything by supplier.

---

## §2.4 — Per-screen help pop-ups

### Events list

**CA** — Aquí veus tots els esdeveniments, agrupats per estat: en
preparació, a punt i passats. Toca'n un per obrir-lo, o crea'n un de nou
amb el botó de baix.

**ES** — Aquí ves todos los eventos, agrupados por estado: en preparación,
listos y pasados. Toca uno para abrirlo, o crea uno nuevo con el botón de
abajo.

**EN** — All your events, grouped by status: in preparation, ready, and
past. Tap one to open it, or create a new one with the button below.

### Event detail — Event tab

**CA** — Les dades de l'esdeveniment: títol, tipus, format, data, convidats
i fotos. El nombre de convidats escala les quantitats dels plats.

**ES** — Los datos del evento: título, tipo, formato, fecha, invitados y
fotos. El número de invitados escala las cantidades de los platos.

**EN** — The event's details: title, type, format, date, guests, and
photos. The guest count scales the dish quantities.

### Event detail — Menu tab

**CA** — Els plats de l'esdeveniment, per categoria. A dalt veus els totals:
plats, racions i racions per convidat. Els plats d'aquí són còpies: editar-los
no canvia el catàleg.

**ES** — Los platos del evento, por categoría. Arriba ves los totales:
platos, raciones y raciones por invitado. Los platos de aquí son copias:
editarlos no cambia el catálogo.

**EN** — The event's dishes, by category. The totals at the top show dishes,
servings, and servings per guest. Dishes here are copies — editing them
doesn't change the catalog.

### Event detail — Shopping tab

**CA** — Tots els ingredients a comprar, agrupats per proveïdor. Cada
proveïdor mostra quants en falten, demanats i rebuts. Pots afegir extres i
enviar la comanda directament.

**ES** — Todos los ingredientes a comprar, agrupados por proveedor. Cada
proveedor muestra cuántos faltan, pedidos y recibidos. Puedes añadir extras
y enviar el pedido directamente.

**EN** — Everything to buy, grouped by supplier. Each supplier shows how
many are pending, ordered, and received. You can add extras and send the
order directly.

### Dishes catalog

**CA** — El teu catàleg de plats, per categoria. Cada plat té els seus
ingredients i racions base. Afegeix-los als esdeveniments des de la pestanya
Menú.

**ES** — Tu catálogo de platos, por categoría. Cada plato tiene sus
ingredientes y raciones base. Añádelos a los eventos desde la pestaña Menú.

**EN** — Your dish catalog, by category. Each dish has its ingredients and
base servings. Add them to events from the Menu tab.

### Ingredients catalog

**CA** — El teu catàleg d'ingredients, per proveïdor. Cada ingredient té una
unitat i un proveïdor per defecte que es fan servir a les llistes de compra.

**ES** — Tu catálogo de ingredientes, por proveedor. Cada ingrediente tiene
una unidad y un proveedor por defecto que se usan en las listas de compra.

**EN** — Your ingredient catalog, by supplier. Each ingredient has a default
unit and supplier used in the shopping lists.

---

## §2.5 — Tester manual (GitHub Pages, English + PDF)

> Two formats, same content:
> - GitHub Pages at docs/manual/index.md → .../entertain/manual/ (Jekyll
>   front matter like the privacy page).
> - A PDF version ("Entertain - Tester guide.pdf") for direct sending to
>   testers who prefer a file over a link. The PDF is already produced and
>   committed alongside this doc; the GitHub Pages page mirrors its content.
>
> The manual is a real getting-started guide with a numbered step-by-step
> section, not just an expanded version of the in-app Getting Started card.
> Length: ~2 pages. The in-app Getting Started card (§2.3) stays telegraphic;
> this manual is the walk-through.

# Entertain — A short guide for testers

Thanks for taking the time to try Entertain. It's an app for organizing the
meals and gatherings you host at home — the kind of planning that usually
lives in scattered notes, group chats, and last-minute supermarket runs. The
idea is to keep all of it in one calm place: you build a menu from your own
dishes, the app works out the ingredients, and it hands you back a shopping
list already sorted by the supplier you'll buy each thing from.

## The big picture

There are two reusable catalogs — your **ingredients** and your **dishes** —
that you build up over time. Then there are **events**: a lunch, a dinner, a
gathering. For each event you compose a menu from your dishes, and the app
turns that into a shopping list grouped by supplier. Build the catalogs once,
reuse them for every event.

## First time, step by step

If this is your first time opening the app, here's the smoothest way to get
going. Follow it in order the first time; after that, you'll jump around
however you like.

**1. Set things up in Settings.** Open the Settings tab first. Set your
greeting and signature — these are used at the top and bottom of the order
messages the app drafts for your suppliers, so they read like something you
actually wrote. Then look at Suppliers: you'll see the built-in categories
(butcher, fishmonger, greengrocer, supermarket, pantry). Give the ones you
use a name and a contact, so orders can go straight to the right place.
*(The General section also has a Getting Started card and your account
details. Every main screen has a small help icon next to its title if you
get stuck.)*

**2. Add a few ingredients.** Go to the Ingredients tab and add the things
you cook with. For each one you set a default unit (grams, units, a
bottle…) and a default supplier (which shop it comes from). Those two
defaults are what let the app build a tidy shopping list later. You don't
have to add everything at once — just enough to build your first dish.

**3. Create a dish or two.** In the Dishes tab, create a dish and add its
ingredients with quantities, plus a base number of servings (how many people
the recipe is written for). If you realize an ingredient is missing, you can
add it to the catalog right there without leaving the dish — both ways work.

**4. Create your first event.** Go to the Events tab and add an event. Give
it a type (lunch, dinner), a format (seated, buffet), a date, and the number
of guests. That guest count is important: it's what the app uses to scale
your dish quantities to the size of the gathering.

**5. Build the event's menu.** Open your event and go to its Menu tab. Add
dishes from your catalog. Here's the one thing really worth remembering: a
dish added to an event becomes **its own copy**. Adjust its ingredients or
quantities for this particular occasion and your original catalog dish stays
exactly as it was. The Menu tab keeps a running total — dishes, servings,
and servings per guest — so you can see at a glance whether you've planned
enough food.

**6. Shop by supplier.** Switch to the event's Shopping tab. Every ingredient
from your menu is gathered here and grouped by supplier. Each item has a
status you can tap through — to order, ordered, received, already at home —
and each supplier header shows the running tally without having to open it.
When you're ready, the app drafts the order message for you, using the
greeting and signature you set in step 1. You can also add a few **extra**
items to a supplier's order — things you want to buy that aren't part of the
event.

## A few more things

Events, dishes, and ingredients can each carry a few photos; the first one
becomes the cover everywhere it appears. The app follows your phone's
language — Catalan, Spanish, or English. And if you ever want your data
removed, your account ID is in Settings, under Privacy & data.

## What helps us most

Use it for something real if you can — plan an actual meal and walk the whole
flow. The feedback we value most isn't about big crashes; it's the small
moments where something felt confusing, slower than it should be, or just not
where you expected it. Those are hard for us to see from the inside and easy
for you to spot. Tell us about them — and thanks again for the help.
