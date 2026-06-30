# -*- coding: utf-8 -*-
"""Teaser (social) + Tester guide content — EN master + ca/es."""

# ============================================================================
# TEASER — social one-pager (IG/FB). Short, punchy, screenshot-led.
# Structure: headline, subhead, 4 punchy feature lines, a closing CTA.
# ============================================================================

TEASER = {
    "en": {
        "doc_title": "Entertain",
        "headline": "Host without the chaos.",
        "subhead": "From the idea to the table — menus, guests and shopping, all in one place.",
        "features": [
            ("Build the menu in minutes", "A reusable catalog of dishes, drinks and ingredients. Let AI propose a whole menu, then make it yours."),
            ("Never lose track of guests", "Confirmed, pending or excused at a glance. Guests RSVP themselves from a link — and tell you what they can't eat."),
            ("Shopping, already done", "The list builds itself from your menu, grouped by supplier, quantities calculated. Order from home or tick off in the shop."),
            ("Beautiful from the first tap", "Photos on everything, dietary badges, and a printable summary sheet for the whole event."),
        ],
        "cta": "Entertain — life is gathering around a table.",
        "footer": "Now in closed testing. · Catalan · Spanish · English",
    },
    "ca": {
        "doc_title": "Entertain",
        "headline": "Organitza sense el caos.",
        "subhead": "De la idea a la taula —menús, convidats i compra, tot en un sol lloc.",
        "features": [
            ("Munta el menú en minuts", "Un catàleg reutilitzable de plats, begudes i ingredients. Deixa que la IA et proposi un menú sencer i després fes-lo teu."),
            ("No perdis mai el compte dels convidats", "Confirmats, pendents o excusats d'un cop d'ull. Els convidats responen ells mateixos des d'un enllaç —i t'indiquen què no poden menjar."),
            ("La compra, ja feta", "La llista es genera sola a partir del menú, agrupada per proveïdor i amb les quantitats calculades. Demana des de casa o marca a la botiga."),
            ("Bonic des del primer toc", "Fotos a tot, insígnies dietètiques, i un full resum imprimible de tot l'esdeveniment."),
        ],
        "cta": "Entertain —la vida és reunir-se al voltant d'una taula.",
        "footer": "Ara en proves tancades. · Català · Castellà · Anglès",
    },
    "es": {
        "doc_title": "Entertain",
        "headline": "Organiza sin el caos.",
        "subhead": "De la idea a la mesa —menús, invitados y compra, todo en un solo lugar.",
        "features": [
            ("Monta el menú en minutos", "Un catálogo reutilizable de platos, bebidas e ingredientes. Deja que la IA te proponga un menú entero y luego hazlo tuyo."),
            ("No pierdas nunca la cuenta de los invitados", "Confirmados, pendientes o excusados de un vistazo. Los invitados responden ellos mismos desde un enlace —e indican qué no pueden comer."),
            ("La compra, ya hecha", "La lista se genera sola a partir del menú, agrupada por proveedor y con las cantidades calculadas. Pide desde casa o marca en la tienda."),
            ("Bonito desde el primer toque", "Fotos en todo, insignias dietéticas, y una hoja resumen imprimible de todo el evento."),
        ],
        "cta": "Entertain —la vida es reunirse alrededor de una mesa.",
        "footer": "Ahora en pruebas cerradas. · Catalán · Castellano · Inglés",
    },
}

# ============================================================================
# TESTER GUIDE — closed-testing walkthrough. Tells testers what to do.
# Structure: intro, "what we need from you", a numbered walkthrough, feedback, thanks.
# ============================================================================

