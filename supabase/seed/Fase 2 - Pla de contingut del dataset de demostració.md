# Fase 2 — Pla de contingut del dataset de demostració (seed regenerable)

> **Objectiu:** un dataset ric en **anglès**, al grup `1f09045b-cacd-449a-a8a1-c7bdfb5bdc52`,
> dissenyat perquè els **screenshots** (fitxa de Play, manual, demos) ensenyin **totes** les
> funcionalitats actuals: badges dietètics (VGN/VGT/SG/?), semàfor de convidats, ordre canònic
> de plats, full resum, compra per urgència.
>
> **Forma d'execució:** **seed script net i regenerable** (Opció 2). El seed incorpora el
> contingut bo existent (61 ingredients + 15 plats + receptes) **amb** la classificació
> dietètica afegida, i hi afegeix tot el nou (convidats, begudes, event futur, compra). Executar
> el seed deixa el grup en aquest estat conegut; reexecutar-lo el regenera net (idempotent).
>
> **Principi de disseny:** varietat deliberada — cada bloc cobreix tot l'espectre d'una funció,
> perquè una sola captura ensenyi el màxim.
>
> **Decisió tècnica oberta (CC):** com tractar les fotos existents a `media`/Storage en un seed
> net — re-referenciar pels paths existents o mantenir-les a part. CC ho resol.

---

## 1. Catàleg d'ingredients — classificació dietètica

Es conserven els **61 ingredients existents** (noms i fotos), ara **classificats**. La taula
fixa `diet` (vegan / vegetarian / none / unknown) i `gluten` (yes = gluten-free / no = conté
gluten / unknown). Disseny perquè el catàleg ensenyi **tots** els casos de badge, inclòs algun
"?" deixat expressament.

Llegenda: **diet** = vegan (V) / vegetarian (Vt) / none-meat·fish (N) / unknown (?);
**gluten** = GF (sense gluten) / G (conté gluten) / ? (desconegut).

| Ingredient | diet | gluten | Nota |
|---|---|---|---|
| 00 flour | vegan | G | farina de blat |
| apples | vegan | GF | |
| arborio rice | vegan | GF | |
| avocado | vegan | GF | |
| baguette | vegan | G | |
| basil | vegan | GF | |
| bean sprouts | vegan | GF | |
| beef stock | none | GF | origen carn |
| beef tenderloin | none | GF | |
| blueberries | vegan | GF | |
| butter | vegetarian | GF | làctic |
| capers | vegan | GF | |
| carrots | vegan | GF | |
| celery stalks | vegan | GF | |
| chestnuts | vegan | GF | |
| cocoa powder | vegan | GF | |
| cream cheese | vegetarian | GF | làctic |
| cucumber | vegan | GF | |
| dark chocolate | vegan | GF | (assumim sense llet; deixa vegan) |
| dry white wine | vegan | GF | |
| espresso coffee | vegan | GF | |
| feta cheese | vegetarian | GF | làctic |
| firm tofu | vegan | GF | |
| fresh mint | vegan | GF | |
| fresh orange juice | vegan | GF | |
| fresh thyme | vegan | GF | |
| garlic cloves | vegan | GF | |
| heavy cream | vegetarian | GF | làctic |
| kalamata olives | vegan | GF | |
| ladyfingers | vegetarian | G | ou + farina |
| large eggs | vegetarian | GF | |
| lemons | vegan | GF | |
| limes | vegan | GF | |
| marsala wine | vegan | GF | |
| mascarpone | vegetarian | GF | làctic |
| mushrooms | vegan | GF | |
| olive oil | vegan | GF | |
| oysters | none | GF | marisc |
| parmesan | vegetarian | GF | làctic (deixem vegetarian; el quall és un detall que ometem a la demo) |
| parsley | vegan | GF | |
| pastry flour | vegan | G | |
| peanuts | vegan | GF | |
| pineapple | vegan | GF | |
| potatoes | vegan | GF | |
| prosecco | vegan | GF | |
| puff pastry | vegetarian | G | sol portar mantega |
| rice noodles | vegan | GF | |
| ricotta | vegetarian | GF | làctic |
| saffron threads | vegan | GF | |
| sage leaves | vegan | GF | |
| smoked salmon | none | GF | peix |
| sourdough bread | vegan | G | |
| soy sauce | vegan | G | conté blat |
| spinach | vegan | GF | |
| strawberries | vegan | GF | |
| sugar | vegan | GF | |
| tomato | vegan | GF | |
| truffle oil | vegan | GF | |
| veal shanks | none | GF | carn |
| whole goose | none | GF | carn |
| yellow onion | vegan | GF | |

