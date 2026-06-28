# Entertain — Backlog d'idees

> Bústia única d'idees, millores i refinaments d'Entertain (convenció §8). La
> captura és barata: apuntar una idea costa segons. Les idees es **decideixen
> després**, en passades de triatge; no s'obre debat enmig d'una tasca. Capturar
> una idea no és acceptar-la: el backlog **alimenta** els documents canònics
> (pla, spec, ADR); no els substitueix. En incorporar-se a un canònic, aquí es
> marca com a incorporada.
>
> **Estats:** 💡 capturada · 🔍 en triatge · ✅ incorporada · ⏸️ aparcada · ❌ descartada
> **Cada idea:** descripció · reptes (si escau) · **on va / quan / què bloqueja**

## Índex

> **Cua de specs (planificada):** 025 catàleg ric ✅ · 026 polits + descobribilitat ✅ ·
> 027 full resum (PDF al client) + splash + sync hints ✅ · 028 mode compra al súper ·
> 029 convidats Capa 2 (RSVP) · Google Play Billing. (Detall just a sota.)

> **Estratègia de tancament de scope.** L'abast de funcionalitats **es tanca
> conscientment a la Spec 029**. Les specs **028** (compra en persona) i **029**
> (RSVP web) estan **especificades i a la cua d'implementació**. Després de la 029,
> **NO s'afegeixen més funcionalitats** (seria *gold plating*).
>
> **Seqüència de llançament:** Closed Testing (recollir feedback real) → **iOS** →
> **premium/pagament** (només quan una funció ho justifiqui, segons feedback).
>
> **Pendents menors abans de Closed Testing:** pre-launch report del Play Console
> (identificar 2 usuaris) + neteja dels grups del robo-test.

0. **Principis de producte** — AI-native, ecosistema foodappslab
1. **Catàleg** — filtres ✅ (Spec 025), atributs dietètics plats ✅ (Spec 025), atributs begudes (aparcat)
1B. **Convidats i esdeveniment social** — Capa 1 ✅ (Spec 023); Capa 2 RSVP pendent →cua (029)
2. **Creació assistida (IA)** — assistent de plats ✅, wizard de menú ✅, feedback ✅
3. **Plataforma i directori** — directori curat geolocalitzat + afiliació (aparcat)
4. **Administració** — panell d'admin, rols de grup (aparcats)
5. **Monetització** — model (decidit) + Google Play Billing
6. **Polits i millores menors**
7. **Limitacions conegudes**
8. **Decisions descartades** (per no tornar-hi)
9. **Higiene de dades i pendents tècnics** — grups buits (tancat); òrfenes ✅ (026)
10. **Fites de llançament** — Closed Testing, versió iOS

---

## Cua de specs (planificada)

> Seqüència decidida en el triatge, ordenada **simple → complex**. Els números
> **026–029 són orientatius**: el real serà el següent lliure en redactar cada
> spec. Captura la direcció, no un compromís de dates. El detall viu a cada secció.

### ✅ Spec 025 — Catàleg ric + polits — INCORPORADA
**A `main`, validada al Pixel** (PR #78). Multilingüe (ingredients/plats/begudes
reusant `translations` + helpers `translate-name`/`backfill-name-i18n`, noms en
l'idioma de l'app, caixa preservada), dietètic (enum ordenat + tri-estat, derivació
conservadora als plats, filtre), i l'escombra de polits (foto d'ingredient i de
beguda al menú i als pickers, preomplir bilingüe, quantitat en afegir begudes, botó
"Afegeix" contextual). Begudes (atributs/filtre propis) segueixen **aparcades** (§1).

### ✅ Spec 026 — Polits i descobribilitat — INCORPORADA
**A `main`, validada al Pixel** (PR #81). El bloc més senzill, agrupant millores
d'UX i deute petit:
- **Hints en entrar (pantalla de consells):** en obrir l'app, una pantalla/targeta
  de consell rotativa amb fletxa **"més"**, botó **tancar**, checkbox **"No mostrar
  més pistes"** + un interruptor a **Configuració** (per defecte **ON**). Contingut
  **des de la BD** (taules `hints` + `translations`, editables sense rebuild), seed
  ca/es/en **verificat contra l'inventari real de funcionalitats** — font a
  `Entertain - Hints (seed).md` (arrel) + generador `tools/gen_hints_seed.py`.
- **Eslògan multilingüe a la splash:** el lema d'Entertain apareix a la pantalla
  de presentació en l'idioma de l'app.
- **Badges dietètics al catàleg:** sistema d'icones propi **VGN/VGT/SG** (vegà /
  vegetarià / sense gluten), no dependent d'emojis del sistema, reusat a plats i
  ingredients (`dietary_badges.dart`).
- **Neteja de `menu_add_target.dart`** — codi mort des de la 025 (botó "Afegeix"
  contextual) + el seu test.
