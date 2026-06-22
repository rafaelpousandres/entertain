# Entertain — Backlog d'idees

> Bústia única d'idees, millores i refinaments d'Entertain (convenció §8). La
> captura és barata: apuntar una idea costa segons. Les idees es **decideixen
> després**, en passades de triatge; no s'obre debat enmig d'una tasca. Capturar
> una idea no és acceptar-la: el backlog **alimenta** els documents canònics
> (pla, spec, ADR); no els substitueix. En incorporar-se a un canònic, aquí es
> marca com a incorporada.
>
> **Estats:** 💡 capturada · 🔍 en triatge · ✅ incorporada · ❌ descartada
> **Cada idea:** descripció · reptes (si escau) · **on va / quan / què bloqueja**

## Índex

0. **Principis de producte** — AI-native, ecosistema foodappslab
1. **Catàleg** — filtres, atributs dietètics (plats), atributs de begudes
2. **Creació assistida (IA)** — assistent de plats, wizard, feedback amb bucle IA
3. **Plataforma i directori** — directori curat geolocalitzat + afiliació
4. **Administració** — panell d'admin, rols de grup
5. **Monetització** — model (decidit) + Google Play Billing
6. **Polits i millores menors**
7. **Limitacions conegudes**
8. **Decisions descartades** (per no tornar-hi)

---

## 0. Principis de producte

> Orientacions de fons que haurien de guiar les decisions de producte d'Entertain.
> No són funcionalitats concretes, sinó el "nord" que les funcionalitats segueixen.
> *(La visió de negoci i la constel·lació d'apps viuen al projecte foodappslab;
> aquí només el que afecta Entertain com a producte.)*

### 💡 AI-native: la IA al centre, no afegida
Entertain es concep com una app de la generació de la IA: la IA no és un extra
sinó una peça central de l'experiència. Les funcions assistides (assistent de
plats §2, wizard d'esdeveniment §2) no són "features" aïllades sinó la direcció
del producte. Implicacions pràctiques per a les decisions d'ara:
- Prioritzar i no endarrerir la **infraestructura d'IA** (secret de servidor +
  Edge Function + quota), que la Spec 019 estrena amb les fotos d'stock. Cada
  peça d'infra de 019 és també fonament IA-ready.
- En dissenyar funcions noves, preguntar-se sempre si la IA hi aporta valor
  (proposar, completar, interpretar, casar) abans de fer-les només manuals.
- El model de quota/entitlement està pensat també per acotar el cost real de les
  crides d'IA (no només les fotos).
- **On va:** principi transversal; es concreta a les specs d'IA (§2).
- **Quan:** vigent ja com a criteri de disseny.

### 💡 Part de l'ecosistema foodappslab (infraestructura compartida)
Entertain és la primera app d'un ecosistema (foodappslab). El **negoci i la
visió de constel·lació** es gestionen al projecte foodappslab; el que importa
**aquí com a producte** és que les decisions tècniques d'Entertain no tanquin
portes a compartir infraestructura amb futures apps germanes:
- Plataforma de dades/auth/storage (Supabase), patró d'Edge Functions + secrets,
  model de quota/entitlement, i (futur) directori de proveïdors + afiliació són
  candidats a **infraestructura compartida** entre apps de foodappslab.
- Mantenir aquests components **net i portables** (ports/adapters quan tingui
  sentit) perquè es puguin extreure/compartir, sense sobre-enginyeria prematura.
- No cal fer res especial ara: només **no acoblar** aquestes peces a coses
  específiques d'Entertain de manera que impedeixi reutilitzar-les després.
- **On va:** criteri d'arquitectura; es revisarà si/quan neixi una segona app.
- **Quan:** tenir-ho present en decisions d'infra (019 i posteriors).

---

## 1. Catàleg

### 💡 Filtres al catàleg
Poder filtrar el catàleg (començant pels plats) per criteris combinables:
- **Mode d'adquisició**: només cuinats / només comprats.
- **Proveïdor / categoria de proveïdor**: només d'un proveïdor concret, o cap.
- **Atributs dietètics**: només vegans, vegetarians, sense gluten, etc. (depèn
  de "Atributs dietètics", a sota).
- (Possible) per **categoria de plat** (entrants, principals…).

