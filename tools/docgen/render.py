#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Entertain docs renderer v2 — 4 docs x 3 langs, with screenshots."""
import os, copy
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from PIL import Image

from content import TAGLINE, VERSION, STARTER
from content_manual_en import MANUAL
from content_manual_caes import MANUAL_CA, MANUAL_ES
from content_teaser_tester import TEASER, TESTER
MANUAL["ca"] = MANUAL_CA; MANUAL["es"] = MANUAL_ES

GREEN=HexColor("#1F6B52"); ORANGE=HexColor("#D6603A"); BROWN=HexColor("#3D2B1F")
GREY=HexColor("#6B6256"); CREAM=HexColor("#F0E9D8"); WHITE=HexColor("#FFFFFF"); BODY=HexColor("#2E2A26")
COLOR={"green":GREEN,"orange":ORANGE}
HERE=os.path.dirname(os.path.abspath(__file__)); LOGO=os.path.join(HERE,"assets","logo.png")
SHOTS=os.path.join(HERE,"assets","shots"); OUTDIR=os.path.join(HERE,"out"); os.makedirs(OUTDIR,exist_ok=True)
PAGE_W,PAGE_H=A4; ML,MR=18*mm,18*mm; CONTENT_W=PAGE_W-ML-MR; BOTTOM=18*mm
DOC_TITLE={"starter":{"en":"Getting started guide","ca":"Guia de primers passos","es":"Guía de primeros pasos"},
 "manual":{"en":"User manual","ca":"Manual d'usuari","es":"Manual de usuario"},
 "tester":{"en":"Tester guide","ca":"Guia del provador","es":"Guía del probador"}}
LANG_NAME={"en":"EN","ca":"CA","es":"ES"}

def wrap(c,text,font,size,max_w):
    c.setFont(font,size); words,lines,cur=text.split(),[],""
    for w in words:
        t=(cur+" "+w).strip()
        if c.stringWidth(t,font,size)<=max_w: cur=t
        else:
            if cur: lines.append(cur)
            cur=w
    if cur: lines.append(cur)
    return lines

def img_dims(path):
    im=Image.open(path); return im.size

def phone(c,path,x,y_top,h,label=None):
    iw,ih=img_dims(path); w=h*iw/ih
    c.setFillColor(WHITE); c.setStrokeColor(HexColor("#D9D2C4")); c.setLineWidth(0.8)
    c.roundRect(x-1.2*mm,y_top-h-1.2*mm,w+2.4*mm,h+2.4*mm,2*mm,fill=1,stroke=1)
    c.drawImage(ImageReader(path),x,y_top-h,width=w,height=h,mask='auto')
    if label:
        c.setFillColor(GREY); c.setFont("Helvetica",7.5); c.drawCentredString(x+w/2,y_top-h-5*mm,label)
    return w

def banner(c,y,logo_size,title_big,slogan,subtitle):
    try: c.drawImage(ImageReader(LOGO),ML,y-logo_size+6*mm,width=logo_size,height=logo_size,mask='auto',preserveAspectRatio=True)
    except Exception: pass
    tx=ML+logo_size+6*mm
    c.setFillColor(GREEN); c.setFont("Helvetica-Bold",30); c.drawString(tx,y-8*mm,title_big)
    c.setFillColor(ORANGE); c.setFont("Helvetica-Oblique",12.5); c.drawString(tx,y-14*mm,slogan)
    c.setFillColor(GREY); c.setFont("Helvetica",9.5); c.drawString(tx,y-19*mm,subtitle)
    return y-logo_size-8*mm

def footer_block(c,y,text):
    c.setFillColor(GREY)
    for ln in wrap(c,text,"Helvetica",7.8,CONTENT_W):
        c.setFont("Helvetica",7.8); c.drawString(ML,max(y,12*mm),ln); y-=4*mm

