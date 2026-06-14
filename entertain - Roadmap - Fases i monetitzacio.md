# Entertain — Roadmap de fases i monetització

> Document de planificació. NO és una especificació d'implementació.
> Recull les decisions de producte i arquitectura preses en sessió per
> orientar les fases futures. Cada ítem es convertirà en una Spec pròpia
> quan toqui implementar-lo. L'ordre és indicatiu, no compromís.
>
> Estat de l'app en redactar això: Spec 011 a Internal Testing (release
> 1.0.2+3). App estable, usada en events reals. Objectiu declarat:
> publicar a Producció, eventualment iOS, amb funcions de pagament.

---

## 1. Objectiu de producte (decisió de fons)

L'app ha de ser **pública a Google Play eventualment**, després iOS, i
amb **funcionalitats de pagament** (en concret importar receptes). Es
construeix **lean però bé**: cada fase és un producte sencer i honest al
seu nivell, no una closca esperant la peça que la fa útil.

**Camí a Producció**: el requisit de Google (12 testers a Closed Testing
durant 14 dies) és una porta d'entrada **única** a Producció, no un peatge
recurrent. Un cop a Producció, s'hi afegeixen funcionalitats per releases
incrementals sense tornar a passar per Closed. Estratègia: arribar a
Producció **aviat** amb l'app actual (estable), i construir les funcions
premium sobre una app ja pública.

**Ordre d'aprenentatge decidit**: **pagaments abans que iOS**. iOS és un
univers paral·lel (segona botiga, segon billing, segona revisió) que
multiplica la feina; millor aprendre monetització en una sola plataforma
primer.

---

## 2. Arquitectura de monetització (decisions clau)

Aquestes decisions són **requisits de disseny** per a tota funcionalitat
que pugui acabar darrere un mur de pagament. Prendre-les ara estalvia un
refactor dolorós després.

### 2.1 Separar tres conceptes independents

1. **La funcionalitat existeix** (el codi). Sempre present al binari.
2. **L'usuari té dret a usar-la** (entitlement). Es decideix a **runtime**,
   consultant configuració externa + estat de compra.
3. **Què costa desbloquejar-la** (el producte de pagament a Play Console).

Mantenir-los separats dóna flexibilitat total: canviar preus, fer gratis
el que era premium, oferir proves, tot sense tocar el binari.

### 2.2 La decisió de què és premium es pren a runtime, no en dev ni en publicació

- **NO hardcoded** (Nivell 0): si "què és premium" viu al codi, cada canvi
  exigeix nova release + revisió + esperar que els usuaris actualitzin.
  S'ha d'evitar.
- **SÍ configuració remota** (Nivell 1): el codi pregunta a una font de
  configuració externa (taula a Supabase, p. ex. `feature_flags` /
  `entitlements`) què està desbloquejat per a l'usuari. Per canviar què és
  premium → es canvia la configuració, no el codi. L'app ho llegeix en
  arrencar (o en temps real via subscripcions Supabase).

### 2.3 Requisit de disseny: check d'entitlement des del primer dia

