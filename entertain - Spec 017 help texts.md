# entertain — Help & onboarding texts (Spec 017)

> Updated and new help copy for the polish + help pass. Claude Code integrates
> these verbatim into the ARB files (`help*Body`, `gettingStarted*`) and the
> GitHub Pages manual. Tone: telegraphic, warm, concrete. Three locales each:
> CA (primary), ES, EN.
>
> Sections:
> - §1 Corrections to existing help (drinks model changed in Spec 016)
> - §2 New selective help pop-ups (dish editor, drink editor, suppliers)
> - §3 Getting Started card (Settings) — updated
> - §4 Manual (docs/manual/index.md) — updated body

---

## §1 — Corrections to existing help

### §1.1 `helpDrinksBody` — drinks now units-only (Spec 016)

The old text described servings + an optional purchase unit. Drinks are now
**units of a denomination** (bottle, can…), set manually, with no servings and
no guest scaling. Replace with:

**CA** — Les begudes del teu catàleg. Cada beguda té un proveïdor i una
denominació (ampolla, llauna, garrafa…). A diferència dels plats, no porten
racions: a cada esdeveniment hi poses directament les unitats que vols (3
ampolles, 2 llaunes…). A la compra surten agrupades pel seu proveïdor.

**ES** — Las bebidas de tu catálogo. Cada bebida tiene un proveedor y una
denominación (botella, lata, garrafa…). A diferencia de los platos, no llevan
raciones: en cada evento pones directamente las unidades que quieres (3
botellas, 2 latas…). En la compra salen agrupadas por su proveedor.

**EN** — Your drinks catalog. Each drink has a supplier and a denomination
(bottle, can, jug…). Unlike dishes, drinks have no servings: for each event you
set the number of units directly (3 bottles, 2 cans…). In Shopping they appear
grouped by their supplier.

### §1.2 `helpMenuTabBody` — mention prepared dishes and drinks

Append to the existing Menu help (keep the format-scaling and 3–5 servings
guidance from Spec 012; add a sentence on prepared dishes and drinks):

**CA** (append) — El menú admet plats cuinats a casa i plats comprats fets, i
té una secció de begudes a part. Plats preparats i begudes es compren sencers
al seu proveïdor; les begudes no compten al càlcul de racions per persona.

**ES** (append) — El menú admite platos cocinados en casa y platos comprados
hechos, y tiene una sección de bebidas aparte. Platos preparados y bebidas se
compran enteros a su proveedor; las bebidas no cuentan en el cálculo de
raciones por persona.

**EN** (append) — The menu supports home-cooked and ready-bought dishes, and
has a separate drinks section. Prepared dishes and drinks are bought whole from
their supplier; drinks don't count toward the servings-per-guest figure.

---

## §2 — New selective help pop-ups

### §2.1 Dish editor — `helpDishEditorBody` (cooked/bought toggle)

**CA** — Un plat pot ser **cuinat a casa** o **comprat fet**. Cuinat: hi
afegeixes ingredients amb quantitats i l'app et calcula la compra. Comprat: no
té ingredients; només tries el proveïdor i les racions que dóna una unitat (per
exemple, una safata de canelons per a 4). A la compra, l'app calcula quantes
unitats necessites.

**ES** — Un plato puede ser **cocinado en casa** o **comprado hecho**. Cocinado:
le añades ingredientes con cantidades y la app calcula la compra. Comprado: no
tiene ingredientes; solo eliges el proveedor y las raciones que da una unidad
(por ejemplo, una bandeja de canelones para 4). En la compra, la app calcula
cuántas unidades necesitas.

**EN** — A dish can be **cooked at home** or **bought ready-made**. Cooked: you
add ingredients with quantities and the app works out the shopping. Bought: no
ingredients; you just pick the supplier and how many servings one unit provides
(say, a tray of cannelloni serving 4). In Shopping, the app computes how many
units you need.

### §2.2 Drink editor — `helpDrinkEditorBody` (denomination / no scaling)

**CA** — Defineix una beguda amb el seu proveïdor i la seva denominació
(ampolla, llauna, garrafa…). Les begudes no porten racions ni s'escalen pels
convidats: a cada esdeveniment hi poses tu les unitats que vols.

**ES** — Define una bebida con su proveedor y su denominación (botella, lata,
garrafa…). Las bebidas no llevan raciones ni se escalan por los invitados: en
cada evento pones tú las unidades que quieres.

**EN** — Define a drink with its supplier and its denomination (bottle, can,
jug…). Drinks have no servings and don't scale with guests: for each event you
set the units yourself.