def render_starter(lang):
    d=STARTER[lang]; OUT=os.path.join(OUTDIR,f"Entertain - {DOC_TITLE['starter'][lang]} ({LANG_NAME[lang]}).pdf")
    c=canvas.Canvas(OUT,pagesize=A4); c.setTitle(f"Entertain - {d['doc_title']}")
    y=PAGE_H-14*mm; y=banner(c,y,22*mm,"Entertain",TAGLINE[lang],f"{d['doc_title']} · {VERSION}"); y+=2*mm
    il=wrap(c,d["intro"],"Helvetica",9.7,CONTENT_W-8*mm); bh=len(il)*4.6*mm+5*mm
    c.setFillColor(CREAM); c.roundRect(ML,y-bh,CONTENT_W,bh,2.5*mm,fill=1,stroke=0)
    c.setFillColor(BODY); ty=y-5.5*mm
    for ln in il: c.setFont("Helvetica",9.7); c.drawString(ML+4*mm,ty,ln); ty-=4.6*mm
    y-=bh+3*mm; FS=9.8; LH=5.2*mm
    def sh(body):
        lines=wrap(c,body,"Helvetica",FS,CONTENT_W-2*mm); return 7*mm+4.5*mm+len(lines)*LH+1.3*mm
    def sec(y,num,title,tag,colour,body):
        bh=7*mm; c.setFillColor(COLOR[colour]); c.roundRect(ML,y-bh,CONTENT_W,bh,1.2*mm,fill=1,stroke=0)
        c.setFillColor(WHITE); c.setFont("Helvetica-Bold",11); c.drawString(ML+3.5*mm,y-bh+2.2*mm,f"{num}   {title}")
        if tag:
            tw=c.stringWidth(f"{num}   {title}","Helvetica-Bold",11); c.setFont("Helvetica-Bold",7.5)
            c.drawString(ML+3.5*mm+tw+4*mm,y-bh+2.3*mm,f"|  {tag}")
        y-=bh+4.5*mm; c.setFillColor(BODY); lines=wrap(c,body,"Helvetica",FS,CONTENT_W-2*mm)
        for ln in lines:
            c.setFont("Helvetica",FS); c.drawString(ML+1*mm,y,ln); y-=LH
        y-=1.3*mm; return y
    for (num,title,tag,colour,body) in d["sections"]:
        if y-sh(body)<BOTTOM: c.showPage(); y=PAGE_H-16*mm
        y=sec(y,num,title,tag,colour,body)
    if y<26*mm: c.showPage(); y=PAGE_H-16*mm
    c.setStrokeColor(ORANGE); c.setLineWidth(0.5); c.line(ML,y,ML+CONTENT_W,y); y-=5*mm
    footer_block(c,y,d["footer"]); c.showPage(); c.save(); print("written:",os.path.basename(OUT))

MANUAL_IMGS_MASTER={
 2:([("catalog_dishes.png","catalog_ingredients.png")],{"en":"The catalog: dishes and ingredients, with dietary badges","ca":"El catàleg: plats i ingredients, amb insígnies dietètiques","es":"El catálogo: platos e ingredientes, con insignias dietéticas"}),
 6:([("menu_courses.png","ai_menu.png")],{"en":"The menu by course, and the AI menu wizard","ca":"El menú per plats, i el wizard de menú amb IA","es":"El menú por plato, y el asistente de menú con IA"}),
 7:([("guests_badges.png","rsvp_invite.png")],{"en":"Guests by status, and the invitation","ca":"Convidats per estat, i la invitació","es":"Invitados por estado, y la invitación"}),
 8:([("shopping_orders.png","shopping_inperson.png")],{"en":"Shopping: Orders mode and In-person mode","ca":"La compra: mode Comandes i mode En persona","es":"La compra: modo Pedidos y modo En persona"}),
 11:([("summary_sheet.png",)],{"en":"A generated event summary sheet","ca":"Un full resum d'esdeveniment generat","es":"Una hoja resumen de evento generada"}),
}

