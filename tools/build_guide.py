#!/usr/bin/env python3
"""
Build the Entertain "Getting started" guide PDF from its content.

Design (colours, layout) reproduced from the original v1.0.16 PDF:
  green  #1F6B52   orange #D6603A   brown #3D2B1F
  warm grey #6B6256   cream #F0E9D8
Content updated to v1.0.21 (specs 021-025): AI menu wizard, multilingual
catalog, dietary attributes + filter, guest list & invitations.

Reproducible build (run from anywhere — paths resolve relative to the repo):

    pip install reportlab pillow
    python3 tools/build_guide.py        # [logo.png] [output.pdf] optional overrides

By default it reads the repo logo (assets/icon/entertain - icon foreground.png)
and overwrites the guide at the repo root ("Entertain - Getting started guide.pdf").
"""
import os
import sys
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader

# ---- palette (from original PDF) -------------------------------------------
GREEN  = HexColor("#1F6B52")
ORANGE = HexColor("#D6603A")
BROWN  = HexColor("#3D2B1F")
GREY   = HexColor("#6B6256")
CREAM  = HexColor("#F0E9D8")
WHITE  = HexColor("#FFFFFF")
BODY   = HexColor("#2E2A26")

# Paths default to the repo (this file lives in <repo>/tools/), so the build is
# reproducible regardless of the current working directory (mirrors build_manual.py).
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
DEFAULT_LOGO = os.path.join(REPO, "assets", "icon", "entertain - icon foreground.png")
LOGO = sys.argv[1] if len(sys.argv) > 1 else (
    DEFAULT_LOGO if os.path.exists(DEFAULT_LOGO) else os.path.join(HERE, "logo.png"))
OUT  = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
    REPO, "Entertain - Getting started guide.pdf")

VERSION = "v1.0.21"

# ---- content ---------------------------------------------------------------
INTRO = ("Amb Entertain organitzes àpats i reunions a casa, de la idea a la "
         "taula. Primer prepares el teu catàleg de plats, begudes i ingredients; "
         "després muntes el menú de cada esdeveniment, hi convides la gent i "
         "obtens la llista de la compra ja calculada i agrupada per proveïdor. "
         "Tot el que crees es reutilitza, així que com més fas servir l'app, més "
         "ràpid et va. Comença pel catàleg —és la base de tot.")