Els filtres acoten el que mostra l'acordió existent. Extensible als catàlegs
d'ingredients (per proveïdor) i begudes (per proveïdor) per coherència.
- **On anirà:** spec pròpia (probablement junt amb els atributs dietètics).
- **Quan:** algun dia; útil quan el catàleg creix.
- **Bloqueja:** els atributs dietètics (per al filtre dietètic); disseny de la UI
  de filtres.

### 💡 Atributs dietètics als plats (i ingredients)
Informació de preferències/restriccions als plats: **vegetarià, vegà, sense
gluten, sense lactosa, sense fruita seca…** (conjunt d'etiquetes dietètiques).
Habilita el filtre dietètic i obre la porta a fer-ho coincidir amb restriccions
dels convidats.

Disseny a decidir:
- **Manual vs derivat**: per a plats comprats (sense ingredients), **manual**.
  Per a cuinats, es podria **derivar dels ingredients** (un plat és vegà si tots
  ho són) si els ingredients porten atributs dietètics; o manual amb override.
  Començar manual als plats és el més simple; la derivació és un refinament que
  implica atributs dietètics també als ingredients (model més gran).
- **Conjunt d'etiquetes**: definir el conjunt inicial (sistema, i18n ca/es/en).
- **Extensió futura**: restriccions dietètiques dels **convidats** → validar el
  menú i avisar de conflictes (lliga amb el model d'event/convidats i amb el
  wizard d'esdeveniment).
- **On anirà:** spec pròpia (amb o abans dels filtres).
- **Quan:** algun dia; prerequisit del filtre dietètic.
- **Bloqueja:** decisió manual vs derivat; conjunt d'etiquetes; (si derivat)
  atributs dietètics als ingredients.

### 💡 Atributs i filtre propis de begudes
Les begudes tenen el seu **propi conjunt d'atributs** i el seu **filtre**, amb
dimensions pròpies (no les mateixes que els plats):
- **Alcohòlica / sense alcohol** (i possible graduació).
- **Amb sucre / sense sucre** (o baix en sucre).
- (Possibles) **freda/calenta**, **amb gas / sense gas**, **cafeïna**, apta vegana…

Filtre al catàleg de Begudes per aquests atributs + per proveïdor. Mateix patró
que els atributs dietètics dels plats, però amb etiquetes pròpies de beguda.
Connecta amb el wizard d'esdeveniment (proposar begudes segons context: amb/sense
alcohol, infantil…) i amb restriccions dels convidats.
- **On anirà:** spec pròpia (amb els atributs dietètics / filtres de catàleg).
- **Quan:** algun dia; junt amb el bloc de filtres del catàleg.
- **Bloqueja:** conjunt d'etiquetes de beguda; disseny de la UI de filtres
  (compartida amb plats/ingredients).

### 💡 Ingredients multilingües (i18n d'ingredient) — DECIDIT
**Decidit:** cada ingredient guarda els seus noms en **ca/es/en** (taronja /
naranja / orange), no només en l'idioma en què es va escriure. Resol un deute
d'i18n latent (ara els ingredients són monolingües, incomplint el principi
"i18n des del dia u") i habilita:
- **Mostrar** l'ingredient en l'idioma de l'usuari (no només cercar).
- **Millors cerques de fotos d'stock** (cercar "orange" dóna millors resultats
  a Pexels que "taronja") sense cridar l'IA cada cop — la traducció es desa.
- Futur: directori curat, ecosistema foodappslab, catàlegs compartits entre
  usuaris de diferents idiomes.

Disseny:
- **Model**: noms per idioma a l'ingredient (reusar la taula `translations` que
  ja existeix per a altres entitats, o camps dedicats — decidir a la spec).