**Dos "?" deixats expressament** (per ensenyar el badge desconegut al catàleg i propagar-lo a
algun plat): deixa **`espresso coffee`** i **`dark chocolate`** amb `diet = unknown` i
`gluten = unknown` *en lloc* dels valors de dalt. (Trien-se aquests dos perquè apareixen al
Tiramisu i al Yule log → faran que aquells postres mostrin "?", il·lustrant la propagació de
l'incògnit. Si prefereixes no embrutar postres concrets, deixa el "?" en dos ingredients no
usats en cap plat — decisió menor; recomano els dos proposats per ensenyar la propagació.)

---

## 2. Catàleg de begudes (nou — actualment 0)

Afegir **8 begudes** de catàleg, amb classificació per ensenyar badges també a begudes:

| Beguda | diet | gluten | Nota |
|---|---|---|---|
| Still water | vegan | GF | |
| Sparkling water | vegan | GF | |
| Red wine (Rioja) | vegan | GF | |
| White wine | vegan | GF | |
| Craft beer | vegan | **G** | conté gluten — ensenya SG-negatiu (cap badge SG) |
| Orange juice | vegan | GF | |
| Cola | vegan | GF | |
| Espresso | vegan | GF | |

(La cervesa amb gluten és deliberada: contrasta amb les altres SG.)

---

## 3. Catàleg de plats

Es conserven els **15 plats existents** (noms + receptes). La classificació dietètica de cada
plat **es deriva automàticament** dels seus ingredients (no es fixa a mà) — per això classificar
els ingredients (§1) és la feina clau. Recordatori dels 15 plats i la categoria:

- **Starter:** Bruschetta with tomato and basil · Oysters on ice · Smoked salmon platter
- **Main:** Avocado toast with poached egg · Beef Wellington · Homemade ravioli with butter and
  sage · Osso buco with saffron risotto · Pad Thai · Roasted goose with chestnut stuffing
- **Dessert:** Chocolate yule log · Fresh fruit salad · Tiramisu
- **Drink (com a plat):** Mimosa
- **Other:** Greek salad · Mashed potatoes with truffle oil

Badges derivats esperats (per verificar després): Oysters/Smoked salmon/Beef Wellington/Osso
buco/Roasted goose → **no-veg**; Bruschetta/Greek salad (sense feta? amb feta → vegetarian) →
veg/vegan; Tiramisu/Yule log → "?" (pels dos ingredients unknown del §1). Greek salad amb feta
→ vegetarian; si porta pa (no) seria amb gluten. *(CC verifica els badges derivats reals.)*

---

## 4. Convidats — la matriu estat × restricció (cor del semàfor)

L'eix més important per als screenshots: una llista de convidats que cobreixi **tots** els
estats (semàfor) i **totes** les restriccions (pastilles), perquè una captura ho ensenyi tot.

Estats: **confirmed** (verd) · **pending** (taronja) · **excused** (vermell).
Restriccions: vegan · vegetarian · gluten-free · none · unknown.

**10 convidats** (noms anglesos creïbles), repartits per cobrir la matriu. S'assignen a l'event
futur (§5) i alguns també als events existents:

| Convidat | Estat | Restricció dietètica |
|---|---|---|
| Sarah Mitchell | confirmed (verd) | vegetarian |
| James Carter | pending (taronja) | gluten-free |
| Emma Thompson | confirmed (verd) | vegan |
| Michael Brennan | excused (vermell) | none |
| Olivia Hayes | pending (taronja) | none |
| David Okafor | confirmed (verd) | unknown |
| Sophia Russo | confirmed (verd) | gluten-free |
| Liam Walsh | pending (taronja) | vegan |
| Grace Bennett | excused (vermell) | vegetarian |
| Noah Adams | confirmed (verd) | none |

Cobertura: 3 estats presents, 5 tipus de restricció presents, encreuats. Una captura de la
llista de convidats ensenya el semàfor sencer **i** totes les pastilles dietètiques.

(Els convidats poden tenir email/telèfon ficticis si el model ho permet — CC decideix els camps
opcionals; res de dades reals.)

---

## 5. Events

Es conserven els **3 existents** (Christmas Eve Dinner, Garden Brunch, Italian Sunday Dinner) i
s'hi **afegeixen convidats i begudes**. S'afegeix **1 event futur** com a estrella dels
screenshots (els 3 existents són passats → secció plegada).