Tota funcionalitat **premiable** (fotos d'stock, importar receptes, futures)
neix **embolcallada amb un check d'entitlement**, encara que es llanci
gratis a tothom al principi (entitlement obert). El dia que es vulgui posar
el mur, només es tanca l'entitlement i es lliga a la compra — la
funcionalitat no canvia, només qui hi té dret, i això es decideix fora del
codi.

El **gating** (els punts de comprovació "està desbloquejada?") sí que viu al
codi; la **resposta** a la pregunta viu a la configuració externa.

### 2.4 Infraestructura un cop (cara), reconfiguració després (barata)

- **La primera vegada**: passar a pagament requereix construir tota la
  infraestructura: Google Play Billing integrat, validació de compra
  (idealment server-side via Edge Function), enllaç compra ↔ entitlement a
  Supabase. Feina substancial, una sola vegada. És el gruix d'"aprendre a
  fer una app amb pagaments".
- **A partir de llavors**: moure una funcionalitat de gratuïta a premium
  (o al revés) és essencialment **un canvi de configuració** (una query, o
  via GUI), perquè la maquinària "qui ha pagat té accés" ja s'aplica a tot
  el que es marqui.

Metàfora: es construeix el peatge una vegada (car); decidir quins carrils hi
passen és barat després.

### 2.5 Direcció del canvi i grandfathering

- **De pagament a gratuït**: sempre trivial.
- **De gratuït a pagament**: tècnicament igual de simple un cop hi ha
  maquinària, però té una dimensió **no tècnica** delicata — els usuaris que
  ja la feien servir gratis poden sentir-se traïts. Mitigació habitual:
  llançar les funcionalitats noves directament amb el seu estatus premium
  decidit, o **grandfathering** (gratis per als usuaris primerencs, de
  pagament per als nous). Decisió d'estratègia per a quan es fixin preus.

### 2.6 Compliment de Google Play Billing

Per a béns digitals, Google exigeix el **seu** sistema de billing (comissió
15–30%), no un de propi. La primera introducció de pagaments rep una mica
més d'escrutini en revisió. No requereix tornar a Closed Testing.

---

## 3. Usuari administrador (infraestructura de configuració)

Lligat al bloc de monetització: la cara visible de gestionar entitlements.

### 3.1 Concepte

Patró estàndard d'usuari admin amb funcions de configuració només accessibles
per a ell. Per al cas d'Entertain (un sol admin, lean): **funcions d'admin
dins de la mateixa app**, visibles només per a l'administrador — p. ex. una
secció extra al tab **Settings** amb els controls de configuració
(entitlements, feature flags, etc.). Evita construir una segona app/web
d'admin.

### 3.2 Seguretat en dues capes (crític)

"Ser admin" ha de ser una propietat **verificada al servidor**, no decidida
per l'app:

1. **La UI** (mostrar/amagar controls d'admin al Settings segons rol) és
   **conveniència, no seguretat** — cosmètica.
2. **Les RLS de Supabase** són la **seguretat real**: només usuaris marcats
   com a admin a la BD (columna `role`/`is_admin` o taula de rols) poden
   **escriure** a les taules de configuració. Encara que algú manipulés
   l'app per mostrar-se els controls, en intentar guardar un canvi Supabase
   el rebutjaria.

Mateix principi que GRANT + RLS: la barrera real és al servidor, no al
client. "Admin" és una cosa que la BD sap i fa complir.

### 3.3 Compte admin = compte real (no anònim)

Avui l'auth és anònima (es regenera a cada reinstal·lació — d'aquí el ball de
migracions recurrent). El compte admin ha de ser **estable i identificable**:
serà el primer cas d'ús de **compte real** (email/contrasenya o Google), tal
com les convencions ja preveuen ("auth anònima primer, ampliable a compte
real sense migració").

### 3.4 GUI de configuració

Una GUI d'administració dins l'app per moure funcionalitats d'una banda a
l'altra del mur de pagament és factible i seria la cara visible de les
queries de configuració. Va de manera natural junt amb el bloc de pagaments.

---

## 4. Fase 1 — prioritats noves (amb component de pagament)

Ordre recomanat: construir gratis primer, posar el mur després (un cop hi
hagi infraestructura), sobre la funcionalitat que hagi demostrat més valor.

### 4.1 Fotos d'stock automàtiques

- **Integració**: tercera opció al sheet de foto (avui: càmera / galeria;
  afegir: **cerca foto d'stock**). L'usuari tria → cercador d'imatges →
  selecciona → entra al carrusel `media` com qualsevol altra foto. Sense
  canvis de model.
- **Font**: banc d'imatges gratuït amb ús comercial sense atribució
  obligatòria (Unsplash / Pexels / Pixabay). Verificar llicència amb cura
  (l'app tindrà funcions de pagament). Guardar procedència de cada imatge.
- **API key inevitable**: la cerca d'imatges requereix API key **sempre**
  (autenticació del servei), tradueixi o no. Va via **Edge Function de
  Supabase** (proxy) — cap clau al client, per convenció. **Seria la primera
  Edge Function del projecte**; un graó d'infraestructura reutilitzable per a
  IA, e-commerce, etc.
- **Keyword en anglès** (els bancs responen molt millor a l'anglès). Tres
  nivells: (a) nom tal qual — dolent per a noms en català; (b) **camp de nom
  canònic en anglès a l'ingredient** — millor equilibri, sense IA; (c) API
  d'IA (Claude) per generar el keyword netejant preparacions — més potent,
  primer ús petit de l'API de Claude, però segona crida amb cost.
- **UX**: "automàtic del tot" rarament queda bé amb imatges (cf. l'oli
  d'oliva amb llimones del dataset demo). Probablement millor **mostrar unes
  quantes perquè l'usuari triï** que no pas imposar la primera.
- **Mida**: funcionalitat mitjana (Edge Function + integració + UX + gestió
  de llicències). Spec pròpia.

### 4.2 Importar receptes des d'URL

- Scraping/parsing d'una recepta web → ingredients + passos. Funcionalitat
  **premium estrella**.
- Possible efecte secundari valuós: moltes receptes web porten fotos del
  plat → el flux podria capturar imatges reals i pertinents, més rellevants
  que una foto d'stock genèrica. Part del valor de "fotos automàtiques"
  podria arribar gratis com a subproducte d'aquí.
- Spec pròpia (probablement requereix IA per al parsing robust).

### 4.3 Requisit transversal de Fase 1

Totes les funcionalitats premiables (4.1, 4.2) **neixen amb check
d'entitlement** (§2.3), encara que es llancin gratis al principi.

---

## 5. Fase 1 — funcionalitats ja a la backlog (sense pagament)

- Rebost dinàmic amb stocks reals (de binari at_home a quantitats; es
  decrementa amb l'ús).
- Calendari de preparació / timeline de tasques prèvies a un event.
- Quantitats per format d'event (seated ×1, buffet ×0.6, other ×0.8).
- Verificació de raccions vs guests (avís suau).
- Compartir grup amb altres usuaris (implica login real, invitacions, rols;
  molta feina).
- Events recurrents (plantilla, més enllà del duplicate actual).
- Plurals singular/plural al text de comandes ("16 gambes vermelles"). Alta
  complexitat i18n (camp `name_plural` o sistema Intl).
- Migració de plugins a Built-in Kotlin (warning de build; no urgent).

---

## 6. Infraestructura de monetització (ítem separat, Eix 2)

Bloc independent de qualsevol funcionalitat concreta. Es construeix **una
vegada**, quan hi hagi la primera funcionalitat premium llesta per posar-hi
darrere (recomanat: després de 4.1 i/o 4.2 funcionant gratis).

- Taula d'entitlements / feature flags a Supabase.
- Google Play Billing integrat a Flutter.
- Validació de compra server-side (Edge Function).
- Enllaç compra ↔ entitlement.
- Sistema de gating al codi (checks d'entitlement, ja presents des de Fase 1
  si es respecta §2.3).
- Concepte d'usuari admin + secció d'admin al Settings (§3).
- GUI de configuració d'entitlements (§3.4).

---

## 7. Fase 2 — idees grans

- **iOS port** (després de pagaments). Univers paral·lel: Apple Developer
  ($99/any), Mac per a builds (Codemagic o GitHub Actions amb runner macOS
  per autonomia; recursos disponibles: Mac/iPhone de la filla per a
  l'arrencada), TestFlight, App Review humana. 4 preguntes pendents de
  respondre per planificar (compte propi, acord d'ús del Mac/iPhone, espai
  en disc, versions macOS/iOS).
- Premium model consolidat (sobre la infraestructura del bloc 6).
- AI assistant conversacional.
- Integracions e-commerce (comanda directa a supermercats en lloc de generar
  text).
- Push notifications (recordatoris del calendari de preparació, etc.).

---

## 8. Camí immediat suggerit

1. **Ampliar testers interns** (2–3 més; reaprofitables per a Closed).
2. **Closed Testing**: reclutar 12 testers, arrencar el rellotge dels 14
   dies (corre en paral·lel mentre es fa altra feina). Requisit per a
   Producció.
3. **Producció** amb l'app actual (estable). Travessar la porta una vegada.
4. Construir Fase 1 (fotos d'stock → importar receptes) sobre l'app ja
   pública, amb checks d'entitlement des del primer dia.
5. Infraestructura de monetització (bloc 6) + admin.
6. iOS (Fase 2).

> Nota sobre tracks: Internal Testing no es "tanca" formalment; és un canal
> que es manté actiu. La decisió real és quan s'afegeix Closed (camí a
> Producció). Per a feedback de producte calen **pocs** testers atents que
> NO siguin l'autor (troben punts cecs), no molts ni moltes proves — el
> valor és qualitatiu, no estadístic.