- **Original vs traduït (important)**: cal marcar **quin idioma és l'original**
  (el que l'usuari o la font van escriure de debò) i quins són **traduccions
  derivades** (generades per l'IA). Importa per a confiança i traçabilitat: les
  traduccions assistides poden tenir errors; l'original és la referència. Lliga
  amb la idea d'origen/confiança per atribut.
- **Regla de traducció (decidida)**: **sempre els tres idiomes** (ca/es/en),
  marcant l'original. Sigui quin sigui l'idioma de creació, es generen les altres
  dues traduccions; cap ingredient queda incomplet. L'anglès, a més, és el pont
  per a millors cerques de fotos d'stock.
- **Guardar ≠ cercar ≠ mostrar (decidit)**: es **guarden** els tres idiomes (o
  més). Per **cercar fotos** d'stock s'envia només **l'idioma de l'usuari +
  anglès** (o anglès sol) — no els tres; el tercer idioma seria soroll. Per
  **mostrar**, cada usuari veu l'ingredient **només en el seu idioma** (un
  català no veu el nom en castellà ni anglès alhora); els altres noms existeixen
  per a i18n (mostrar a cada usuari el seu) i com a pont de cerca, no per
  ensenyar-los junts.
- **Qui omple les traduccions**: en crear un ingredient nou des de l'assistent
  IA (§2, Spec 020), l'IA hi posa els tres noms. Per als ingredients existents,
  una **passada en lot** amb IA quan es vulgui.
- **Aplica també a plats i begudes?** Coherent estendre-ho; decidir abast.
- **On va:** spec pròpia (model + i18n) i/o dins la 020 per als ingredients que
  l'assistent crea. La cerca d'stock (019) se'n beneficia.
- **Quan:** lligat a la 020 (l'IA omple traduccions en crear); la migració del
  model d'ingredient pot anar abans o amb la 020.
- **Bloqueja:** decisió translations vs camps; abast (només ingredients o també
  plats/begudes); passada en lot per als existents.

---

## 2. Creació assistida (IA)

> Totes les funcions d'IA comparteixen infraestructura: API key d'Anthropic com a
> **secret de servidor + Edge Function** (que estrena la Spec 019), i la **quota
> genèrica** (`quota_key`) per limitar-ne l'ús. Candidates a **premium** (cost
> real per crida).

### 💡 Assistent de creació de plats (substitueix l'"importador d'URL")
Replantejament de la idea original d'importador d'URL: en lloc que la URL sigui
el mecanisme principal, és un **assistent**:
- Diàleg "Quin plat vols afegir?" → l'usuari escriu un nom ("canelons",
  "amanida César").
- El sistema **cerca / proposa** unes quantes opcions (receptes candidates amb
  els seus ingredients).
- L'usuari en tria una → s'incorpora al catàleg amb ingredients casats.
- **La URL passa a ser una opció més**, no el camí principal.