- **Trigger de traduccions òrfenes** — neteja automàtica de les files de
  `translations` que quedaven sense entitat viva (polimòrfica, sense FK), brossa
  menor capturada a la 025 (`catalog_repository`). Cobreix les entitats de catàleg;
  **no** el `kind = 'hint'` (els hints es gestionen per migració, vegeu §6).

> **Documentació d'usuari (existent, reproduïble des del repo):**
> - **Manual d'usuari complet** — `Entertain - User manual.pdf` (12 capítols, català),
>   generat amb `python3 tools/build_manual.py`; font web a `docs/manual/index.md`.
> - **Guia ràpida de primers passos** — `Entertain - Getting started guide.pdf`
>   (10 seccions), generada amb `python3 tools/build_guide.py`; ara el peu remet al
>   Manual complet. Tots dos generadors resolen logo i sortida **relatius al repo**.

### ✅ Spec 027 — Full resum de l'esdeveniment (PDF) — INCORPORADA
**A `main`, validada al Pixel** (versió 1.0.23+30). Un botó **"Crea full resum"** a
la pantalla **Esdeveniment** genera un **PDF al client (Flutter, `pdf`+`printing`)**
—no servidor— amb el logo i l'estil Entertain, en l'idioma de l'app, i **compartible
amb el share sheet**. Conté: dades de l'esdeveniment + foto, **convidats** (estats +
totals + avís de sobrecapacitat), **plats** (badges dietètics, ingredients amb
quantitats escalades, recepta en viu; plats comprats amb proveïdor), **begudes**,
**totals de menú** i **llista de compra per proveïdor**. Llegeix les **mateixes dades
resoltes** que les pantalles (sense divergència); fotos reduïdes a ≤1000px des de la
cache de sessió per rendiment (§C). Codi a `lib/features/events/summary/`
(`EventSummaryPdfBuilder` pur + servei + helper de downscale).

Hi van plegats, validats junts en el mateix AAB, els **dos polits carregats de la
026** (§6):
- **§9(a) "Entertain" a la splash** — nom apilat sobre el logo amb `Align`; el logo
  queda exactament al centre (traspàs net amb la splash nativa intacte).
- **§9(b) Sync de hints (BD)** — migració `20260630000000_hints_sync.sql` (44 → 40):
  esborra els 4 keys retirats **i les seves traduccions** (cap trigger cobreix
  `kind='hint'`), reescriu els 4 canviats; idempotent, regenerable amb
  `tools/gen_hints_sync.py`. Aplicada i verificada a la BD viva.

**Cua de polits (format del PDF, no urgents):** vegeu §6.

### Spec 028 — Mode compra al súper
Polir la vista de **Compra** per a l'ús real al supermercat (§6): diana d'un toc,
mode XL, progrés per secció, pantalla desperta. Sense IA ni PDF.

### ✅ Spec 029 — Convidats Capa 2 (gestió MANUAL) — INCORPORADA · ⏸️ RSVP web APARCAT

**Enviada com a gestió manual**, no com a web pública. Motiu: al domini per defecte
`*.supabase.co/functions/v1`, Supabase **reescriu les respostes `text/html` de GET a
`text/plain` (+ nosniff)** (anti-phishing), així que la pàgina es veu com a codi cru
al navegador. **Servir HTML demana domini propi** (Supabase **Pro** + add-on, ~10 $/mes)
i hem decidit **no passar a Pro ara**. Per tant:

- L'amfitrió fixa **a mà** les restriccions dietètiques a la fitxa del convidat (selector
  excloent Cap/Vegetarià/Vegà + casella Sense gluten), desat per esdeveniment.
- Pills **VGN/VGT/SG** (només positives) a la llista de Convidats.
- La invitació demana **respondre al missatge** (sense enllaç). Estat del convidat manual
  com a la Capa 1.

**⏸️ RSVP web — APARCAT fins a Pro.** Es reactiva quan Entertain passi a **Pro + domini
propi** (~10 $/mes). El codi queda **al repo, llest per reactivar**: l'Edge Function `rsvp`
(sense ús), la columna `event_guests.rsvp_token` + la migració `20260702000000` (token +
`diet_*` + grant `service_role`), i el helper Dart `rsvpUrl` (+ test). Per reactivar:
configurar el domini propi, tornar a posar l'enllaç a la invitació, i deixar que el convidat
ompli ell mateix l'estat + les restriccions.

### Google Play Billing
El flux de pagament que activa premium (§5). Quan les funcions premium (fotos + IA)
justifiquin cobrar, i després que hi hagi prou valor premium acumulat.

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
**✅ Incorporat a la Spec 025** (filtre dietètic + cuinat/comprat sobre el catàleg de plats).

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
**✅ Incorporat a la Spec 025** (dietètic a ingredients amb derivació conservadora als plats; manual als plats sense ingredients).

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

