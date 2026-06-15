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

En afegir un plat, si l'esdeveniment és assegut les racions s'ajusten al
nombre de convidats; si és bufet es manté el valor del catàleg. Sempre ho pots
retocar. Com a guia aproximada, un menú ben dimensionat sol rondar les 3-5
racions per convidat.

**ES** — Los platos del evento, por categoría. Arriba ves los totales:
platos, raciones y raciones por invitado. Los platos de aquí son copias:
editarlos no cambia el catálogo.

Al añadir un plato, si el evento es sentado las raciones se ajustan al número
de invitados; si es bufé se mantiene el valor del catálogo. Siempre puedes
retocarlo. Como guía aproximada, un menú bien dimensionado suele rondar las
3-5 raciones por invitado.

**EN** — The event's dishes, by category. The totals at the top show dishes,
servings, and servings per guest. Dishes here are copies — editing them
doesn't change the catalog.

When you add a dish, a seated event scales its servings to the guest count; a
buffet keeps the catalog value. You can always fine-tune. As a rough guide, a
well-balanced menu lands around 3-5 servings per guest.

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

## §2.5 — Getting started guide (GitHub Pages, English + PDF)

> A general getting-started guide for any new user (no tester framing, no
> feedback section). Two formats, same content:
> - GitHub Pages at docs/manual/index.md → .../entertain/manual/ (Jekyll
>   front matter like the privacy page).
> - PDF "Entertain - Getting started guide.pdf" for direct sending. It
>   REPLACES the earlier "Entertain - Tester guide.pdf" (delete the old one).
>
> Numbered step-by-step walk-through, one page. The in-app Getting Started
> card (§2.3) stays telegraphic; this is the full walk-through. Integrate the
> body below verbatim into docs/manual/index.md.

# Entertain — Getting started

## The big picture

Entertain helps you organize the meals you host at home: build a menu from
your own dishes, and the app works out the ingredients and hands you back a
shopping list sorted by supplier.

Two reusable catalogs sit at the core — your **ingredients** and your
**dishes** — which you build up over time. Then come the **events**: a lunch,
a dinner, a gathering. For each one you compose a menu from your dishes, and
the app turns it into a supplier-grouped shopping list. Build the catalogs
once, reuse them for every event.

## First time, step by step

If this is your first time in the app, follow these in order. After that,
you'll move around however you like.

**1. Set things up in Settings.** Open the Settings tab first. Set your
greeting and signature — these top and tail the order messages the app drafts
for suppliers, so they read like something you wrote. Then open Suppliers:
you'll see the built-in categories (butcher, fishmonger, greengrocer,
supermarket, pantry). Give the ones you use a name and a contact, so orders
go to the right place. *(Every main screen has a small help icon by its title
if you get stuck.)*

**2. Add a few ingredients.** In the Ingredients tab, add the things you cook
with. Each one gets a default unit (grams, units, a bottle…) and a default
supplier (which shop it comes from). Those defaults are what let the app build
a tidy shopping list later. Add just enough for your first dish — you can
always add more.

**3. Create a dish or two.** In the Dishes tab, create a dish: add its
ingredients with quantities, plus a base number of servings (how many people
the recipe is written for). A missing ingredient can be added to the catalog
right there, without leaving the dish.

**4. Create your first event.** In the Events tab, add an event: a type
(lunch, dinner), a format (seated, buffet), a date, and the number of guests.
Guest count and format both matter — they're what the app uses to work out
quantities, as the next step explains.

**5. Build the event's menu.** Open the event and go to its Menu tab. Add
dishes from your catalog. A dish added to an event becomes **its own copy**:
adjust its ingredients or servings for this occasion and the original catalog
dish stays exactly as it was.

How servings start depends on the format. A **seated** event scales each dish
to your guest count automatically — everyone gets a serving of each. A
**buffet** keeps the dish's catalog servings, since people serve themselves.
Either way, you can fine-tune afterwards.

At the top of the Menu tab there's a running total: dishes, servings, and
**servings per guest** — a quick check on whether you've planned enough food.
As a rough guide, a well-balanced menu lands around **3 to 5 servings per
guest** across the whole menu. It's a guideline, not a rule — a light lunch
sits lower, a feast higher. If you're far outside that range, take a second
look at your servings, especially for a buffet where you set them yourself.

**6. Shop by supplier.** Switch to the event's Shopping tab. Every ingredient
is gathered here, grouped by supplier, each with a status you tap through — to
order, ordered, received, already at home. Each supplier header shows the
running tally without opening it. When you're ready, the app drafts the order
message using the greeting and signature from step 1. You can also add
**extra** items to a supplier's order — things you want to buy that aren't
part of the event.