Reptes (heretats del disseny d'importador, vegeu `entertain - Decisions de
disseny.md` §2/§4): mapeig ingredient↔catàleg i unitat↔canònica; sortida com a
esborrany revisable (ingredients casats/ambigus) abans de desar; drets (mínim
segur: no copiar passos de tercers en producte de pagament); procedència
(`url_font`) quan l'origen és una URL.
- **Límits (decidits):** free 3/mes → premium 50/mes.
- **On anirà:** spec pròpia.
- **Quan:** després de 019.
- **Bloqueja:** infra IA (019); decisions pròpies (font de receptes: Claude vs
  API de receptes; flux de revisió; drets).

### 💡 Wizard d'esdeveniment
Assistent que **proposa un menú complet**:
- Formulari inicial: nom, # persones, quadre lliure de descripció.
- Preguntes amb opcions (tipus d'àpat, formalitat, restriccions dietètiques,
  estació…).
- Al final, proposa un menú (plats + begudes) coherent amb el context.

Encaixa amb l'"assistent IA" de Fase 2, acotat. Lliga amb els atributs dietètics
(§1) si vol respectar restriccions dels convidats.
- **Límits (decidits):** free 2/mes → premium 15/mes.
- **On anirà:** spec pròpia.
- **Quan:** algun dia (després de l'assistent de plats, probablement).
- **Bloqueja:** infra IA (019); catàleg de plats prou ric per triar; decisions
  de disseny pròpies.

### 💡 Eina de feedback amb bucle IA (l'app s'adapta als usuaris)
Una eina dins l'app perquè l'usuari digui **ràpidament** què troba a faltar i què
no funciona (captura barata: pocs tocs, sense fricció). El valor diferencial és
el **bucle tancat amb IA**: el feedback recollit s'agrega i la IA ajuda a
convertir-lo en **specs** i, d'aquí, en **releases** — l'app s'adapta als seus
usuaris ràpidament. Molt alineat amb el principi AI-native (§0).

Dimensions a dissenyar:
- **Captura (dins l'app)**: formulari mínim — què falta / què falla, opcionalment
  context (pantalla, captura), to lliure. Idealment contextual (botó discret a
  cada pantalla o un únic punt a Settings).
- **Agregació**: on van els feedbacks (taula pròpia? servei extern?), com es
  classifiquen i es detecten patrons (diversos usuaris demanant el mateix).
- **Bucle IA**: la IA resumeix/agrupa el feedback, en proposa **specs
  esborrany** (en el format de specs del projecte) i prioritza. L'operador
  revisa i decideix; no és automàtic de feedback→release sense supervisió.
- **Tancar el cercle**: avisar l'usuari quan una cosa que va demanar s'ha fet
  ("ho vau demanar, ja hi és") — efecte de fidelització fort.

Consideracions: privadesa/GDPR del feedback (consentiment, dades mínimes); evitar
soroll/spam; el bucle IA reutilitza la infra d'IA (secret + Edge Function + quota
de 019). Aquesta eina és també **infraestructura potencialment compartida** amb
altres apps de foodappslab (§0).
- **On anirà:** spec pròpia (captura) + procés/eina d'operador per al bucle IA.
- **Quan:** captura simple es pot fer aviat (barata, alt valor); el bucle IA
  complet, després de la infra d'IA (019).
- **Bloqueja:** model de dades de feedback; infra IA per al bucle; decisió de
  privadesa; (per al bucle complet) eina d'operador / panell d'admin.

---

## 3. Plataforma i directori

### 💡 Directori curat de proveïdors i plats geolocalitzat (+ afiliació)
**Gir de producte gran.** Entertain deixa de ser només eina privada i incorpora
un **directori curat** de proveïdors reals i els seus plats preparats, visibles
per **radi** segons la ubicació de l'usuari. Idealment amb **afiliació/comissions**
(el negoci hi surt de manera consentida, opt-in; relació comercial).

Model:
- L'**operador (admin de plataforma)** cura a mà proveïdors i plats reals (SQL o
  l'eina del panell d'admin). No és població automàtica.
- Es mostren als usuaris **dins un radi**; si no n'hi ha a prop, no en surten
  (l'usuari segueix amb els seus proveïdors). El radi resol el "decep on no hi ha
  cobertura".
- Només dades que el negoci ja fa públiques com a canal de comanda, i **opt-in**
  → sense problema de privadesa (curació consentida, no scraping).

Reptes:
- **Manteniment**: cada proveïdor/plat curat s'ha de mantenir; operació real a
  escala. Començar per densitat en una zona (Barcelona com a prova).
- **Model de dades nou**: proveïdors i plats **"de sistema/curats"** (globals,
  geolocalitzats, per radi) en paral·lel als **"del grup"** (privats) — patró de
  les categories de sistema, però amb geolocalització.
- **Afiliació**: comissió per comanda derivada; model de negoci propi (aparador
  + afiliat).

Connexió amb el que ja es construeix: **rol admin de plataforma** (latent a 019)
és qui cura; **categories de sistema** ja existents donen el patró; infra de
servidor (Edge Functions de 019) és base per geolocalització/afiliació.
- **On anirà:** spec(s) pròpia(es); és un gir de producte, no un afegit.
- **Quan:** després que existeixin el panell d'admin i el model
  sistema-geolocalitzat. No abans de 018/019.
- **Bloqueja:** panell d'admin; model proveïdor/plat de sistema amb
  geolocalització; decisió d'afiliació; densitat de curació en una zona.

---

## 4. Administració

### 💡 Panell d'admin de plataforma
Per a l'operador/propietari (rol que transcendeix grups). Gestionar paràmetres
globals sense tocar la BD: límits per defecte, donar/treure premium a grups
(escriure `quota_entitlements`), veure ús agregat. El **rol** admin-plataforma
(`platform_admins`) es deixa preparat a la Spec 019 sense UI; aquest panell és la
UI posterior. Probablement lligat al Billing (qui paga obté premium
automàticament).
- **Quan:** amb volum / amb Billing.
- **Bloqueja:** rol latent (019, fet); abast del panell.

### 💡 Rols dins d'un grup (group-admin)
Membres amb permisos elevats dins del seu grup (gestionar membres, configuració).
Diferent de l'admin de plataforma (Entertain és multi-grup; això és intra-grup).
- **Quan:** algun dia, si els grups creixen en membres.
- **Bloqueja:** disseny de permisos intra-grup; no confondre amb admin de
  plataforma.

---

## 5. Monetització

### ✅ Model de monetització (decidit) — referència
**Freemium "try before you buy"** amb una **sola subscripció Premium** que puja
tots els límits alhora (no compra per funció). Límits gratuïts = tast real,
dimensionats pel cost real de cada funció:
- **Fotos d'stock** (cost ~zero): free **10/mes** → premium **il·limitat**. (Spec 019.)
- **Assistent de plats** (IA): free **3/mes** → premium **50/mes**.
- **Wizard d'event** (IA): free **2/mes** → premium **15/mes**.

Tots els números viuen a config / `quota_entitlements`, ajustables sense
desplegament.

### 💡 Google Play Billing (monetització real)
El flux de pagament que activa el tier premium. Qui paga → s'escriu premium a
`quota_entitlements`. Validació server-side. És la peça de **preu** del model de
tres eixos; la 019 deixa la costura al missatge de límit assolit.
- **Quan:** quan les funcions premium (fotos + IA) justifiquin cobrar.
- **Bloqueja:** entitlement (019, fet); compte Google Play Billing; decisió de
  preu.

---

## 6. Polits i millores menors

### 💡 Velocitat del desar de fotos d'stock (resolució més petita)
Desar una foto de Pexels va una mica lent: la imatge fa un viatge doble per la
xarxa (Edge Function descarrega de Pexels → puja al storage). És inherent al
disseny (copiem la foto al storage, no hotlink), però es pot accelerar
**descarregant una resolució més petita** de Pexels (la mida `large`/`medium`
en lloc de l'`original`) — per a fotos de plats/ingredients n'hi ha de sobres.
- **On va:** ajust a l'Edge Function stock-photos (quin `src` descarrega) + 019.
- **Quan:** algun dia; millora de rendiment, no bloqueja.

### 💡 Preomplir el camp de cerca d'stock amb el nom de l'entitat
En obrir la cerca de Pexels des d'un plat/ingredient/beguda, preomplir el camp
amb el nom de l'entitat (en català ara; amb traducció a anglès quan hi hagi
ingredients multilingües —§1— i la IA de la 020).
- **On va:** 019 (client, pantalla de cerca) ara per al nom tal qual; la
  traducció arriba amb §1 + 020.
- **Quan:** el preomplir simple, aviat; la traducció, amb la 020.

### 💡 Ordre de la fitxa Crèdits a Settings
La fitxa "Crèdits" ("Fotos proporcionades per Pexels") ha d'anar **entre
"Primers passos" i "Privadesa i dades"**, no on és ara. Només canvi d'ordre de
UI, sense tocar contingut.
- **On va:** lib/features/shopping/screens/settings_screen.dart.
- **Quan:** agrupar amb altres polits en una passada futura (no val un cicle
  d'Internal Testing sol).

### 💡 Parpelleig residual del splash
A l'arrencada queda un "flash" lleu (doble càrrega) en el traspàs natiu→overlay.
El retall i el salt de mida ja es van resoldre (Spec 017 + fixos posteriors);
residu menor que l'usuari dóna per bo.
- **Quan:** algun dia, si molesta.

---

## 7. Limitacions conegudes (no urgents)

- **Historial de comandes sense denominació de begudes:** `order_items` no guarda
  la metadata de compra (denominació); les línies històriques de begudes mostren
  el nom sense la denominació. El missatge en viu i la llista de compra són
  correctes. Ampliar `order_items` queda fora d'abast fins que calgui.
- **Un proveïdor per categoria-comanda:** no es pot repartir una categoria entre
  dos proveïdors dins el mateix esdeveniment. Opcions futures: nivell per
  ingredient, o divisió a la comanda.

---

## 8. Decisions descartades (per no tornar-hi)

- **Integració amb apps de delivery (Glovo, Uber Eats…):** descartada. (a) L'API
  de Glovo és cap a dins (rebre comandes al POS d'un comerç) o logística pròpia
  amb targeta; **no** hi ha API oberta per fer comandes a la seva xarxa en nom de
  l'usuari, i l'accés és tancat amb aprovació manual. (b) Els deep links obren
  l'app en un restaurant però **no** a un plat amb cistella muntada, i no hi ha
  catàleg públic per construir-los. (c) No encaixa amb el cas d'ús (proveïdors
  locals de confiança amb encàrrec anticipat ≠ delivery exprés). El model de
  **missatge a proveïdor** que ja té Entertain és l'adequat. *(L'afiliació via
  directori curat —secció 3— és un altre model, sí viable.)*
- **Prepopulació automàtica de proveïdors/plats per geolocalització:** descartada
  com a *automàtica* (no hi ha font fiable i estructurada; manteniment i
  cobertura inviables). La via vàlida és la **curació manual** del directori
  (secció 3), no la població automàtica.