### ⏸️ Atributs i filtre propis de begudes — APARCAT
**Aparcat (decisió estratègica, no descartat).** **NO entra a la Spec 025**: el
bloc de catàleg ric prioritza plats (atributs dietètics + filtre) i els ingredients
multilingües. Els atributs/filtre de begudes es reprendran si calen (p. ex. quan
el wizard hagi de proposar begudes amb/sense alcohol o el catàleg de begudes
creixi); de moment no s'hi inverteix.

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
**✅ Incorporat a la Spec 025**: reusant `translations`, l'IA omple en crear i un
backfill one-off (`backfill-name-i18n`) per als existents; display en l'idioma de l'app.

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

## 1B. Convidats i esdeveniment social

### ✅ Llista de convidats + invitacions (Capa 1) · ✅ Capa 2 manual (Spec 029) · ⏸️ RSVP web a Pro

**Capa 1 incorporada a la Spec 023** (NOMÉS Capa 1): llista de convidats + estats
manuals {pendent / confirmat / excusat} + text d'invitació enviat pel canal propi
(WhatsApp/SMS/email), reutilitzant els patrons de **contactes de proveïdor**
(afegir des del dispositiu) i de **missatge a proveïdor** (enviar). La connexió
confirmats→comensals es va deixar **fora** per decisió (la llista és independent;
només un avís informatiu de sobre-aforament).

**Capa 2 incorporada a la Spec 029 com a gestió MANUAL** — l'amfitrió fixa a mà les
restriccions dietètiques (selector excloent + Sense gluten, pills VGN/VGT/SG) i l'estat;
la invitació demana respondre al missatge. El **RSVP web públic** (token + landing + Edge
Function `rsvp`) queda **APARCAT fins a Pro** (cal domini propi; codi llest al repo). Vegeu
l'entrada a §"Cua de specs".

Afegir als esdeveniments una **llista de convidats**, amb la possibilitat
d'**enviar invitacions** per **text (SMS/WhatsApp)** o **email**, i fer **control
de RSVP** (qui ve, qui no, qui no ha respost).

Dimensions a dissenyar:
- **Model**: convidats per esdeveniment (nom, contacte: telèfon/email), estat
  RSVP (pendent / confirmat / declinat), # acompanyants potser.
- **Invitació**: generar un missatge d'invitació (com es genera el missatge de
  comanda al proveïdor) i enviar-lo pel canal triat (text/email) — l'usuari
  l'envia des del seu canal, com amb les comandes (no enviament automàtic des de
  l'app, almenys d'inici).
- **RSVP**: com torna la resposta. Opcions: manual (l'amfitrió marca qui ha
  confirmat) o automàtic (un enllaç de confirmació → torna a l'app/BD). El manual
  és molt més simple i pot ser el MVP; l'automàtic necessita un endpoint/landing.
- **Connexió amb el menú**: el # de confirmats podria alimentar el nombre de
  comensals de l'esdeveniment (les racions) — sinergia clara amb el càlcul de la
  compra.
- **Privadesa/GDPR**: dades de contacte de tercers (els convidats) — consentiment,
  minimització.

Connecta amb: el càlcul de racions/compra (els confirmats fixen els comensals);
els atributs dietètics (§1) i el wizard (§2) si es vol proposar menú segons
restriccions dels convidats.
- **On va:** spec(s) pròpia(es). MVP: llista + invitació per text/email + RSVP
  manual. Fase 2: RSVP automàtic amb enllaç.
- **Quan:** algun dia; és una funcionalitat social gran que amplia l'abast
  d'Entertain (d'organitzar el menú a organitzar també els convidats).
- **Bloqueja:** model de convidats; decisió RSVP manual vs automàtic; privadesa.

---

## 2. Creació assistida (IA)

> Totes les funcions d'IA comparteixen infraestructura: API key d'Anthropic com a
> **secret de servidor + Edge Function** (que estrena la Spec 019), i la **quota
> genèrica** (`quota_key`) per limitar-ne l'ús. Candidates a **premium** (cost
> real per crida).