### Event nou (futur, estrella)
- **Nom:** Summer Garden Party
- **Data:** ~1 setmana en el futur des d'avui (CC posa una data futura concreta, p.ex. avui+7).
- **Format:** buffet · **Tipus:** lunch · **Comensals:** 10.
- **Convidats:** els 10 de §4 (cobreix tot el semàfor i restriccions).
- **Menú** (totes les categories, per ensenyar ordre canònic + full resum):
  - Aperitiu: (afegir-ne un, p.ex. una versió de Bruschetta o un nou "Marinated olives")
  - Entrant: Smoked salmon platter · Greek salad
  - Principal: Osso buco with saffron risotto · Homemade ravioli with butter and sage
  - Postre: Tiramisu · Fresh fruit salad
  - Begudes: Red wine, White wine, Craft beer, Still/Sparkling water, Orange juice (del §2)
- **Compra:** generada (§6).

### Events existents (completar)
- **Christmas Eve Dinner:** afegir 6-8 convidats (subconjunt de §4, estats variats) + begudes
  (vi, aigua...). Afegir portada (no en té).
- **Garden Brunch:** afegir convidats + begudes (Mimosa hi encaixa; prosecco + orange juice).
- **Italian Sunday Dinner:** afegir convidats + begudes (vi italià, aigua).

---

## 6. Compra — estats variats (urgència + semàfor de compra)

Per a l'event futur (Summer Garden Party), generar la llista de compra amb ingredients en
**tots els estats**, repartits entre **proveïdors diferents** (per ensenyar les seccions per
proveïdor a mode Comandes + l'ordre per urgència):

Estats a cobrir: **to order** · **missing** · **ordered** · **received** · **at home**.

- Repartir els ingredients del menú futur entre aquests 5 estats (uns quants a cada un).
- Assignar-los a 2-3 proveïdors diferents (p.ex. Supermarket, Fishmonger, Wine shop) + alguns a
  El rebost (at home).
- Així la pantalla de compra ensenya: ordre per urgència (to order dalt → at home baix),
  alfabètic dins de cada estat, seccions per proveïdor, i el semàfor d'estats.

---

## 7. Fotos (opcional, segons quant polir)

Cobertura actual: 9/15 plats, 11/61 ingredients, portades 0/1/4. Per a screenshots impecables
caldria completar, però és **opcional** i pot anar en una passada posterior. Prioritat si es fa:
1. **Portada de cada event** (sobretot l'event futur i Christmas Eve, que no en tenen).
2. **Fotos dels plats del menú de l'event futur** (els que sortiran als screenshots).
3. Ingredients destacats.

(Les fotos es poden afegir des de l'app via Pexels/càmera, o CC pot deixar-ho documentat com a
pas manual. Decisió: probablement més pràctic afegir-les tu des de l'app al perfil de proves,
ja que la cerca de Pexels hi funciona.)

---

## Notes d'execució per a CC

- **Seed net regenerable (Opció 2):** el seed defineix tot l'estat del grup `1f09` i, en
  executar-se, el deixa exactament així (idempotent). Incorpora el contingut existent
  (ingredients/plats/receptes) materialitzat al seed + la classificació + tot el nou.
- **Fotos:** decideix com tractar `media`/Storage en un seed net (re-referenciar paths existents
  o deixar-les a part). Si és complex, el seed pot recrear dades i deixar les fotos com a pas a
  part — explica-ho.
- **Badges derivats:** no es fixen a mà als plats; es deriven dels ingredients. Verifica que els
  badges resultants dels plats/events són els esperats després de classificar.
- **Regenerable:** documenta com reexecutar el seed (i què esborra/recrea) perquè jo el pugui
  regenerar quan embruti el dataset provant.
- **Tot en anglès.** Cap dada personal real.
- **Mostra el SQL/seed i explica en paraules què fa abans d'executar-lo sobre la BD** (regla de
  migracions/dades). El seed toca dades reals del grup de proves.

## Verificació (al segon perfil, després del seed)
1. Catàleg d'ingredients: badges VGN/VGT/SG/? variats, inclòs algun "?".
2. Catàleg de plats: badges derivats correctes; Tiramisu/Yule log mostren "?".
3. Begudes: 8 al catàleg, cervesa sense badge SG (té gluten).
4. Convidats (event futur): semàfor complet (verd/taronja/vermell) + totes les pastilles.
5. Menú de l'event futur: ordre canònic (aperitius→...→begudes).
6. Full resum de l'event futur: títols per categoria, ordre canònic, línies de dos gruixos,
   badges, convidats amb restriccions.
7. Compra: ordre per urgència, alfabètic dins, seccions per proveïdor, estats amb color.
