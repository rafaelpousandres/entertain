# entertain — Decisions de disseny

> Notes consolidades d'una sessió de disseny. Recullen quatre temes: plats preparats i begudes, l'importador d'URL, la regla d'unitats, i el mapeig d'ingredients al catàleg. Pendent d'incorporar al document/repo del projecte.

---

## 1. Plats preparats i begudes (ítems de menú no descomponibles)

### Principi

Un plat es pot obtenir de dues maneres, marcades amb un **toggle** a nivell de plat:

- **Cuinat a casa** — recepta que es descompon en ingredients, amb proveïdors d'ingredients.
- **Comprat fet** — d'un **proveïdor de plats preparats**, no es descompon.

Les **begudes** segueixen la mateixa forma que el plat preparat: ítem de menú no descomponible, d'un proveïdor, que s'afegeix directament al menú i genera la seva pròpia línia de compra.

### El cas degenerat

Plats preparats i begudes **no són un mecanisme nou**: són el cas degenerat del plat amb recepta. Es descomponen en una sola línia —ells mateixos— en comptes de en ingredients. La canonada de compra (resoldre → agregar) és la mateixa; només canvia que la descomposició té longitud 1. El gros del disseny ja està fet amb els plats amb recepta; el que queda és UI i etiquetatge.

### Regla neta

> El menú es fa d'**ítems de menú**; els **ingredients** són components que només arriben a la compra a través d'un plat cuinat.

### Una cosa, dos rols

El mateix producte pot existir com a beguda-de-menú i com a ingredient (vi blanc per beure / vi blanc al risotto). No s'han de fer excloents; el cas "s'hi cuina" ja el cobreix el mecanisme d'ingredients.

### Estructura compartida

Plat preparat i beguda són la mateixa forma (ítem no descomponible + proveïdor + una línia de compra). Millor **compartir estructura** i distingir-los amb una etiqueta (menjar / beguda) per a filtres i visualització, que no pas fer catàlegs separats.

### Granularitat del proveïdor

El proveïdor de plats preparats s'assembla al d'ingredients, però la granularitat canvia: aquí el producte **és** el plat (1 SKU = 1 plat), no una peça repartida entre molts plats. A la llista de compra, un plat comprat genera **una sola línia** ("1 × truita de patates — Mantequerías Pirenaicas"), sense explotar a ingredients.

### Decisions