### ✅ Assistent de creació de plats (substitueix l'"importador d'URL")
**Incorporada a la Spec 020** (assistent: genera → revisió → desa, amb foto
d'stock i quota `dish_assistant`). La URL com a font es va deixar fora; Claude
genera la fitxa del seu coneixement.

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

### ✅ Wizard de menú amb IA ("Crea / Completa el menú amb IA")
**Incorporada a la Spec 022** (botó adaptatiu Crea/Completa, preguntes, proposta
que barreja catàleg + plats nous via 020 + begudes de catàleg, quota
`menu_wizard`).

Assistent que **proposa o completa el menú** d'un esdeveniment. Concreció de
l'antic "wizard d'esdeveniment":
- **Entrada**: a la pestanya **Menú**, un botó a sobre de "+ Afegeix plat",
  anàleg al "Crea un plat amb IA" però per al menú sencer: **"Crea un menú amb
  IA"**.
- **Botó adaptatiu segons context**: si el menú és buit → "Crea un menú amb IA";
  si **ja hi ha plats o begudes** → canvia a **"Completa el menú amb IA"**. Es pot
  cridar **en qualsevol moment**, respectant el que ja hi ha.
- **Context + preguntes**: parteix dels **paràmetres de l'esdeveniment** (#
  persones, format de racions…) i fa **algunes preguntes** d'opció múltiple
  (tipus d'àpat, formalitat, restriccions dietètiques, estació…) **+ una resposta
  oberta**. Amb això proposa el menú.
- **Barreja catàleg + plats nous**: la proposta pot incloure **plats del catàleg**
  existents i **plats nous creats amb IA** (reutilitza l'assistent de la 020).
- **Analogia Spotify**: com Spotify afegeix cançons noves a una playlist que ja
  sona, l'IA **completa** el menú que ja estàs muntant — no el reemplaça;
  complementa el que hi ha.

Sinergies: reutilitza l'assistent de plats (020) per als plats nous; lliga amb
els atributs dietètics (§1) i amb els convidats/RSVP (§1B) per respectar
restriccions; els paràmetres de l'esdeveniment fixen les quantitats.
- **Límits (decidits):** free 2/mes → premium 15/mes.
- **On anirà:** spec pròpia.
- **Quan:** després de l'assistent de plats (020), que reutilitza.
- **Bloqueja:** infra IA (feta, 019/020); catàleg prou ric; disseny de les
  preguntes i del flux de proposta/edició; com es barregen plats catàleg + nous.

### ✅ Eina de feedback amb bucle IA (l'app s'adapta als usuaris)
**Incorporada a la Spec 021** com a **"Suggeriments"** (a Configuració, caixa de
text lliure + comptador, desa a la BD per a export i processament posterior a
claude.ai). El bucle de processament (agregar → proposar backlog/specs) segueix
fent-se a claude.ai a partir de l'export, com estava previst.

Una eina dins l'app perquè l'usuari digui **ràpidament i sovint** què troba a
faltar i què no funciona (captura barata: pocs tocs, sense fricció). El feedback
**arriba a la BD** de manera estructurada, i el **format ha de ser fàcil de
processar per Claude (a claude.ai)** per convertir-lo en **noves entrades de
backlog / specs**. El valor diferencial és el **bucle tancat amb IA**: feedback
recollit → Claude l'agrega i en proposa funcionalitats → backlog → releases —
l'app s'adapta als seus usuaris. Molt alineat amb el principi AI-native (§0).

**MVP concret (decidit):**
- **Ubicació**: a **Configuració**, darrere de "Primers passos".
- **Títol**: **"Suggeriments"**.
- **Caixa de text lliure**, amb **dictat de veu a text** permès (el teclat del
  sistema ja ho ofereix; assegurar que el camp ho admet).
- **Indicador** de **quants suggeriments s'han enviat** (comptador per usuari/grup).
- Es **desen a la BD** per a **volcat/export posterior** (no processament en viu).
Simple a posta: sense IA dins l'app, sense bucle automàtic. El processament
intel·ligent el faig jo a claude.ai a partir del volcat.

Dimensions a dissenyar:
- **Captura (dins l'app), freqüent i fàcil**: un punt d'entrada sempre a mà
  (botó discret omnipresent o a cada pantalla) perquè donar feedback costi
  segons. Formulari mínim: què falta / què falla, to lliure; opcionalment
  context automàtic (pantalla actual, versió de l'app, captura).
- **Arribada a la BD (estructurada)**: taula pròpia de feedback (p. ex.
  `feedback`: id, group_id/user_id si escau, text, pantalla, versió, timestamp,
  estat de triatge). Dades mínimes i consentides. L'objectiu és que el conjunt
  sigui **fàcil d'exportar/llegir** (consulta SQL o export) per portar-lo a
  claude.ai.
- **Processament per Claude (a claude.ai)**: Claude llegeix el feedback agregat,
  el **resumeix, agrupa per temes, detecta patrons** (diversos usuaris demanant
  el mateix) i **proposa entrades de backlog / specs esborrany** en el format del
  projecte, prioritzades. L'operador revisa i decideix; mai feedback→release
  automàtic sense supervisió.
- **Tancar el cercle**: avisar l'usuari quan una cosa que va demanar s'ha fet
  ("ho vau demanar, ja hi és") — fidelització forta.

Consideracions: privadesa/GDPR (consentiment, dades mínimes); evitar soroll/spam.
La captura simple (BD) **no necessita IA** i es pot fer aviat; el bucle de
processament el fa Claude a claude.ai a partir de l'export, sense necessitat
d'infra d'IA dins l'app (encara que un dia es podria automatitzar via Edge
Function + quota de 019). Eina també candidata a **infraestructura compartida**
amb foodappslab (§0).
- **On anirà:** spec pròpia (captura + taula de BD) + procediment d'operador per
  al processament a claude.ai.
- **Quan:** captura + BD **aviat** (barata, alt valor, sense IA); el bucle de
  processament és immediat un cop hi ha dades (el faig jo a claude.ai).
- **Bloqueja:** model de dades de feedback (taula); decisió de privadesa/
  consentiment; punt d'entrada a la UI.

---

## 3. Plataforma i directori

### ⏸️ Directori curat de proveïdors i plats geolocalitzat (+ afiliació) — APARCAT
**Aparcat (decisió estratègica, no descartat).** És un **gir de producte** gran;
de moment Entertain segueix com a **eina privada**. Es reprendrà si/quan es
decideixi fer el gir d'aparador + afiliació. No condiciona la cua actual
(025–027). En quedar aparcat, els seus dependents (panell d'admin, rols de grup)
perden urgència — vegeu §4.

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

### ⏸️ Panell d'admin de plataforma — APARCAT
**Aparcat:** perd urgència sense el directori curat (§3, també aparcat) — el seu
ús principal era curar/gestionar. El rol `platform_admins` segueix latent (019);
es reprendrà amb el directori o amb Billing (donar/treure premium a grups).

Per a l'operador/propietari (rol que transcendeix grups). Gestionar paràmetres
globals sense tocar la BD: límits per defecte, donar/treure premium a grups
(escriure `quota_entitlements`), veure ús agregat. El **rol** admin-plataforma
(`platform_admins`) es deixa preparat a la Spec 019 sense UI; aquest panell és la
UI posterior. Probablement lligat al Billing (qui paga obté premium
automàticament).
- **Quan:** amb volum / amb Billing.
- **Bloqueja:** rol latent (019, fet); abast del panell.

### ⏸️ Rols dins d'un grup (group-admin) — APARCAT
**Aparcat:** sense urgència mentre els grups siguin petits i el directori (§3)
estigui aparcat. Es reprendrà si els grups creixen en membres.

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

### ✅ "Entertain" a la pantalla de splash (nom apilat sobre el logo)
**Incorporat a la Spec 027 (§9a), a `main`, validat al Pixel.** Nom **"Entertain"**
en bold i verd de marca, apilat sobre el logo amb un `Align` propi; el logo queda
exactament al centre, sense reflowejar la columna, així el traspàs amb la splash
nativa segueix net.

### ✅ Sync del contingut dels hints amb el fitxer font (migració de BD)
**Incorporat a la Spec 027 (§9b), aplicat i verificat a la BD viva** (44 → 40).
Migració `20260630000000_hints_sync.sql`: esborra els 4 keys retirats
(`menu_add_button`, `hints_toggle`, `event_status`, `photos_pexels`) **i les seves
traduccions explícitament** (el trigger d'òrfenes de la 026 no cobreix `kind='hint'`),
i reescriu els 4 canviats (`photos_three`, `event_format`, `config_suggestions`,
`menu_adhoc`). Idempotent (`is distinct from`), regenerable amb `tools/gen_hints_sync.py`.

### 💡 Retocs de format del full resum (PDF, Spec 027)
Dos ajustos menors de maquetació detectats validant exemples reals al Pixel (no
urgents, només presentació del PDF):
- **(a) Interlineat dels passos de recepta**: quan els passos d'una preparació van
  en línies separades, l'espai entre línies queda **massa ample** — **comprimir-lo**
  perquè la recepta es llegeixi més compacta.
- **(b) Aire abans de la primera capçalera de proveïdor a "Compra"**: afegir **una
  mica més de separació** entre el títol de secció **"Compra"** i la primera
  capçalera de proveïdor.
- **On va:** client, `event_summary_pdf_builder.dart` (espaiats de `_dishBlock` i de
  la secció Compra).
- **Quan:** propera passada de polits; trivial, només UI del PDF, sense BD.

### ✅ La foto auto de l'assistent no apareix com a capçalera de la fitxa
**Resolt a la Spec 021 (B1):** la inserció de `media` de l'assistent es va alinear
amb la del selector manual (position 0 + provinença Pexels) perquè la foto auto
quedi com a coberta.

Bug (020): la foto de plat que l'assistent afegeix automàticament (via Pexels)
**no apareix com a imatge de capçalera** de la fitxa del plat. **Pista clau:** les
fotos d'stock afegides **manualment** (selector "Cerca a Pexels") **SÍ** que surten
a la capçalera. Per tant no és la capçalera ni les fotos d'stock en general — és
**com l'assistent desa la foto** (la via assistent vs la via manual difereixen en
alguna cosa). Sospites: la `position` (la capçalera potser mostra position 0/la
primera), un camp que la via manual omple i l'assistent no, o l'ordre/`entity_id`
de la inserció. **Comparar la inserció de `media` de l'assistent amb la del
selector manual** i alinear-les.
- **On va:** Edge Function dish-assistant (save de la foto), comparat amb el
  selector manual de Pexels (019).
- **Quan:** aviat (és un bug, no un polit); afecta la percepció de l'assistent.

### ✅ Recordatori "editable després" sota el botó de crear plat amb IA
**Incorporat a la Spec 021 (B4).**

Sota el botó/camp de crear plat amb IA, posar un missatge que recordi que
**immediatament després de crear-lo, el plat es podrà editar** (ingredients,
quantitats, foto, preparació…). Treu pressió a la generació (no cal que surti
perfecte) i deixa clar que l'usuari té el control final.
- **On va:** client, pantalla de l'assistent (020).
- **Quan:** aviat, trivial.

### ✅ Afinar el prompt de l'assistent de plats (020): camps + query de foto
**Incorporat a la Spec 021:** (a) nota de proveïdor vs pas de cuina vs nom →
**B2**; (b) query de foto en anglès → **B3**.

Diversos ajustos del prompt que rep Claude a l'Edge Function dish-assistant,
detectats provant amb Sonnet. Es fan junts (mateix prompt/funció):

**(a) Nota de preparació d'ingredient vs pas de cuina vs nom.** Claude confon a
vegades on va la informació:
- "Ceba" amb nota "en juliana fina" → "en juliana" és un **pas de cuina**, no
  una instrucció al proveïdor; no hauria d'anar a la nota d'ingredient (la ceba
  es compra sencera). Els passos de cuina van **tots** a la preparació del plat.
- "Formatge Gruyère ratllat" → el "ratllat" (instrucció de proveïdor vàlida) s'ha
  colat **dins del nom**; el nom hauria de ser "Formatge Gruyère" i "ratllat" a
  la **nota** (opcional).
- Regla a reforçar al prompt amb exemples: la nota d'ingredient = NOMÉS
  instrucció al proveïdor (net, a daus, ratllat, filetejat, sense pell…), MAI un
  pas de cuina; el nom = ingredient base sense preparació enganxada; els passos
  de cuina = a la preparació del plat.

**(b) Query de foto en anglès.** La cerca de foto a Pexels desencerta amb plats
catalans/regionals ("bacallà a la llauna" → pizza). Que Claude generi la query
de foto **en anglès** (nom anglès del plat o ingredient principal, "baked cod").
Connecta amb el pont anglès dels ingredients multilingües (§1). Cap foto és
millor que una incongruent? (difícil detectar bon match; de moment, millorar la
query). La foto és il·lustrativa i editable després.

- **On va:** prompt + lògica de query de foto de l'Edge Function dish-assistant.
- **Quan:** aviat; millora de qualitat percebuda alta, cost baix, una passada.
- Cap és greu (tot editable després), però "un sol error fa dubtar de tot".

### 🔄 Preomplir el camp de cerca d'stock amb el nom de l'entitat (idioma local + anglès)
**Part SIMPLE ✅ (Spec 021, B6):** la cerca es preomple amb el nom de l'entitat tal
qual (idioma local). **Part BILINGÜE (local + anglès) PENDENT:** el terme amb
anglès depèn de tenir el nom anglès, que arriba amb els **ingredients multilingües**
(§1) → planificada a la cua (**Spec 025**, escombra de polits). El valor real és la
bilingüe.

En obrir la cerca de Pexels des d'un plat/ingredient/beguda, preomplir el camp
amb el nom de l'entitat. **Important (remarcat per Rafael):** el terme de cerca
ha de ser **idioma local + anglès** (no només el nom en català) — l'anglès
millora molt els resultats a Pexels. Connecta directament amb la regla
"guardar/cercar/mostrar" dels ingredients multilingües (§1): cercar = idioma de
l'usuari + anglès.
- **Fases:** (a) preomplir simple amb el nom tal qual (català) es pot fer ja a
  la 019; (b) el terme bilingüe (local + anglès) depèn de tenir el nom anglès,
  que arriba amb els ingredients multilingües (§1) i la IA (020). El valor real
  és (b).
- **On va:** 019 (client, pantalla de cerca) per al preomplir; el terme bilingüe
  amb §1 + 020.
- **Quan:** preomplir simple aviat; el bilingüe (el que aporta valor), amb §1/020.

### ✅ Ordre de la fitxa Crèdits a Settings
**Incorporat a la Spec 021 (B5).**

La fitxa "Crèdits" ("Fotos proporcionades per Pexels") ha d'anar **entre
"Primers passos" i "Privadesa i dades"**, no on és ara. Només canvi d'ordre de
UI, sense tocar contingut.
- **On va:** lib/features/shopping/screens/settings_screen.dart.
- **Quan:** agrupar amb altres polits en una passada futura (no val un cicle
  d'Internal Testing sol).

### ✅ Parpelleig residual del splash — resolt
**Verificat al Pixel: ja no passa.** El retall i el salt de mida es van resoldre
(Spec 017 + fixos posteriors) i el flaix residual del traspàs natiu→overlay ja no
s'observa. Tancat.

### 💡 Mode compra: vista de Compra usable al supermercat
**→ A la cua: Spec 028** (mode compra al súper).

Fer que la pantalla de Compra funcioni bé com a llista de la compra REAL al
super (dret, en moviment, una mà ocupada, cops d'ull curts). Descarta la idea
inicial d'un PDF "llista general": el valor és la interactivitat (marcar mentre
compres, estat desat, sempre actualitzat) que ja és el fort de l'app — un PDF
estàtic no aporta. La vista marcable JA existeix (és la pròpia Compra); es
tracta de POLIR-LA per a l'ús al super, no de crear-ne una de nova.

Context d'ús que mana el disseny (UX): diana tàctil gran, acció d'un sol toc,
llegibilitat a distància de braç, feedback immediat i reversible, progrés
visible, agrupació per recorregut de botiga.

Millores candidates (per impacte):
- Nucli: tota la fila com a toggle d'un toc (comprat/no comprat, diana gran);
  el comprat baixa i s'atenua/tatxa (la llista "es buida" a mesura que avances);
  comptador de progrés per secció i total ("Verduleria 3/7 · Total 12/18").
- Mode super (palanca gran): toggle "mode compra" que transforma la vista en
  versió XL (files altes, tipografia gran, només nom·quantitat·estat, amaga la
  resta); mantenir la pantalla desperta mentre s'hi és.
- Refinaments: agrupació plegable per secció (secció acabada es col·lapsa);
  filtre "amaga el que ja tinc"; possible reordenació de seccions pel recorregut
  habitual (potser massa per v1).

Preguntes obertes a resoldre en el triatge/spec:
- La Compra actual, ¿distingeix "comprat al super" o els seus estats
  (received/at_home/to_order…) són d'un altre moment del flux (encarregar/rebre
  del proveïdor)? Comprar al super pot necessitar un estat propi (p. ex. bought)
  o reutilitzar-ne un — decisió de model, mirar com està avui abans de decidir.
- Pantalla que s'adapta sola vs "mode compra" explícit amb botó (inclinació:
  mode explícit, per optimitzar per al super sense espatllar la vista de gestió).
- On va: spec pròpia ("Mode compra / vista Compra al super"), UX + interacció,
  sense IA ni PDF.
- Quan: algun dia; alta usabilitat real, no bloqueja. Independent de 22/23/24.
- Bloqueja: confirmar el model d'estats de la Compra actual; decisió
  adapta-sola vs mode explícit.

### 💡 Edició de quantitat en afegir begudes (paritat amb plats)
**✅ Incorporat a la Spec 025.**

En afegir una beguda al menú d'un event —especialment via "Crea una beguda
nova"— s'insereix directament al menú amb quantitat 1, sense passar per una
pantalla d'edició de la còpia per-event (quantitat), a diferència dels plats,
que sí permeten ajustar la còpia. Asimetria d'UX: el patró de còpia malleable
per-event hauria de valer igual per a begudes.
- Dos vessants: (a) general —no s'exposa l'edició de la còpia de beguda en
  afegir-la; (b) camí "crea nova" —cau directa al menú sense el pas d'edició.
- Triatge: confirmar si hi ha taula còpia event_drinks anàloga a event_dishes;
  si no, decidir el model abans de la UI.
- On va: spec pròpia o polit del flux de begudes a l'event.
- Quan: algun dia; coherència d'UX, no bloqueja.

### 💡 Foto d'ingredient al menú de l'esdeveniment (paritat amb plats i catàleg)
**✅ Incorporat a la Spec 025.**

Les files d'ingredient al menú (event_dish_detail_screen, _LineRow) no mostren
la foto de l'ingredient, mentre que el catàleg i les files de PLAT del menú sí.
No és un lookup que falla: el render de foto simplement no existeix a la fila
d'ingredient. Per això passa amb TOTS els ingredients.
- Solució trobada (opció A, recomanada): replicar el patró que ja fan els plats
  al mateix menú — watch entityCoverPathsProvider(MediaEntityType.ingredient) i
  passar coverPaths[line.ingredientId] a un RowPhotoThumb(bucket:
  'ingredient-photos') dins _LineRow, condicional. line.ingredientId ja ve a la
  query. Cap canvi de model ni de BD; degradació neta si ingredientId és null
  (com els plats amb sourceDishId null).
- On va: propera passada de polits (baix risc, reaprofita providers/widgets).
- Quan: després de 22/23; agrupar amb altres polits per no gastar un cicle
  d'Internal Testing per a una sola fila.

---

## 7. Limitacions conegudes (no urgents)

- **Historial de comandes sense denominació de begudes:** `order_items` no guarda
  la metadata de compra (denominació); les línies històriques de begudes mostren
  el nom sense la denominació. El missatge en viu i la llista de compra són
  correctes. Ampliar `order_items` queda fora d'abast fins que calgui.
- **Un proveïdor per categoria-comanda:** no es pot repartir una categoria entre
  dos proveïdors dins el mateix esdeveniment. Opcions futures: nivell per
  ingredient, o divisió a la comanda.
- **Velocitat de desar fotos d'stock (no és problema actual):** desar una foto de
  Pexels fa un viatge doble per la xarxa (Edge Function descarrega → puja al
  storage), inherent al disseny (copiem al storage, no hotlink). **No molesta en
  l'ús actual**, així que **no s'hi inverteix**. Si algun dia molesta, l'accelerador
  conegut és descarregar una resolució més petita (`large`/`medium` en lloc d'
  `original`) a l'Edge Function stock-photos (019).

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
- **Eliminar el valor `drink` de l'enum `dish_category`:** descartada (Spec 024).
  Les begudes s'han consolidat a l'entitat pròpia `drinks`/`event_drinks`. El
  valor `dish_category.drink` queda **deprecat, no eliminat**: Postgres no té
  `ALTER TYPE … DROP VALUE` i recrear el tipus convertiria dades reals
  (incloent-hi snapshots històrics d'`event_dishes`) — destructiu i irreversible
  sense backup, i no arreglaria el símptoma (que era a la UI). El valor es manté
  **inert** (documentat amb `comment on type`) per compatibilitat històrica i es
  treu dels camins actius (UI/IA/menú) via `dishCategoryActive`.

---

## 9. Higiene de dades i pendents tècnics

### ✅ Proliferació de grups "My group" buits a la BD — TANCAT
**Diagnòstic (benigne) + neteja FETA.** La causa era brossa **històrica de
desenvolupament**: cada arrencada anònima (reinstal·lacions, `flutter run`, canvis
de signatura) provisiona via trigger un usuari Auth + un grup; en ús normal
(actualitzar versió, mateix dispositiu) la sessió persisteix i **no** se'n creen de
nous. No afecta cap usuari real (cadascú veu només el seu grup via RLS). La neteja es
va fer amb rigor (transacció amb pre-check + post-check, preservant els 5 grups amb
events): **de 137 grups → 5**.

**Pendent menor (no bloquejant ara):** abans de Closed Testing, fer el **Pre-launch
report** de Play per identificar els **2 usuaris/grups** restants que no es van poder
classificar amb certesa (validar que són de proves abans de qualsevol neteja final).
Lligat amb §10.

### ✅ Translations òrfenes en esborrar — RESOLT a la Spec 026
En esborrar un ingredient/plat/beguda, les seves files a `translations` (taula
polimòrfica, sense FK) quedaven òrfenes. **Resolt a la Spec 026** amb un **trigger**
de neteja automàtica. Cobreix les entitats de catàleg; **no** el `kind = 'hint'`
(els hints es sincronitzen per migració — vegeu el polit pendent a §6).

---

## 10. Fites de llançament (camí cap a producció)

### 🔍 Closed Testing (requisit de Google Play)
Per promoure de **Internal** a **Closed/Production**, Google exigeix **12 testers
durant 14 dies continus** — però **NOMÉS per a comptes de desenvolupador personals
creats després del 13/11/2023**; els d'**organització** o **anteriors** n'estan
**exempts**.
- **PREREQUISIT:** **confirmar el tipus i la data del compte** de Google Play
  Console (personal vs organització; data d'alta) per saber si aplica el requisit.
- **Pla de testing real:** contractar una empresa de **crowdtesting** amb informe
  **ESCRIT** (no vídeo) i cost raonable — demanar **quote** a **test IO /
  Testbirds / MyCrowd / BetaTesting**. Els informes es converteixen en **specs de
  millora** (lligar amb la cua i amb la "Suggeriments" §2).
- **Quan:** **DESPRÉS** de 025–027 i de resoldre la proliferació de grups (§9) +
  tenir la **store listing completa**.
- **Bloqueja:** tipus/data del compte; quote de crowdtesting; store listing.

### 💡 Versió iOS (expansió després d'Android)
Flutter ja compila a iOS, però cal infraestructura i comptes propis:
- **Compte Apple Developer** (~99 USD/any), **CI d'iOS** (Codemagic), **App Store
  Connect + TestFlight**, i **ajustos específics d'iOS** (permisos Info.plist —
  p. ex. contactes—, icones, signing, revisió d'App Store).
- **Decisió de prioritat:** **Android primer**; iOS quan l'Android estigui validat
  en **Closed/producció**. Android com a base, iOS com a expansió.
- **Bloqueja:** compte Apple Developer; CI iOS; pas d'Android a Closed/producció.