### §2.3 Supplier category detail — `helpSuppliersBody` (multiple + default)

**CA** — Cada categoria pot tenir diversos proveïdors (per exemple, dues
carnisseries). Marca'n un com a **predeterminat**: és el que es proposa quan
generes una comanda, però el pots canviar en aquell moment. El primer proveïdor
que afegeixes queda com a predeterminat automàticament.

**ES** — Cada categoría puede tener varios proveedores (por ejemplo, dos
carnicerías). Marca uno como **predeterminado**: es el que se propone al generar
un pedido, pero puedes cambiarlo en ese momento. El primer proveedor que añades
queda como predeterminado automáticamente.

**EN** — Each category can have several suppliers (e.g. two butchers). Mark one
as **default**: it's the one proposed when you generate an order, but you can
change it then. The first supplier you add becomes the default automatically.

---

## §3 — Getting Started card (Settings) — updated

Five short steps (keys `gettingStartedStep1..5`). Updated to reflect the
grouped Catàleg, prepared dishes/drinks, and multiple suppliers. Keep
telegraphic.

**CA**
1. A Configuració, posa la teva salutació i signatura, i dona nom als
   proveïdors que faràs servir.
2. Al Catàleg, afegeix ingredients (amb unitat i proveïdor) i begudes.
3. Crea plats: cuinats a casa (amb ingredients) o comprats fets (d'un
   proveïdor).
4. Crea un esdeveniment i munta'n el menú amb plats i begudes.
5. A Compra, l'app agrupa tot per proveïdor i en prepara els missatges.

**ES**
1. En Ajustes, pon tu saludo y firma, y da nombre a los proveedores que vayas a
   usar.
2. En el Catálogo, añade ingredientes (con unidad y proveedor) y bebidas.
3. Crea platos: cocinados en casa (con ingredientes) o comprados hechos (de un
   proveedor).
4. Crea un evento y monta su menú con platos y bebidas.
5. En Compra, la app agrupa todo por proveedor y prepara los mensajes.

**EN**
1. In Settings, set your greeting and signature, and name the suppliers you'll
   use.
2. In the Catalog, add ingredients (with a unit and supplier) and drinks.
3. Create dishes: cooked at home (with ingredients) or bought ready-made (from a
   supplier).
4. Create an event and build its menu with dishes and drinks.
5. In Shopping, the app groups everything by supplier and drafts the messages.

---

## §4 — Manual (docs/manual/index.md) — updated body (EN)

The web manual / getting-started guide, updated to include the grouped Catalog,
prepared dishes, drinks, and multiple suppliers. Integrate as the manual body
(and regenerate the PDF). Builds on the Spec 012 §2.5 structure.

# Entertain — Getting started

## The big picture

Entertain helps you organize the meals you host at home: build a menu from your
own dishes and drinks, and the app works out the shopping, grouped by supplier.

Three reusable catalogs sit at the core — your **ingredients**, your **dishes**,
and your **drinks** — grouped under the **Catalog** tab. Then come the
**events**: for each one you build a menu and the app turns it into a
supplier-grouped shopping list. Build the catalogs once, reuse them for every
event.

## First time, step by step

**1. Set things up in Settings.** Set your greeting and signature (they top and
tail the order messages). Open Suppliers and name the shops you use — a category
(butcher, fishmonger…) can hold several suppliers, with one marked default.

**2. Add ingredients and drinks.** In the Catalog tab: add ingredients (each
with a default unit and supplier) and drinks (each with a supplier and a
denomination — bottle, can, jug…).

**3. Create dishes.** A dish is either **cooked at home** (you add ingredients
with quantities) or **bought ready-made** (you pick a supplier and the servings
one unit provides). Cooked dishes drive the shopping list from their
ingredients; bought dishes are a single purchase line.

**4. Create an event.** Give it a type, a format (seated or buffet), a date, and
the number of guests — format and guests are what the app uses to scale
quantities.

**5. Build the menu.** Add dishes (cooked or bought) and, in the drinks section,
drinks. A dish added to an event becomes its own copy you can fine-tune.
Servings scale with the format (seated → guests; buffet → catalog value);
drinks don't scale — you set the number of units. A well-balanced menu tends to
land around 3–5 servings per guest (food only; drinks aren't counted).

**6. Shop by supplier.** In the event's Shopping tab everything is grouped by
supplier — ingredients, prepared dishes, and drinks. Pick the supplier when a
category has more than one, and the app drafts the order message with your
greeting and signature.