def render_manual(lang):
    imgs=copy.deepcopy(MANUAL_IMGS_MASTER)
    d=MANUAL[lang]; OUT=os.path.join(OUTDIR,f"Entertain - {DOC_TITLE['manual'][lang]} ({LANG_NAME[lang]}).pdf")
    c=canvas.Canvas(OUT,pagesize=A4); c.setTitle(f"Entertain - {d['doc_title']}")
    ls=52*mm; cx=PAGE_W/2
    try: c.drawImage(ImageReader(LOGO),cx-ls/2,PAGE_H/2+8*mm,width=ls,height=ls,mask='auto',preserveAspectRatio=True)
    except Exception: pass
    c.setFillColor(GREEN); c.setFont("Helvetica-Bold",40); c.drawCentredString(cx,PAGE_H/2-6*mm,"Entertain")
    c.setFillColor(BROWN); c.setFont("Helvetica-Bold",17); c.drawCentredString(cx,PAGE_H/2-18*mm,d["doc_title"])
    c.setFillColor(ORANGE); c.setFont("Helvetica-Oblique",12.5); c.drawCentredString(cx,PAGE_H/2-27*mm,TAGLINE[lang])
    c.setFillColor(GREY); c.setFont("Helvetica",10); c.drawCentredString(cx,40*mm,f"{VERSION}"); c.showPage()
    y=PAGE_H-24*mm; c.setFillColor(GREEN); c.setFont("Helvetica-Bold",20); c.drawString(ML,y,d["toc_title"]); y-=12*mm
    for (n,t) in [(n,t) for (k,n,t) in [b for b in d["blocks"] if b[0]=='chap']]:
        c.setFillColor(BODY); c.setFont("Helvetica",12); c.drawString(ML+2*mm,y,f"{n}.  {t}"); y-=8*mm
    c.setFillColor(ORANGE); c.setFont("Helvetica-Oblique",10); c.drawString(ML,20*mm,TAGLINE[lang]); c.showPage()
    y=PAGE_H-22*mm; c.setFillColor(BODY)
    for ln in wrap(c,d["intro"],"Helvetica",11,CONTENT_W):
        if y<BOTTOM: c.showPage(); y=PAGE_H-22*mm
        c.setFont("Helvetica",11); c.drawString(ML,y,ln); y-=5.4*mm
    y-=4*mm
    def ensure(s):
        nonlocal y
        if y-s<BOTTOM: c.showPage(); y=PAGE_H-22*mm
    cur=None
    for b in d["blocks"]:
        if b[0]=='chap':
            _,n,t=b; cur=n; ensure(16*mm); y-=3*mm; bh=9*mm
            c.setFillColor(GREEN); c.roundRect(ML,y-bh,CONTENT_W,bh,1.5*mm,fill=1,stroke=0)
            c.setFillColor(WHITE); c.setFont("Helvetica-Bold",13); c.drawString(ML+4*mm,y-bh+2.9*mm,f"{n}   {t}"); y-=bh+5*mm
        elif b[0]=='sub':
            _,t=b; ensure(10*mm); c.setFillColor(ORANGE); c.setFont("Helvetica-Bold",11.5); c.drawString(ML,y,t); y-=6*mm
        elif b[0]=='p':
            _,text=b
            for ln in wrap(c,text,"Helvetica",11,CONTENT_W):
                ensure(5.4*mm); c.setFillColor(BODY); c.setFont("Helvetica",11); c.drawString(ML,y,ln); y-=5.4*mm
            y-=3.5*mm
            if cur in imgs:
                pairs,caps=imgs.pop(cur); group=pairs[0]
                paths=[os.path.join(SHOTS,fn) for fn in group if os.path.exists(os.path.join(SHOTS,fn))]
                if paths:
                    if len(paths)==1 and group[0]=="summary_sheet.png":
                        ihmm=96*mm
                    else:
                        ihmm=84*mm
                    ws=[ihmm*img_dims(p)[0]/img_dims(p)[1] for p in paths]
                    gap=8*mm; total=sum(ws)+gap*(len(paths)-1)
                    ensure(ihmm+12*mm)
                    x=ML+(CONTENT_W-total)/2
                    for p,w in zip(paths,ws):
                        phone(c,p,x,y,ihmm); x+=w+gap
                    # caption centered below
                    c.setFillColor(GREY); c.setFont("Helvetica",8)
                    c.drawCentredString(ML+CONTENT_W/2, y-ihmm-5.5*mm, caps[lang])
                    y-=ihmm+12*mm
    ensure(20*mm); c.setStrokeColor(GREY); c.setLineWidth(0.4); c.line(ML,y,ML+CONTENT_W,y); y-=6*mm
    footer_block(c,y,d["footer"]); c.showPage(); c.save(); print("written:",os.path.basename(OUT))