# (number, title, tag, colour, body)  tag = small label after the title (or None)
SECTIONS = [
    (1, "El catàleg — la base", None, GREEN,
     "És el teu rebost reutilitzable, el cor d'Entertain. Hi crees plats "
     "(cuinats a casa o comprats fets), begudes, ingredients i els teus "
     "proveïdors (carnisseria, peixateria, fruiteria, forn…). El prepares un "
     "cop i el reutilitzes a tots els esdeveniments, sense tornar a començar de "
     "zero cada vegada. Pots marcar cada ingredient com a vegà, vegetarià o "
     "sense gluten, i els plats hereten automàticament la classificació dels "
     "seus ingredients —ideal per tenir present qui menja què."),

    (2, "Crea plats amb IA", "amb IA", ORANGE,
     "La manera més ràpida d'omplir el catàleg. Escriu un nom o una breu "
     "descripció —\"canelons\", \"un guisat de conill amb xocolata\"— i "
     "l'assistent et prepara una fitxa completa: la llista d'ingredients amb les "
     "seves quantitats, el nombre de racions, la preparació pas a pas i fins i "
     "tot una foto. Ho revises, ho ajustes si vols i ho deses. A partir "
     "d'aquí, el plat és teu: l'edites com qualsevol altre quan et convingui."),

    (3, "Crea un menú sencer amb IA", "amb IA", ORANGE,
     "Quan no saps per on començar un menú, deixa que l'IA te'l proposi sencer. "
     "Respon unes preguntes ràpides sobre l'esdeveniment i obtens una proposta "
     "completa que combina plats que ja tens al catàleg, plats nous fets a mida "
     "i begudes per acompanyar. Revises la proposta amb calma i tries què "
     "acceptes i què no abans d'afegir res al menú —tu sempre tens l'última "
     "paraula, l'IA només et dóna un bon punt de partida."),

    (4, "Fotos", "Pexels", ORANGE,
     "Una imatge fa que el catàleg entri pels ulls. Posa foto als teus plats, "
     "begudes i ingredients de tres maneres: fes-la al moment amb la càmera, "
     "tria'n una de la galeria del telèfon, o cerca a Pexels —un banc de fotos "
     "professionals i gratuïtes— per trobar la imatge perfecta sense sortir de "
     "l'app. La cerca et proposa el nom en diversos idiomes perquè trobis més "
     "i millors resultats."),

    (5, "El catàleg en el teu idioma", None, GREEN,
     "Entertain parla català, castellà i anglès. Els noms de plats, begudes i "
     "ingredients es tradueixen automàticament als tres idiomes: escriu el nom "
     "en el teu i l'app omple la resta tota sola. Després, cada persona veu el "
     "catàleg en l'idioma que té configurat al telèfon —pràctic si comparteixes "
     "l'organització amb algú que parla una altra llengua, o si cuines per a "
     "convidats internacionals."),

    (6, "Filtra el catàleg", None, GREEN,
     "Quan el catàleg creix, els filtres t'ajuden a trobar de seguida el que "
     "busques. Filtra els plats pels seus atributs dietètics —vegà, vegetarià o "
     "sense gluten— o per si són cuinats a casa o comprats fets. Així pots "
     "muntar un menú tenint present les necessitats dels teus convidats, o "
     "localitzar ràpidament aquell plat comprat que vols tornar a encarregar."),

    (7, "Crea un esdeveniment", None, GREEN,
     "Un esdeveniment és qualsevol àpat o reunió: un sopar d'aniversari, un "
     "dinar de Nadal, una calçotada. Posa-li un nom, la data, quantes persones "
     "vindran i el format de racions (plat individual o per compartir). Aquestes "
     "dades són la base sobre la qual muntaràs el menú i la llista de convidats, "
     "i el que permet a Entertain calcular-te bé les quantitats."),

    (8, "Munta el menú", None, GREEN,
     "Amb l'esdeveniment creat, omple'n el menú amb plats i begudes del teu "
     "catàleg. Prem el botó Afegeix i tria si vols un plat o una beguda; pots "
     "agafar-ne d'existents o crear-ne de nous sobre la marxa sense perdre el "
     "fil. Entertain ajusta les quantitats automàticament segons el nombre de "
     "comensals que has indicat, de manera que el menú sempre està a escala per "
     "a la teva colla."),

    (9, "Convidats i invitacions", None, ORANGE,
     "Porta la llista de convidats de cada esdeveniment des de la pestanya "
     "Convidats. Afegeix-los a mà o directament des dels contactes del telèfon, "
     "marca l'estat de cadascú (pendent, confirmat o excusat) i consulta els "
     "totals d'un cop d'ull, amb un avís si confirmes més gent de la que havies "
     "previst. Quan ho tinguis a punt, escriu una invitació i envia-la a cada "
     "convidat pel teu canal de sempre: WhatsApp, SMS o correu electrònic."),

    (10, "La compra", None, GREEN,
     "L'últim pas, ja resolt. A partir del menú, Entertain genera la llista de "
     "la compra agrupada per proveïdor, amb les quantitats ja calculades segons "
     "els comensals —no has de sumar res a mà. Per a cada proveïdor pots "
     "preparar un missatge de comanda a punt per enviar pel teu canal habitual, "
     "així només has de prémer enviar i esperar que t'ho tinguin a punt."),
]

FOOTER = ("Vols tots els detalls? Consulta el Manual d'usuari complet.   "
          "A cada pantalla trobaràs la icona ? amb explicacions.   "
          "Tens un suggeriment? Fes-nos-el arribar des de Configuració › Suggeriments.   "
          "Fotos d'stock proporcionades per Pexels.")

# ---- layout helpers --------------------------------------------------------
PAGE_W, PAGE_H = A4
ML, MR = 18*mm, 18*mm          # left / right margins
CONTENT_W = PAGE_W - ML - MR

def wrap(c, text, font, size, max_w):
    c.setFont(font, size)
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if c.stringWidth(t, font, size) <= max_w:
            cur = t
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines

