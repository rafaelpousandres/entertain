# Entertain — Specification 033 — Dades d'exemple a l'onboarding + polits

## A. Dades d'exemple per a usuaris nous (onboarding)

### A.1 Objectiu
Cada usuari nou estrena l'app amb un dataset d'exemple ric ja carregat al seu grup
(catàleg, esdeveniments, convidats, compra, fotos), editable i aïllat. Un banner a la
pantalla d'esdeveniments li ofereix "començar de zero" quan vulgui. Aplica a **tots els
usuaris nous** (testing i producció) — no és bastida temporal, és onboarding de producte.

### A.2 Quan se sembra
- En el **provisioning d'un usuari nou** (la Phase 0 ja crea grup + membership). El sembrat
  s'enganxa aquí: en crear-se el grup del nou usuari, s'hi clona el dataset d'exemple.
- **Una sola vegada per usuari**, lligat al provisioning — NO a "el grup és buit". Un usuari
  que esborri l'exemple té el grup buit i NO se li ha de tornar a sembrar.
- Manté **una sola membership per usuari** (no trenca `currentGroupId()`).

### A.3 Contingut sembrat
- Origen: el dataset d'exemple de la Fase 2 (catàleg de 61 ingredients / 16 plats / 8 begudes
  amb noms trilingües i fotos; 4 esdeveniments amb convidats i compra; proveïdors).
- El catàleg conserva els **noms trilingües existents** (cada usuari el veu en l'idioma del
  seu telèfon).
- Fotos: cada usuari ha de poder editar/esborrar les seves fotos d'exemple **sense afectar
  les d'altres usuaris**. El mecanisme de clonatge (copiar fitxers vs referenciar assets demo
  compartits de només-lectura) el decideix CC, respectant aquest aïllament.

### A.4 Marcatge de dades d'exemple
- Cada fila sembrada es marca com a **demo** (flag a definir per CC, p. ex. `is_demo` o
  `source='demo'`), a totes les entitats sembrades (catàleg, esdeveniments, convidats, compra,
  proveïdors, fotos).
- Aquest marcatge és el que permet esborrar **exactament** l'exemple sense tocar el que
  l'usuari hagi creat.
- El marcatge **NO es mostra a la UI** (com `kubera_id` a Talaia: traçabilitat interna,
  invisible a l'usuari).

### A.5 Banner "comença de zero"
- **Banner dismissible** a la pantalla d'esdeveniments: text breu (traduït ca/es/en) + acció.
- Acció → **confirmació clara** → esborra **TOTES** les dades d'exemple de cop (totes les files
  marcades demo: catàleg, esdeveniments, convidats, compra, proveïdors, fotos), **preservant
  el que l'usuari hagi creat** (files no marcades demo).
- Tancar el banner (X) l'amaga però **manté** les dades.
- El banner **desapareix automàticament** quan ja no hi ha dades d'exemple al grup.

### A.6 Idempotència
- El sembrat és one-shot al provisioning. Esborrar l'exemple no el fa tornar. Reentrar amb el
  mateix usuari no re-sembra (el grup ja existeix).

### A.7 Aïllament entre usuaris
- Dos usuaris nous diferents tenen datasets **independents**: editar o esborrar en un no
  afecta l'altre (RLS per grup, ja vigent).

---

## B. Polits del full resum (PDF) — `event_summary_pdf_builder.dart`

### B.1 Títols vidus (keep-with-next)
Evitar que un títol de secció quedi sol al peu d'una pàgina. Si després d'un títol no hi cap
almenys un element abans del salt de pàgina, el títol salta amb el contingut a la pàgina nova.

### B.2 Interlineat dels passos de recepta
Quan els passos d'una preparació van en línies separades, l'espai entre línies queda massa
ample — comprimir-lo.

### B.3 Aire abans de la primera capçalera de proveïdor a "Compra"
Afegir una mica més de separació entre el títol "Compra" i la primera capçalera de proveïdor.

---

## C. Polit d'UI

### C.1 Alçada del camp Notes a l'esdeveniment
A la pantalla de detall d'esdeveniment, el camp Notes (`maxLines: 4`) deixa el botó "Crea
resum" fora de vista i obliga a fer scroll. Reduir l'alçada del camp Notes perquè el botó
"Crea resum" sigui visible sense scroll.

---

## A.8 Idioma de les dades d'exemple (decidit)

- El **catàleg** (plats, ingredients, begudes) es mostra en l'idioma del telèfon via els noms
  trilingües existents.
- Els **títols d'esdeveniment i les ubicacions** d'exemple se sembren en l'idioma del telèfon
  de l'usuari (3 variants —ca/es/en— al seed, triades per locale al provisioning).
- Els **noms de convidats** són neutres (no es tradueixen).
- Cal traduir a ca/es els 4 títols d'esdeveniment i les ubicacions que a la Fase 2 estaven
  només en anglès.

---

## Criteris d'acceptació
- Un usuari nou veu el dataset d'exemple complet en obrir l'app per primer cop.
- Les dades d'exemple es veuen en l'idioma del telèfon (catàleg i esdeveniments).
- El banner apareix; "comença de zero" esborra tot l'exemple i deixa el que l'usuari hagi
  creat; el banner desapareix després.
- Esborrar l'exemple i reentrar NO el re-sembra.
- Dos usuaris nous diferents tenen datasets independents.
- `currentGroupId()` segueix amb una sola membership per usuari.
- PDF: cap títol vidu; interlineat de passos compacte; aire correcte abans del primer proveïdor.
- Notes: el botó "Crea resum" es veu sense scroll.

---

## Validació
Build AAB des de branca → validació al Pixel 8 Pro via Google Play Internal Testing →
merge a main. (Cal un usuari net per provar el primer arrencada amb sembrat.)
