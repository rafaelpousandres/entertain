#!/usr/bin/env python3
"""
Build the Entertain complete User Manual PDF.

Same visual language as the getting-started guide (build_guide.py):
  green #1F6B52  orange #D6603A  brown #3D2B1F  warm grey #6B6256  cream #F0E9D8
Long-form, multi-page, chapter/sub-section structure. Content lives in this script
(CHAPTERS), mirroring docs/manual/index.md.

Usage:  pip install reportlab pillow ; python3 tools/build_manual.py
Resolves logo and output relative to the repo, so it runs from any CWD.
Requires: reportlab, pillow
"""
import os, sys
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader

# ---- palette ---------------------------------------------------------------
GREEN  = HexColor("#1F6B52")
ORANGE = HexColor("#D6603A")
BROWN  = HexColor("#3D2B1F")
GREY   = HexColor("#6B6256")
CREAM  = HexColor("#F0E9D8")
WHITE  = HexColor("#FFFFFF")
BODY   = HexColor("#2E2A26")

# ---- paths (repo-relative) -------------------------------------------------
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
DEFAULT_LOGO = os.path.join(REPO, "assets", "icon", "entertain - icon foreground.png")
LOGO = sys.argv[1] if len(sys.argv) > 1 else (DEFAULT_LOGO if os.path.exists(DEFAULT_LOGO)
                                              else os.path.join(HERE, "logo.png"))
OUT  = sys.argv[2] if len(sys.argv) > 2 else os.path.join(REPO, "Entertain - User manual.pdf")

VERSION = "v1.0.21"

# ---- content: list of blocks -----------------------------------------------
# block kinds: ('chap', n, title) | ('sub', title) | ('p', text) | ('slogan', text)
SLOGAN = "La vida és reunir-se al voltant d'una taula"

INTRO_P = ("Entertain t'ajuda a organitzar àpats i reunions a casa, de la idea a la taula. "
           "Prepares un catàleg reutilitzable de plats, begudes i ingredients; muntes el menú "
           "de cada esdeveniment; hi convides la gent; i obtens la llista de la compra ja "
           "calculada i agrupada per proveïdor. Aquest manual recull totes les funcionalitats "
           "de l'app, àrea per àrea. Per començar de pressa, consulta la Guia de primers "
           "passos; aquí hi trobaràs la referència completa.")