- **MVP**: la versió cuinada i la comprada del mateix plat es tracten com a **dos plats diferents**, cadascun amb el seu toggle. Camí ràpid per arrencar.
- **Model de dades**: guardar el "mode d'obtenció" com a **atribut** des del primer dia, encara que la UI mostri dues entrades. Permet unificar després (comparar cost casolà vs. comprat, intercanviar amb un toc, "aquest plat, 2 maneres") **sense migració**.
- **Quantitats**: el cuinat escala per **ració** (quantitat d'ingredient); preparats i begudes escalen per **format** (ampolles, llaunes, litres, unitats) i heurística per persona.

---

## 2. Importador d'URL → plat + ingredients

**Primera opció premium.** Resol una fricció real (entrar receptes a mà és pesat), amb valor immediat i mesurable. Encaixa net: la sortida és el mateix plat-amb-ingredients de sempre; l'importador és només una **font d'entrada alternativa**, no un mecanisme nou.

### Què s'extreu

Nom, racions, temps, dificultat, foto, ingredients (quantitat + unitat + nom normalitzats) i passos.

### Fiabilitat

- Quan la web porta **JSON-LD `Recipe`** (schema.org), l'extracció és neta i fiable.
- Quan no, cal raspar l'HTML i és més fràgil, sobretot en **quantitats** ("un pessic", "al gust", "1 got", "1.5 preses").
- L'importador hauria de marcar amb *flags* els ingredients ambigus (unitat no estàndard, quantitat no especificada) perquè l'usuari els confirmi abans de fiar-s'hi.
- **Contrast passos vs. llista d'ingredients**: cal avisar de discrepàncies (ingredients que apareixen als passos però no a la llista, i viceversa). Passa sovint.

### Vincle amb la font (a guardar)

- **`url_font`**, **`nom_font`**, **`data_importacio`** — procedència, atribució, i poder reimportar/refrescar.
- **`hash_font`** o snapshot dels camps clau — perquè si la web cau o canvia, no es perdi el que es va importar (la URL sola és un vincle fràgil → *link rot*).

### Avisos (perquè és premium i de cara enfora)

- **Drets**. Importar per a ús personal ≠ redistribuir text de receptes de tercers dins d'un producte de pagament. Mostrar atribució hi ajuda; per a algunes fonts el net pot ser **enllaçar + foto + ingredients** i no copiar els passos sencers. Decidir-ho aviat.
- **Foto**: per a premium, **copiar-la** a l'emmagatzematge propi en comptes de fer *hotlink* (es pot trencar o bloquejar). Reforça la necessitat de tenir clars els drets.

---

## 3. Regla d'unitats i immutabilitat d'esdeveniments

**Pregunta que ho motiva**: si un ingredient s'ha fet servir en un esdeveniment i després canviem les seves unitats (de g a pot o a unitat), què passa?

### Mode de fallada a evitar

Si la unitat viu a **l'ingredient** i l'ús només guarda un número, canviar la unitat de l'ingredient **reinterpreta silenciosament tot l'històric**: aquell "200" que volia dir 200 g passa a voler dir 200 pots. Corrupció de dades sense avís.

### Model correcte

- **La unitat pertany a la línia d'ús** (recepta o esdeveniment), no a l'ingredient. Cada ús guarda `{quantitat, unitat}` autodescriptiu. L'ingredient defineix una unitat **canònica** i les unitats permeses amb factors, però no imposa res retroactivament.
- **Guardar internament en unitat base per dimensió** (massa → g, volum → ml, compte → unitat). La unitat que l'usuari veu és presentació. Passar de g a kg és cosmètic i no toca cap dada.
- **Canviar de dimensió** (massa ↔ unitat ↔ format/pot) és l'únic canvi que altera el significat, i requereix un **factor específic de l'ingredient** ("1 pot = 400 g", "1 ceba ≈ 150 g"). Sense factor, no es pot fusionar aquell ingredient a la compra → línia a part i marcat.
- **Els esdeveniments passats són immutables**, com una factura: són història, no es reescriuen. Els esdeveniments futurs/planificats sí que poden re-resoldre's contra el catàleg actual.

> L'esdeveniment guarda *què es va fer servir, en la unitat d'aleshores*; el catàleg guarda *com es mesura ara*. Separant les dues coses, canviar unitats és segur per construcció.

---

## 4. Mapeig d'ingredients al catàleg (la part difícil)

El repte central de l'importador no és extreure, sinó **casar** el que s'ha extret amb el catàleg existent. Té **dues dimensions**, no una:

- **Ingredient**: "sípia" (de la font) → entrada del catàleg. Inclou variants ortogràfiques ("sèpia"/"sípia"), sinònims, i nivells de detall diferents.
- **Unitat**: "1.5 preses", "1 got" → la representació canònica de l'ingredient del catàleg, amb el factor de conversió corresponent.

És el mateix problema de resolució aplicat dos cops. Quan no es pot resoldre (ingredient nou, o unitat sense factor), la sortida segura és **deixar-ho en línia a part i marcar-ho** per a confirmació de l'usuari, mai fusionar a cegues.

---

## Estat / pendents

- [ ] Fixar el contracte de sortida de l'importador (esquema dels camps).
- [ ] Decidir política de drets per font (passos sencers vs. enllaç + foto + ingredients).
- [ ] Confirmar **on viu la unitat** al model actual (entitat ingredient vs. línia d'ús) i, si cal, moure-la a la línia d'ús.
- [ ] Definir l'estratègia de mapeig ingredient↔catàleg i unitat↔canònica (matching, sinònims, factors per ingredient).

---

## Refinaments de la sessió de 16-17 juny 2026

> Decisions preses en sessió posterior, que actualitzen i precisen els punts anteriors.

### Regla d'agregació de la compra (precisa el punt 4)

La clau d'agregació de línies de compra té **tres dimensions**: **ingredient + unitat + preparació**. Els tres han de coincidir perquè dues línies es fusionin; si qualsevol difereix, surten separades.

- Mateix ingredient, mateixa unitat, mateixa preparació → s'agrega.
- Unitat diferent del mateix ingredient → línies separades (decidit: **no** agregar unitats diferents, igual que no s'agreguen preparacions diferents; no cal mantenir factors de conversió massa↔unitat per a l'agregació).
- Preparació diferent → línies separades.

### Model d'unitats: verificat correcte (confirma el punt 3)

Verificat el model real: `dish_ingredients` i `event_dish_ingredients` tenen **`unit_id` propi** (a més de `quantity`). La unitat viu a la línia d'ús, no a l'ingredient. Canviar la `default_unit_id` d'un ingredient **no** reinterpreta l'històric. **No hi ha deute tècnic** per aquest costat.

- La **unitat** es tria a la **recepta** (`dish_ingredients.unit_id`), d'entre **totes** les unitats del catàleg (filosofia permissiva: "200 g d'oli sobre bàscula", "tomàquet triturat en ml" són usos legítims; la unitat depèn del context d'ús, no de l'ingredient). No modificable a l'event (l'event guarda un snapshot immutable de la recepta).
- La **quantitat** s'escala a l'event segons convidats/format.
- El **proveïdor** es resol des de la categoria (vegeu sota), no per ingredient.

### Proveïdors: el model ja suporta N per categoria (precisa el punt 1 i la granularitat)

Verificat: `group_supplier_settings` ja és **1:N** (categoria → diversos proveïdors concrets, amb nom i canal). Ja hi ha dues carnisseries, dues peixateries, etc. a les dades. `orders.supplier_id` existeix però estava **inactiu** (sempre null).

Decisió (**Nivell 1 + default per categoria**, Spec 013):
- L'ingredient/plat-preparat/beguda apunta a una **categoria**.
- Cada categoria pot tenir un **proveïdor per defecte**.
- El proveïdor concret es resol **a la compra**: 1 proveïdor → silenciós; >1 → selector amb default preseleccionat, canviable per aquella comanda; 0 → segueix funcionant.
- S'omple `orders.supplier_id` i el missatge es dirigeix al proveïdor triat.
- **Descartat** (per ara): proveïdor preferit per ingredient individual (Nivell 2) i proveïdor obligatori a tot arreu (Nivell 3).

"Plats preparats" és una **categoria amb múltiples proveïdors** (pastisseria, rostidor, càtering...), com carn/peix. No cal model nou de proveïdor — reutilitza el de la Spec 013.

### Plats preparats i begudes: estructura (precisa el punt 1)

- **Plats preparats**: viuen al **catàleg de Plats** amb un **toggle cuinat/comprat**. Comprat → no descompon en ingredients; té proveïdor (categoria), racions, foto. Cas degenerat del plat amb recepta.
- **Begudes**: **catàleg/pestanya separada** (paral·lela a Plats i Ingredients). Plats i begudes s'entren **per separat** (reflecteix el flux mental real).
- Al **menú de l'esdeveniment**: seccions separades Plats i Begudes, cadascuna amb el seu botó "afegir".
- **Escalat**: tant plats preparats com begudes porten **racions** i escalen com els plats cuinats (decidit: reutilitzar el mecanisme de racions, no inventar escalat per format). Una beguda pot expressar "1 ampolla = N racions/copes".
- A la **compra**: ingredients, plats preparats i begudes conflueixen, agrupats per proveïdor. La compra no distingeix l'origen, només el proveïdor.
- **Ordre d'implementació**: Spec 013 (proveïdor a la compra, fonament) → Spec 014 (plats preparats + begudes, a sobre).

### Estat dels pendents originals

- [x] Confirmar on viu la unitat → **resolt**: a la línia d'ús, model correcte.
- [ ] Fixar el contracte de sortida de l'importador (Fase 1, importador).
- [ ] Política de drets per font (Fase 1, importador).
- [ ] Estratègia de mapeig ingredient↔catàleg i unitat↔canònica (Fase 1, importador).