def render_teaser(lang):
    d=TEASER[lang]; OUT=os.path.join(OUTDIR,f"Entertain - Teaser ({LANG_NAME[lang]}).pdf")
    PW,PH=200*mm,260*mm; c=canvas.Canvas(OUT,pagesize=(PW,PH)); c.setTitle("Entertain")
    mlr=15*mm; cw=PW-2*mlr
    c.setFillColor(GREEN); c.rect(0,PH-70*mm,PW,70*mm,fill=1,stroke=0)
    ls=30*mm; lx=mlr; ly=PH-50*mm
    c.setFillColor(CREAM); c.roundRect(lx-3*mm,ly-3*mm,ls+6*mm,ls+6*mm,4*mm,fill=1,stroke=0)
    try: c.drawImage(ImageReader(LOGO),lx,ly,width=ls,height=ls,mask='auto',preserveAspectRatio=True)
    except Exception: pass
    c.setFillColor(WHITE); c.setFont("Helvetica-Bold",32); c.drawString(lx+ls+8*mm,PH-28*mm,"Entertain")
    c.setFillColor(CREAM); c.setFont("Helvetica-Oblique",12); c.drawString(lx+ls+8*mm,PH-36*mm,TAGLINE[lang])
    y=PH-84*mm; c.setFillColor(BROWN); c.setFont("Helvetica-Bold",25)
    for ln in wrap(c,d["headline"],"Helvetica-Bold",25,cw): c.drawString(mlr,y,ln); y-=10.5*mm
    c.setFillColor(GREY); c.setFont("Helvetica",12.5)
    for ln in wrap(c,d["subhead"],"Helvetica",12.5,cw): c.drawString(mlr,y,ln); y-=6*mm
    y-=4*mm
    hero=["menu_courses.png","guests_badges.png","shopping_orders.png","catalog_dishes.png"]; ph_h=66*mm
    widths=[]
    for fn in hero: iw,ih=img_dims(os.path.join(SHOTS,fn)); widths.append(ph_h*iw/ih)
    gap=6*mm; total=sum(widths)+gap*(len(hero)-1); x=(PW-total)/2
    for fn,w in zip(hero,widths): phone(c,os.path.join(SHOTS,fn),x,y,ph_h); x+=w+gap
    y-=ph_h+9*mm
    colw=(cw-8*mm)/2; fx=[mlr,mlr+colw+8*mm]
    for i,(h,body) in enumerate(d["features"]):
        col=i%2; row=i//2; bx=fx[col]; by=y-row*22*mm
        c.setFillColor(ORANGE if i%2 else GREEN); c.circle(bx+2*mm,by-1.2*mm,2*mm,fill=1,stroke=0)
        c.setFillColor(BROWN); c.setFont("Helvetica-Bold",12); c.drawString(bx+6*mm,by,h); by-=5.4*mm
        c.setFillColor(BODY); c.setFont("Helvetica",9.5)
        for ln in wrap(c,body,"Helvetica",9.5,colw-6*mm): c.drawString(bx+6*mm,by,ln); by-=4.4*mm
    y-=2*22*mm+4*mm
    c.setFillColor(ORANGE); c.roundRect(mlr,22*mm,cw,15*mm,3*mm,fill=1,stroke=0)
    c.setFillColor(WHITE); c.setFont("Helvetica-Bold",14); c.drawCentredString(PW/2,27*mm,d["cta"])
    c.setFillColor(GREY); c.setFont("Helvetica",9); c.drawCentredString(PW/2,13*mm,d["footer"])
    c.showPage(); c.save(); print("written:",os.path.basename(OUT))

TESTER_SHOTS=["catalog_dishes.png","ai_menu.png","events_list.png","menu_courses.png","guests_badges.png","shopping_inperson.png","summary_sheet.png","suppliers.png"]