CHAPTERS = [
    ('chap', 1, "La idea general"),
    ('p', "Entertain s'organitza en tres nivells que es construeixen un sobre l'altre. El catàleg és el teu rebost reutilitzable: hi defineixes una vegada els plats, les begudes i els ingredients, i els fas servir a tots els esdeveniments. L'esdeveniment és cada àpat o reunió concreta, amb la seva data, els seus comensals i el seu menú. La compra es genera automàticament a partir del menú, agrupada per proveïdor i amb les quantitats ja calculades. Com més fas servir l'app, més de pressa et va, perquè el catàleg creix i el reutilitzes."),

    ('chap', 2, "El catàleg"),
    ('p', "El catàleg té tres seccions —plats, ingredients i begudes—, cadascuna agrupada per categories en un acordió on només se'n manté una d'oberta alhora, amb un comptador per secció (per exemple, «12 plats»). El catàleg el prepares un cop i el reutilitzes sempre."),
    ('sub', "Plats"),
    ('p', "Cada plat té un nom, una categoria, un nombre de racions base, una descripció curta, la preparació pas a pas i fotos. Un plat pot ser cuinat a casa o comprat fet: amb el commutador «Cuinat / Comprat» tries quin és. Un plat comprat amaga els ingredients i, en lloc seu, demana el proveïdor i les racions per unitat; un plat cuinat es defineix amb la seva llista d'ingredients. Canviar el commutador no esborra els ingredients que ja havies posat, de manera que pots provar les dues modalitats sense por de perdre res."),
    ('sub', "Ingredients"),
    ('p', "Cada ingredient té un nom, una unitat per defecte (grams, unitats, ampolles…), una categoria de proveïdor per defecte (carnisseria, fruiteria…) i, opcionalment, una nota de preparació i fotos. La categoria de proveïdor per defecte és la que es farà servir a la llista de la compra quan aquest ingredient hi aparegui."),
    ('sub', "Begudes"),
    ('p', "Cada beguda té un nom, un proveïdor i una denominació (ampolla, llauna, garrafa, unitat…). A diferència dels plats, les begudes no escalen amb els comensals: en gestiones la quantitat d'unitats directament, sense racions."),
    ('sub', "Noms multilingües"),
    ('p', "Quan escrius el nom d'un plat, una beguda o un ingredient en el teu idioma, Entertain l'omple automàticament als altres dos (català, castellà i anglès). Després, cada persona veu el catàleg en l'idioma que té configurat al telèfon. Això és pràctic si comparteixes l'organització amb algú que parla una altra llengua, o si cuines per a convidats internacionals. Els noms es mantenen amb la seva capitalització original."),
    ('sub', "Atributs dietètics"),
    ('p', "Pots marcar cada ingredient amb la seva dieta (desconegut, no-vegetarià, vegetarià o vegà) i amb el seu estat de gluten (desconegut, sense gluten o amb gluten). L'eix dietètic és ordenat: marcar un ingredient com a vegà implica que també és vegetarià."),
    ('p', "Els plats cuinats hereten automàticament la classificació dels seus ingredients, de manera conservadora: si un sol ingredient és desconegut, el plat es considera desconegut; el plat és vegà només si tots els seus ingredients ho són. A la fitxa del plat, aquesta classificació apareix com a «derivada» i només de lectura. Els plats comprats, que no tenen ingredients, porten un valor dietètic que pots marcar a mà. A les files del catàleg, les classificacions positives es mostren amb una insígnia concisa, perquè es vegin d'un cop d'ull."),
    ('sub', "Filtrar el catàleg"),
    ('p', "Pots filtrar el catàleg de plats per atributs dietètics —vegà, vegetarià o sense gluten, que es combinen— i per si són cuinats a casa o comprats fets. Si cap plat coincideix amb el filtre, l'app t'ho indica. Els plats amb classificació desconeguda no apareixen mai sota un filtre dietètic positiu, per no donar una falsa garantia."),
    ('sub', "Esborrar"),
    ('p', "Pots esborrar plats, ingredients i begudes del catàleg. L'app distingeix entre «Esborra» —treure una cosa del catàleg— i «Treu de…» —treure-la d'un context concret, com un menú—, de manera que mai esborris del catàleg quan només volies treure d'un esdeveniment."),

    ('chap', 3, "Crear amb intel·ligència artificial"),
    ('p', "Entertain incorpora assistents d'IA per omplir el catàleg i muntar menús més de pressa. Tota acció d'IA es reconeix pel símbol ✦."),
    ('sub', "Assistent de plats"),
    ('p', "És la manera més ràpida d'omplir el catàleg. Escrius un nom o una descripció, fins i tot vaga («com el gaspatxo però més espès», «un guisat de conill amb xocolata»), i l'assistent et prepara una fitxa completa: la llista d'ingredients amb les quantitats, el nombre de racions, la preparació pas a pas i una foto. La revises, l'ajustes si vols i la deses. A partir d'aquí el plat és teu i l'edites com qualsevol altre. Quan l'assistent crea ingredients nous, ja et proposa els seus atributs dietètics, que pots modificar."),
    ('sub', "Wizard de menú"),
    ('p', "Quan no saps per on començar un menú, el wizard («Crea el menú amb IA» / «Completa el menú amb IA») te'l proposa sencer. Respons unes quantes preguntes i afegeixes el que vulguis en text lliure, i obtens una proposta que barreja plats que ja tens al catàleg, plats nous fets a mida i begudes per acompanyar. Revises la proposta amb calma i tries què acceptes. El wizard funciona en mode «completa, no reemplaça»: afegeix coses al menú sense treure el que ja hi tenies."),
    ('sub', "Quotes"),
    ('p', "Les funcions d'IA tenen una quota mensual al pla gratuït (per exemple, l'assistent de plats i el wizard de menú). El comptador d'ús es mostra a la mateixa funció."),

    ('chap', 4, "Fotos"),
    ('p', "Pots posar imatge als teus plats, begudes i ingredients de tres maneres: fent una foto amb la càmera, triant-ne una de la galeria del telèfon, o cercant-ne una a Pexels, un banc de fotos professionals i gratuïtes, sense sortir de l'app. En la cerca de Pexels, el terme es preomple en el teu idioma i en anglès alhora, per trobar més i millors resultats; cada resultat mostra el crèdit del seu autor, i un comptador indica quantes cerques has fet del teu límit."),
    ('p', "Cada entitat pot tenir diverses fotos en un carrusel que pots reordenar; la primera és la portada que apareix a les llistes. Hi ha un visor a pantalla completa amb zoom de pinça i desplaçament entre fotos. Si descartes una edició de fotos, els canvis es reverteixen. Les fotos dels ingredients i de les begudes també apareixen al menú de l'esdeveniment i als selectors d'afegir, no només al catàleg."),

    ('chap', 5, "Esdeveniments"),
    ('p', "Un esdeveniment és qualsevol àpat o reunió: un sopar d'aniversari, un dinar de Nadal, una calçotada. Té un títol, un tipus (dinar o sopar), un format (assegut o bufet), una data i hora, un nombre de comensals, un lloc, notes i fotos."),
    ('p', "L'estat de l'esdeveniment es calcula sol —en preparació, llest o passat— a partir de les dates i de l'estat de la compra, i la llista d'esdeveniments s'agrupa per aquest estat. Pots duplicar un esdeveniment sencer, amb tot el seu menú: la còpia reinicia la data i els estats i s'anomena «Còpia de…», ideal per a celebracions que repeteixes. Cada esdeveniment té quatre pestanyes —Esdeveniment, Menú, Convidats i Compra— i l'app recorda en quina pestanya estaves de cada esdeveniment."),
    ('p', "El format decideix com s'escalen les quantitats: en un esdeveniment assegut, les racions de cada plat igualen el nombre de comensals; en un bufet, es respecten les racions del plat tal com estan al catàleg."),

    ('chap', 6, "El menú de l'esdeveniment"),
    ('p', "A la pestanya Menú afegeixes plats i begudes del teu catàleg. El botó «Afegeix» és contextual: si tens oberta la secció de Plats, va directe a afegir un plat; si tens oberta la de Begudes, a afegir una beguda; i si no tens cap secció oberta, et deixa triar entre plat i beguda. Pots agafar elements del catàleg o crear-ne de nous sobre la marxa sense perdre el fil."),
    ('p', "Quan afegeixes un plat a un esdeveniment, se'n fa una còpia per a aquell esdeveniment que pots editar independentment del catàleg —les racions, les línies, les notes— sense que afecti el plat original. Si edites les racions d'aquesta còpia, les quantitats dels ingredients s'escalen soles (arrodonint cap amunt, i amb nombres enters per als ingredients que es compten per unitats)."),
    ('p', "Pots afegir línies ad-hoc a un plat dins un esdeveniment, i marcar-les per promoure-les a la recepta del catàleg si vols que hi quedin per sempre. La nota de preparació d'una línia nova es preomple a partir de l'ingredient (és una instrucció per al proveïdor, no un pas de cuina). El menú mostra els totals: nombre de plats, racions i racions per comensal. En afegir una beguda, passes per l'editor de quantitat, igual que amb els plats."),

    ('chap', 7, "Convidats"),
    ('p', "A la pestanya Convidats portes la llista de convidats de l'esdeveniment. Pots afegir-los a mà o des dels contactes del telèfon (l'app demana permís i et deixa triar el telèfon o el correu). Cada convidat té un estat —pendent, confirmat o excusat— i la llista s'agrupa per estat en un acordió amb subtotals i total."),
    ('p', "Si confirmes més convidats dels comensals que havies previst, l'app t'avisa del sobre-aforament; és només informatiu i no canvia les racions del menú. Pots escriure un text d'invitació a nivell d'esdeveniment (amb un esborrany editable) i enviar la invitació a cada convidat pel teu canal habitual —WhatsApp, SMS o correu—; en fer-ho, el convidat queda marcat com a invitat."),

    ('chap', 8, "La compra"),
    ('p', "La pestanya Compra genera, a partir del menú, la llista de la compra agrupada per proveïdor i amb les quantitats ja calculades segons els comensals."),
    ('sub', "Estats de cada article"),
    ('p', "Cada ingredient de la compra té un estat dins una màquina d'estats: per demanar, demanat, rebut, a casa o falta. El selector només ofereix les transicions vàlides. Els capçals de cada proveïdor porten comptadors de color que resumeixen l'estat: vermell per al que cal demanar o falta, groc per al demanat, verd per al rebut o a casa."),
    ('sub', "Agregació"),
    ('p', "El mateix ingredient, quan coincideix en unitat, estat, proveïdor i nota, es fusiona en una sola línia amb la quantitat sumada. Si en canvies l'estat, el canvi afecta totes les files agregades de cop."),
    ('sub', "Extres"),
    ('p', "Pots afegir articles extra a la compra que no formen part de cap plat (per exemple, gel o tovallons). Apareixen a la compra però no al menú, i no compten als comptadors d'estat dels plats."),
    ('sub', "Missatge de comanda"),
    ('p', "Per a cada proveïdor pots generar un missatge de comanda a punt per enviar per WhatsApp, SMS, correu o el sistema de compartir. El missatge inclou només el que encara no li has demanat (el delta), amb una salutació, una data límit opcional (amb hora opcional) i una signatura. Pots sobreescriure el destinatari només per a aquell enviament."),
    ('sub', "Accions ràpides"),
    ('p', "D'un sol toc pots marcar tot el d'un proveïdor com a rebut, o fer servir «Usa com a llista de la compra», que copia la llista i passa les seves línies a l'estat «demanat»."),
    ('sub', "El rebost"),
    ('p', "El rebost és una secció consultiva on hi ha el que ja tens a casa; no genera cap missatge de comanda. Et serveix per no demanar coses que ja tens."),
    ('sub', "Mode compra al supermercat"),
    ('p', "La pantalla de compra té un mode pensat per fer servir al supermercat mateix, marcant el que ja vas posant al carret a mesura que avances pels passadissos."),
    ('sub', "Plats comprats i begudes"),
    ('p', "Els plats comprats fets i les begudes apareixen a la compra com una línia única (per exemple, «3 × Canelons» o «2 ampolles de Vi negre»). Els textos respecten la gramàtica catalana (per exemple, «3 ous» en comptes de «3 de ous», i l'elisió «d'»)."),

    ('chap', 9, "Proveïdors"),
    ('p', "Pots tenir diversos proveïdors per a una mateixa categoria i marcar-ne un per defecte amb una estrella; quan generes una comanda d'aquella categoria i hi ha més d'un proveïdor, tries quin fas servir en aquell moment. De cada proveïdor en defineixes el nom comercial, el canal (WhatsApp, correu, compartir o cap) i l'adreça (telèfon o correu), i el pots importar dels contactes del dispositiu."),
    ('p', "A més de les categories de proveïdor del sistema, pots crear-ne de pròpies. Una categoria pot representar el que tu vulguis —una botiga, una parada de mercat o una secció del supermercat—, segons com organitzis les teves compres."),

    ('chap', 10, "Configuració"),
    ('p', "A Configuració pots definir la salutació i la signatura dels missatges de comanda (les pots deixar buides expressament), i el canal de text del grup (SMS o WhatsApp), que determina com s'envien els missatges de tipus «text»."),
    ('p', "Hi ha una caixa de suggeriments per fer-nos arribar idees; admet el dictat per veu a través del teclat del sistema, i els suggeriments es desen per a la seva revisió. També hi trobaràs els crèdits (les fotos d'stock són proporcionades per Pexels) i el teu identificador d'usuari (útil per a sol·licituds d'esborrat de dades). L'app fa servir automàticament l'idioma del sistema, sense selector manual, i a cada pantalla principal tens una icona ? amb una explicació curta."),

    ('chap', 11, "El document resum"),
    ('p', "Des de la pantalla d'un esdeveniment pots generar un document resum en PDF que recull tot l'esdeveniment: el logotip d'Entertain, el nom, totes les dades, els convidats, i els plats amb les seves receptes i ingredients, a més de les begudes i la llista de la compra. És ideal per imprimir-lo i tenir-lo a la cuina, o per compartir-lo amb qui t'ajuda a organitzar."),

    ('chap', 12, "Trucs i detalls útils"),
    ('p', "Arreu de l'app, els acordions mantenen una sola secció oberta alhora, perquè et concentris en una cosa cada vegada. Desar és sempre una acció explícita (el ✓ de la barra superior); si surts d'una pantalla amb canvis sense desar, l'app t'avisa abans de descartar-los, també quan canvies de secció a Configuració. I a cada pantalla principal, la icona ? t'ofereix una explicació curta i traduïda del que pots fer-hi."),
]