def main():
    c = canvas.Canvas(OUT, pagesize=A4)
    c.setTitle("Entertain - Getting started")
    c.setAuthor("Entertain")

    y = PAGE_H - 16*mm

    # ---- header: logo + title ----
    logo_size = 26*mm
    try:
        c.drawImage(ImageReader(LOGO), ML, y - logo_size + 6*mm,
                    width=logo_size, height=logo_size, mask='auto',
                    preserveAspectRatio=True)
    except Exception as e:
        print("logo warning:", e)
    tx = ML + logo_size + 6*mm
    c.setFillColor(GREEN)
    c.setFont("Helvetica-Bold", 30)
    c.drawString(tx, y - 8*mm, "Entertain")
    c.setFillColor(ORANGE)
    c.setFont("Helvetica-Oblique", 12.5)
    c.drawString(tx, y - 14*mm, "La vida és reunir-se al voltant d'una taula")
    c.setFillColor(GREY)
    c.setFont("Helvetica", 9.5)
    c.drawString(tx, y - 19*mm, f"Guia de primers passos · {VERSION}")

    y -= logo_size + 8*mm

    # ---- intro box ----
    intro_lines = wrap(c, INTRO, "Helvetica", 11.5, CONTENT_W - 10*mm)
    box_h = len(intro_lines) * 5.7*mm + 7*mm
    c.setFillColor(CREAM)
    c.roundRect(ML, y - box_h, CONTENT_W, box_h, 3*mm, fill=1, stroke=0)
    c.setFillColor(BODY)
    ty = y - 7*mm
    for ln in intro_lines:
        c.setFont("Helvetica", 11.5)
        c.drawString(ML + 5*mm, ty, ln)
        ty -= 5.7*mm
    y -= box_h + 4*mm

    # ---- sections ----
    def section(c, y, num, title, tag, colour, body):
        # coloured header bar
        bar_h = 9*mm
        c.setFillColor(colour)
        c.roundRect(ML, y - bar_h, CONTENT_W, bar_h, 1.5*mm, fill=1, stroke=0)
        c.setFillColor(WHITE)
        c.setFont("Helvetica-Bold", 13)
        c.drawString(ML + 4*mm, y - bar_h + 2.9*mm, f"{num}   {title}")
        if tag:
            tw = c.stringWidth(f"{num}   {title}", "Helvetica-Bold", 13)
            c.setFont("Helvetica-Bold", 8.5)
            c.drawString(ML + 4*mm + tw + 4*mm, y - bar_h + 3.1*mm, f"|  {tag}")
        y -= bar_h + 5*mm           # air between header and paragraph
        # body
        c.setFillColor(BODY)
        lines = wrap(c, body, "Helvetica", 11, CONTENT_W - 2*mm)
        for i, ln in enumerate(lines):
            c.setFont("Helvetica", 11)
            c.drawString(ML + 1*mm, y, ln)
            if i < len(lines) - 1:
                y -= 5.3*mm
        # thin orange rule under the section (tight under the last text line)
        y -= 3.5*mm
        c.setStrokeColor(ORANGE)
        c.setLineWidth(0.6)
        c.line(ML, y, ML + CONTENT_W, y)
        y -= 6.5*mm                  # gap before next section header
        return y

    def section_height(c, title, body):
        lines = wrap(c, body, "Helvetica", 11, CONTENT_W - 2*mm)
        # (len-1) gaps between lines, not len
        return 9*mm + 5*mm + max(len(lines)-1, 0)*5.3*mm + 3.5*mm + 6.5*mm

    BOTTOM = 20*mm
    for (num, title, tag, colour, body) in SECTIONS:
        h = section_height(c, title, body)
        if y - h < BOTTOM:
            # footer on current page, then new page
            c.setFillColor(GREY)
            c.setFont("Helvetica", 7.5)
            c.drawString(ML, 12*mm, FOOTER[:0] or "")  # (footer only on last page)
            c.showPage()
            y = PAGE_H - 18*mm
        y = section(c, y, num, title, tag, colour, body)

    # ---- footer (last page) ----
    c.setStrokeColor(GREY)
    c.setLineWidth(0.4)
    c.setFillColor(GREY)
    c.setFont("Helvetica", 7.8)
    # wrap footer across the width
    for ln in wrap(c, FOOTER, "Helvetica", 7.8, CONTENT_W):
        c.drawString(ML, max(y, 13*mm), ln)
        y -= 4*mm

    c.showPage()
    c.save()
    print("written:", OUT)

if __name__ == "__main__":
    main()