def render_tester(lang):
    d=TESTER[lang]; OUT=os.path.join(OUTDIR,f"Entertain - {DOC_TITLE['tester'][lang]} ({LANG_NAME[lang]}).pdf")
    c=canvas.Canvas(OUT,pagesize=A4); c.setTitle(f"Entertain - {d['doc_title']}")
    y=PAGE_H-14*mm; y=banner(c,y,24*mm,"Entertain",d["subtitle"],f"{d['doc_title']} · {VERSION}")
    il=wrap(c,d["intro"],"Helvetica",11,CONTENT_W-8*mm); bh=len(il)*5.2*mm+6*mm
    c.setFillColor(CREAM); c.roundRect(ML,y-bh,CONTENT_W,bh,2.5*mm,fill=1,stroke=0)
    c.setFillColor(BODY); ty=y-6*mm
    for ln in il: c.setFont("Helvetica",11); c.drawString(ML+4*mm,ty,ln); ty-=5.2*mm
    y-=bh+6*mm
    def ensure(s):
        nonlocal y
        if y-s<BOTTOM: c.showPage(); y=PAGE_H-16*mm
    ensure(8*mm); c.setFillColor(GREEN); c.setFont("Helvetica-Bold",13); c.drawString(ML,y,d["why_title"]); y-=6.5*mm
    c.setFillColor(BODY)
    for ln in wrap(c,d["why"],"Helvetica",10.5,CONTENT_W):
        ensure(5*mm); c.setFont("Helvetica",10.5); c.drawString(ML,y,ln); y-=5*mm
    y-=5*mm
    ensure(8*mm); c.setFillColor(GREEN); c.setFont("Helvetica-Bold",13); c.drawString(ML,y,d["need_title"]); y-=7*mm
    for item in d["need"]:
        ensure(6*mm); c.setFillColor(ORANGE); c.circle(ML+2*mm,y-1.2*mm,1.6*mm,fill=1,stroke=0); c.setFillColor(BODY)
        for ln in wrap(c,item,"Helvetica",10.3,CONTENT_W-8*mm):
            ensure(4.8*mm); c.setFont("Helvetica",10.3); c.drawString(ML+7*mm,y,ln); y-=4.8*mm
        y-=2.4*mm
    y-=4*mm
    ensure(8*mm); c.setFillColor(GREEN); c.setFont("Helvetica-Bold",13); c.drawString(ML,y,d["walk_title"]); y-=7*mm
    for i,(h,body) in enumerate(d["walk"],1):
        shot=TESTER_SHOTS[i-1] if i-1<len(TESTER_SHOTS) else None
        ph_h=50*mm; ensure(ph_h+7*mm); top=y; used_w=0; w=0
        if shot and os.path.exists(os.path.join(SHOTS,shot)):
            iw,ih=img_dims(os.path.join(SHOTS,shot)); w=ph_h*iw/ih; used_w=w+6*mm
        textw=CONTENT_W-used_w-2*mm
        # measure text height to vertically center against the phone
        title_h=6*mm
        body_lines=wrap(c,body,"Helvetica",10.5,textw-9*mm)
        text_h=title_h+len(body_lines)*4.9*mm
        block_h=max(ph_h, text_h)
        # phone on right, vertically centered in block
        if w>0:
            phone(c,os.path.join(SHOTS,shot),ML+CONTENT_W-w,top-(block_h-ph_h)/2,ph_h)
        # text vertically centered
        tstart=top-(block_h-text_h)/2
        c.setFillColor(GREEN); c.circle(ML+3*mm,tstart-1.5*mm,3*mm,fill=1,stroke=0)
        c.setFillColor(WHITE); c.setFont("Helvetica-Bold",10); c.drawCentredString(ML+3*mm,tstart-3*mm,str(i))
        c.setFillColor(BROWN); c.setFont("Helvetica-Bold",12.5); c.drawString(ML+9*mm,tstart,h)
        ty=tstart-6*mm; c.setFillColor(BODY)
        for ln in body_lines:
            c.setFont("Helvetica",10.5); c.drawString(ML+9*mm,ty,ln); ty-=4.9*mm
        y=top-block_h-9*mm
    ensure(14*mm); c.setFillColor(GREEN); c.setFont("Helvetica-Bold",13); c.drawString(ML,y,d["feedback_title"]); y-=7*mm
    c.setFillColor(BODY)
    for ln in wrap(c,d["feedback"],"Helvetica",10.5,CONTENT_W):
        ensure(5*mm); c.setFont("Helvetica",10.5); c.drawString(ML,y,ln); y-=5*mm
    y-=6*mm
    ensure(12*mm); c.setFillColor(ORANGE); c.roundRect(ML,y-11*mm,CONTENT_W,11*mm,2.5*mm,fill=1,stroke=0)
    c.setFillColor(WHITE); c.setFont("Helvetica-Bold",12); c.drawCentredString(PAGE_W/2,y-7*mm,d["thanks"]); y-=16*mm
    ensure(8*mm); footer_block(c,y,d["footer"]); c.showPage(); c.save(); print("written:",os.path.basename(OUT))

if __name__=="__main__":
    for lang in ("en","ca","es"):
        render_starter(lang); render_manual(lang); render_teaser(lang); render_tester(lang)
    print("\nAll done →",OUTDIR)