# ---- layout ----------------------------------------------------------------
PAGE_W, PAGE_H = A4
ML, MR = 20*mm, 20*mm
CONTENT_W = PAGE_W - ML - MR
TOP = PAGE_H - 18*mm
BOTTOM = 20*mm

def wrap(c, text, font, size, max_w):
    c.setFont(font, size)
    out, cur = [], ""
    for w in text.split():
        t = (cur + " " + w).strip()
        if c.stringWidth(t, font, size) <= max_w:
            cur = t
        else:
            if cur: out.append(cur)
            cur = w
    if cur: out.append(cur)
    return out

def main():
    # Two-pass: first pass records the page number where each chapter starts,
    # second pass renders the index with real page numbers.
    chap_pages = {}

    def render(c, record_pages):
        state = {'page': 1}

        def show_page():
            c.showPage()
            state['page'] += 1

        # ---------- COVER (page 1) ----------
        cover_logo = 60*mm
        try:
            c.drawImage(ImageReader(LOGO), (PAGE_W - cover_logo)/2, PAGE_H/2 + 8*mm,
                        width=cover_logo, height=cover_logo, mask='auto',
                        preserveAspectRatio=True)
        except Exception as e:
            print("logo warning:", e)
        c.setFillColor(GREEN); c.setFont("Helvetica-Bold", 46)
        c.drawCentredString(PAGE_W/2, PAGE_H/2 - 6*mm, "Entertain")
        c.setFillColor(BROWN); c.setFont("Helvetica-Bold", 18)
        c.drawCentredString(PAGE_W/2, PAGE_H/2 - 20*mm, "Manual d'usuari")
        c.setFillColor(ORANGE); c.setFont("Helvetica-Oblique", 13)
        c.drawCentredString(PAGE_W/2, PAGE_H/2 - 30*mm, SLOGAN)
        c.setFillColor(GREY); c.setFont("Helvetica", 10)
        c.drawCentredString(PAGE_W/2, 24*mm, f"Versió {VERSION}")
        show_page()

        # ---------- INDEX (page 2) ----------
        c.setFillColor(GREEN); c.setFont("Helvetica-Bold", 22)
        c.drawString(ML, TOP - 4*mm, "Índex")
        iy = TOP - 18*mm
        for block in CHAPTERS:
            if block[0] == 'chap':
                n, title = block[1], block[2]
                c.setFillColor(BODY); c.setFont("Helvetica", 12)
                c.drawString(ML + 2*mm, iy, f"{n}.")
                c.drawString(ML + 12*mm, iy, title)
                if record_pages:
                    pg = chap_pages.get(n)
                    if pg:
                        c.setFillColor(GREY); c.setFont("Helvetica", 12)
                        c.drawRightString(ML + CONTENT_W, iy, str(pg))
                        # dotted leader
                        c.setFont("Helvetica", 9); c.setFillColor(HexColor("#C9C2B4"))
                        tw = c.stringWidth(title, "Helvetica", 12)
                        dots_x = ML + 12*mm + tw + 3*mm
                        dots_end = ML + CONTENT_W - 6*mm
                        x = dots_x
                        while x < dots_end:
                            c.drawString(x, iy, "."); x += 2.2*mm
                iy -= 9*mm
        c.setFillColor(GREY); c.setFont("Helvetica-Oblique", 9)
        c.drawString(ML, 18*mm, "La vida és reunir-se al voltant d'una taula")
        show_page()

        # ---------- BODY (from page 3) ----------
        y = TOP

        # intro box at the top of the body
        intro = wrap(c, INTRO_P, "Helvetica", 10.5, CONTENT_W - 10*mm)
        bh = len(intro)*5.3*mm + 7*mm
        c.setFillColor(CREAM); c.roundRect(ML, y - bh, CONTENT_W, bh, 3*mm, fill=1, stroke=0)
        c.setFillColor(BODY); ty = y - 6.5*mm
        for ln in intro:
            c.setFont("Helvetica", 10.5); c.drawString(ML + 5*mm, ty, ln); ty -= 5.3*mm
        y -= bh + 8*mm

        def ensure(y, need):
            nonlocal_state = state
            if y - need < BOTTOM:
                show_page(); return TOP
            return y

        for block in CHAPTERS:
            if block[0] == 'chap':
                n, title = block[1], block[2]
                y = ensure(y, 16*mm)
                if record_pages is False:
                    chap_pages[n] = state['page']
                bar_h = 9*mm
                c.setFillColor(GREEN)
                c.roundRect(ML, y - bar_h, CONTENT_W, bar_h, 1.5*mm, fill=1, stroke=0)
                c.setFillColor(WHITE); c.setFont("Helvetica-Bold", 13)
                c.drawString(ML + 4*mm, y - bar_h + 2.9*mm, f"{n}   {title}")
                y -= bar_h + 5*mm
            elif block[0] == 'sub':
                y = ensure(y, 12*mm)
                c.setFillColor(ORANGE); c.setFont("Helvetica-Bold", 11)
                c.drawString(ML, y, block[1])
                c.setStrokeColor(ORANGE); c.setLineWidth(0.5)
                c.line(ML, y - 1.5*mm, ML + 18*mm, y - 1.5*mm)
                y -= 6*mm
            elif block[0] == 'p':
                for ln in wrap(c, block[1], "Helvetica", 10.5, CONTENT_W):
                    y = ensure(y, 6*mm)
                    c.setFillColor(BODY); c.setFont("Helvetica", 10.5)
                    c.drawString(ML, y, ln); y -= 5.3*mm
                y -= 2.5*mm

        # footer on last page
        y = ensure(y, 12*mm); y -= 2*mm
        c.setStrokeColor(GREY); c.setLineWidth(0.4); c.line(ML, y, ML + CONTENT_W, y)
        y -= 5*mm
        c.setFillColor(GREY); c.setFont("Helvetica-Oblique", 8.5)
        c.drawString(ML, y, "Necessites una introducció ràpida? Consulta la Guia de primers passos.  ·  Fotos d'stock proporcionades per Pexels.")
        c.showPage()

    # PASS 1 — to a throwaway canvas, just to record chapter pages
    import io
    tmp = canvas.Canvas(io.BytesIO(), pagesize=A4)
    render(tmp, record_pages=False)

    # PASS 2 — real output, index now has page numbers
    c = canvas.Canvas(OUT, pagesize=A4)
    c.setTitle("Entertain - User manual"); c.setAuthor("Entertain")
    render(c, record_pages=True)
    c.save()
    print("written:", OUT)

if __name__ == "__main__":
    main()