TESTER = {
    "en": {
        "doc_title": "Tester guide",
        "why_title": "Why this matters",
        "why": ("Entertain is in closed testing on Google Play. To move the app forward to a public release, we need a small group of testers using it on real devices over a two-week period. Your real-world use — and the fact that you stay opted in for the full two weeks — is what makes that possible. You don't need to use it every day or for long; a natural rhythm over the fortnight is exactly right. Everything you see is pre-loaded demo data, so feel free to change anything, create, delete and experiment — you won't break anything real."),
        "subtitle": "Closed testing — thank you for helping",
        "intro": ("Thank you for joining the Entertain closed test. Your job is simple: use the app "
                  "like you would at home, over the next two weeks, and tell us what works and what "
                  "doesn't. This short guide walks you through the main features so you can try "
                  "everything — but feel free to explore on your own too."),
        "need_title": "What we need from you",
        "need": [
            "Use the app on a few different days over the testing period — not all at once. A natural rhythm (a bit now, a bit in a few days) is exactly what helps.",
            "Try the main flows below at least once each.",
            "Send us your feedback from Settings › Suggestions (you can dictate it by voice) — what you liked, what confused you, anything that broke.",
            "Stay opted in for the full two weeks, even if you're done exploring.",
        ],
        "walk_title": "A quick walkthrough",
        "walk": [
            ("Explore the catalog", "Open the Catalog tab. Browse the dishes, ingredients and drinks — they come pre-loaded with photos and dietary badges. Try the filters (vegan, vegetarian, gluten-free)."),
            ("Create a dish with AI", "In the Catalog, tap \"Create a dish with AI\", type any dish name or description, and watch it build a full recipe with a photo. Save it."),
            ("Open an event", "Go to the Events tab and open \"Summer Garden Party\". Look at the four tabs: Event, Menu, Guests, Shopping."),
            ("Build or complete the menu", "On the Menu tab, add a dish or drink, or try \"Complete the menu with AI\". Notice the courses are ordered automatically."),
            ("Check the guests", "On the Guests tab, see the confirmed / pending / excused traffic-light and the dietary badges. Try writing an invitation."),
            ("Do the shopping", "On the Shopping tab, switch between Orders and In person. Change an item's state in Orders; tick items off in In person. Try generating an order message for a supplier."),
            ("Generate the summary sheet", "From the event, tap Create summary. A full PDF of the event is produced — open it and see the menu, recipes, guests and shopping all in one document."),
            ("Set up a supplier", "In Settings › Suppliers, open one and add a contact, or create your own supplier category."),
        ],
        "feedback_title": "How to send feedback",
        "feedback": ("Go to Settings › Suggestions and write (or dictate) anything that comes to mind. "
                     "The most useful feedback is concrete: \"the X button did Y when I expected Z\", "
                     "\"this screen was confusing because…\", \"I'd love it if…\". Even small things "
                     "help. If something crashed or looked wrong, tell us what you were doing at the "
                     "time."),
        "thanks": "Thank you for your time — it genuinely makes the app better.",
        "footer": "Entertain · Closed testing · Stock photos provided by Pexels.",
    },
    "ca": {
        "doc_title": "Guia del provador",
        "why_title": "Per què importa",
        "why": ("Entertain és en proves tancades a Google Play. Per fer avançar l'app cap a un llançament públic, necessitem un grup reduït de provadors fent-la servir en dispositius reals durant un període de dues setmanes. El teu ús real —i el fet que et mantinguis apuntat les dues setmanes senceres— és el que ho fa possible. No cal que la facis servir cada dia ni molta estona; un ritme natural al llarg de la quinzena és exactament el que cal. Tot el que veus són dades de demostració precarregades, així que canvia el que vulguis, crea, esborra i experimenta —no trencaràs res real."),
        "subtitle": "Proves tancades — gràcies per ajudar",
        "intro": ("Gràcies per unir-te a la prova tancada d'Entertain. La teva feina és simple: fes "
                  "servir l'app com ho faries a casa, durant les pròximes dues setmanes, i digue'ns què "
                  "funciona i què no. Aquesta guia breu et porta per les funcions principals perquè ho "
                  "puguis provar tot —però explora pel teu compte també si vols."),
        "need_title": "Què necessitem de tu",
        "need": [
            "Fes servir l'app uns quants dies diferents durant el període de proves —no tot de cop. Un ritme natural (una mica ara, una mica d'aquí uns dies) és exactament el que ajuda.",
            "Prova els fluxos principals de sota almenys un cop cadascun.",
            "Envia'ns el teu feedback des de Configuració › Suggeriments (el pots dictar per veu) —què t'ha agradat, què t'ha confós, qualsevol cosa que s'hagi trencat.",
            "Mantén-te apuntat les dues setmanes senceres, encara que ja hagis acabat d'explorar.",
        ],
        "walk_title": "Un recorregut ràpid",
        "walk": [
            ("Explora el catàleg", "Obre la pestanya Catàleg. Mira els plats, ingredients i begudes —vénen carregats amb fotos i insígnies dietètiques. Prova els filtres (vegà, vegetarià, sense gluten)."),
            ("Crea un plat amb IA", "Al Catàleg, prem «Crea un plat amb IA», escriu qualsevol nom o descripció de plat, i mira com et construeix una recepta completa amb foto. Desa-la."),
            ("Obre un esdeveniment", "Ves a la pestanya Esdeveniments i obre «Summer Garden Party». Mira les quatre pestanyes: Esdeveniment, Menú, Convidats, Compra."),
            ("Munta o completa el menú", "A la pestanya Menú, afegeix un plat o una beguda, o prova «Completa el menú amb IA». Fixa't que els plats s'ordenen automàticament."),
            ("Revisa els convidats", "A la pestanya Convidats, mira el semàfor confirmat / pendent / excusat i les insígnies dietètiques. Prova d'escriure una invitació."),
            ("Fes la compra", "A la pestanya Compra, canvia entre Comandes i En persona. Canvia l'estat d'un article a Comandes; marca articles a En persona. Prova de generar un missatge de comanda per a un proveïdor."),
            ("Genera el full resum", "Des de l'esdeveniment, prem Crea resum. Es genera un PDF complet de l'esdeveniment —obre'l i mira el menú, les receptes, els convidats i la compra, tot en un document."),
            ("Configura un proveïdor", "A Configuració › Proveïdors, obre'n un i afegeix-hi un contacte, o crea la teva pròpia categoria de proveïdor."),
        ],
        "feedback_title": "Com enviar feedback",
        "feedback": ("Ves a Configuració › Suggeriments i escriu (o dicta) qualsevol cosa que et vingui "
                     "al cap. El feedback més útil és concret: «el botó X feia Y quan esperava Z», "
                     "«aquesta pantalla m'ha confós perquè…», «m'encantaria que…». Fins i tot les coses "
                     "petites ajuden. Si alguna cosa ha petat o s'ha vist malament, digue'ns què "
                     "estaves fent en aquell moment."),
        "thanks": "Gràcies pel teu temps —de debò que fa millor l'app.",
        "footer": "Entertain · Proves tancades · Fotos d'stock proporcionades per Pexels.",
    },
    "es": {
        "doc_title": "Guía del probador",
        "why_title": "Por qué importa",
        "why": ("Entertain está en pruebas cerradas en Google Play. Para hacer avanzar la app hacia un lanzamiento público, necesitamos un grupo reducido de probadores usándola en dispositivos reales durante un periodo de dos semanas. Tu uso real —y el hecho de que te mantengas apuntado las dos semanas enteras— es lo que lo hace posible. No hace falta que la uses cada día ni mucho rato; un ritmo natural a lo largo de la quincena es exactamente lo que se necesita. Todo lo que ves son datos de demostración precargados, así que cambia lo que quieras, crea, borra y experimenta —no romperás nada real."),
        "subtitle": "Pruebas cerradas — gracias por ayudar",
        "intro": ("Gracias por unirte a la prueba cerrada de Entertain. Tu tarea es simple: usa la app "
                  "como lo harías en casa, durante las próximas dos semanas, y dinos qué funciona y qué "
                  "no. Esta guía breve te lleva por las funciones principales para que lo puedas probar "
                  "todo —pero explora por tu cuenta también si quieres."),
        "need_title": "Qué necesitamos de ti",
        "need": [
            "Usa la app unos cuantos días diferentes durante el periodo de pruebas —no todo de golpe. Un ritmo natural (un poco ahora, un poco dentro de unos días) es exactamente lo que ayuda.",
            "Prueba los flujos principales de abajo al menos una vez cada uno.",
            "Envíanos tu feedback desde Configuración › Sugerencias (lo puedes dictar por voz) —qué te ha gustado, qué te ha confundido, cualquier cosa que se haya roto.",
            "Mantente apuntado las dos semanas enteras, aunque ya hayas terminado de explorar.",
        ],
        "walk_title": "Un recorrido rápido",
        "walk": [
            ("Explora el catálogo", "Abre la pestaña Catálogo. Mira los platos, ingredientes y bebidas —vienen cargados con fotos e insignias dietéticas. Prueba los filtros (vegano, vegetariano, sin gluten)."),
            ("Crea un plato con IA", "En el Catálogo, pulsa «Crea un plato con IA», escribe cualquier nombre o descripción de plato, y mira cómo te construye una receta completa con foto. Guárdala."),
            ("Abre un evento", "Ve a la pestaña Eventos y abre «Summer Garden Party». Mira las cuatro pestañas: Evento, Menú, Invitados, Compra."),
            ("Monta o completa el menú", "En la pestaña Menú, añade un plato o una bebida, o prueba «Completa el menú con IA». Fíjate en que los platos se ordenan automáticamente."),
            ("Revisa los invitados", "En la pestaña Invitados, mira el semáforo confirmado / pendiente / excusado y las insignias dietéticas. Prueba a escribir una invitación."),
            ("Haz la compra", "En la pestaña Compra, cambia entre Pedidos y En persona. Cambia el estado de un artículo en Pedidos; marca artículos en En persona. Prueba a generar un mensaje de pedido para un proveedor."),
            ("Genera la hoja resumen", "Desde el evento, pulsa Crear resumen. Se genera un PDF completo del evento —ábrelo y mira el menú, las recetas, los invitados y la compra, todo en un documento."),
            ("Configura un proveedor", "En Configuración › Proveedores, abre uno y añade un contacto, o crea tu propia categoría de proveedor."),
        ],
        "feedback_title": "Cómo enviar feedback",
        "feedback": ("Ve a Configuración › Sugerencias y escribe (o dicta) cualquier cosa que se te "
                     "ocurra. El feedback más útil es concreto: «el botón X hacía Y cuando esperaba Z», "
                     "«esta pantalla me confundió porque…», «me encantaría que…». Hasta las cosas "
                     "pequeñas ayudan. Si algo se rompió o se vio mal, dinos qué estabas haciendo en "
                     "ese momento."),
        "thanks": "Gracias por tu tiempo —de verdad que hace mejor la app.",
        "footer": "Entertain · Pruebas cerradas · Fotos de stock proporcionadas por Pexels.",
    },
}
