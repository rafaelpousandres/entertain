# -*- coding: utf-8 -*-
"""Manual ca + es translations."""

MANUAL_CA = {
    "doc_title": "Manual d'usuari",
    "intro": ("Entertain t'ajuda a organitzar àpats i reunions a casa, de la idea a la taula. "
              "Prepares un catàleg reutilitzable de plats, begudes i ingredients; muntes el menú de "
              "cada esdeveniment; hi convides la gent; i obtens la llista de la compra ja calculada i "
              "agrupada per proveïdor. Aquest manual recull totes les funcionalitats de l'app, àrea "
              "per àrea. Per començar de pressa, consulta la Guia de primers passos; aquí hi trobaràs "
              "la referència completa."),
    "toc_title": "Índex",
    "blocks": [
        ('chap', 1, "La idea general"),
        ('p', "Entertain s'organitza en tres nivells que es construeixen un sobre l'altre. El catàleg "
              "és el teu rebost reutilitzable: hi defineixes una vegada els plats, les begudes i els "
              "ingredients, i els fas servir a tots els esdeveniments. L'esdeveniment és cada àpat o "
              "reunió concreta, amb la seva data, els seus comensals i el seu menú. La compra es genera "
              "automàticament a partir del menú, agrupada per proveïdor i amb les quantitats ja "
              "calculades. Com més fas servir l'app, més de pressa et va, perquè el catàleg creix i el "
              "reutilitzes."),
        ('chap', 2, "El catàleg"),
        ('p', "El catàleg té tres seccions —plats, ingredients i begudes—, cadascuna agrupada per "
              "categories en un acordió on només se'n manté una d'oberta alhora, amb un comptador per "
              "secció (per exemple, «12 plats»). El catàleg el prepares un cop i el reutilitzes sempre."),
        ('sub', "Plats"),
        ('p', "Cada plat té un nom, una categoria, un nombre de racions base, una descripció curta, la "
              "preparació pas a pas i fotos. Un plat pot ser cuinat a casa o comprat fet: amb el "
              "commutador «Cuinat / Comprat» tries quin és. Un plat comprat amaga els ingredients i, en "
              "lloc seu, demana el proveïdor i les racions per unitat; un plat cuinat es defineix amb la "
              "seva llista d'ingredients. Canviar el commutador no esborra els ingredients que ja havies "
              "posat, de manera que pots provar les dues modalitats sense por de perdre res."),
        ('sub', "Ingredients"),
        ('p', "Cada ingredient té un nom, una unitat per defecte (grams, unitats, ampolles…), una "
              "categoria de proveïdor per defecte (carnisseria, fruiteria…) i, opcionalment, una nota de "
              "preparació i fotos. La categoria de proveïdor per defecte és la que es farà servir a la "
              "llista de la compra quan aquest ingredient hi aparegui."),
        ('sub', "Begudes"),
        ('p', "Cada beguda té un nom, un proveïdor i una denominació (ampolla, llauna, garrafa, "
              "unitat…). A diferència dels plats, les begudes no escalen amb els comensals: en gestiones "
              "la quantitat d'unitats directament, sense racions. Les begudes noves van per defecte a la "
              "categoria de proveïdor Supermercat."),
        ('sub', "Noms multilingües"),
        ('p', "Quan escrius el nom d'un plat, una beguda o un ingredient en el teu idioma, Entertain "
              "l'omple automàticament als altres dos (català, castellà i anglès). Després, cada persona "
              "veu el catàleg en l'idioma que té configurat al telèfon. Això és pràctic si comparteixes "
              "l'organització amb algú que parla una altra llengua, o si cuines per a convidats "
              "internacionals. Els noms es mantenen amb la seva capitalització original."),
        ('sub', "Atributs dietètics"),
        ('p', "Pots marcar cada ingredient amb la seva dieta (desconegut, no-vegetarià, vegetarià o "
              "vegà) i amb el seu estat de gluten (desconegut, sense gluten o amb gluten). L'eix "
              "dietètic és ordenat: marcar un ingredient com a vegà implica que també és vegetarià. Els "
              "plats cuinats hereten la classificació dels seus ingredients de manera conservadora: si "
              "un sol ingredient és desconegut, el plat es considera desconegut; el plat és vegà només "
              "si tots els seus ingredients ho són. A la fitxa del plat, aquesta classificació apareix "
              "com a «derivada» i només de lectura. Els plats comprats, que no tenen ingredients, porten "
              "un valor dietètic que marques a mà."),
        ('sub', "Insígnies"),
        ('p', "A les files del catàleg, al menú i al full resum, les classificacions dietètiques es "
              "mostren amb una insígnia concisa perquè es vegin d'un cop d'ull. Una insígnia apareix "
              "només per a una característica coneguda i positiva: vegà (VGN), vegetarià (VGT) o sense "
              "gluten (SG). Quan un aspecte és desconegut, es mostra una insígnia negra «?» perquè el "
              "puguis completar; si tots dos eixos són desconeguts, apareix un sol «?». Una "
              "característica coneguda negativa (per exemple, conegut com a no vegetarià) no mostra res "
              "—cap insígnia ni cap «?» vol dir, simplement, que no ho és."),
        ('sub', "Filtrar el catàleg"),
        ('p', "Pots filtrar el catàleg de plats per atributs dietètics —vegà, vegetarià o sense gluten, "
              "que es combinen— i per si són cuinats a casa o comprats fets. Si cap plat coincideix amb "
              "el filtre, l'app t'ho indica. Els plats amb classificació desconeguda no apareixen mai "
              "sota un filtre dietètic positiu, per no donar una falsa garantia."),
        ('sub', "Esborrar"),
        ('p', "Pots esborrar plats, ingredients i begudes del catàleg. L'app distingeix entre «Esborra» "
              "—treure una cosa del catàleg— i «Treu de…» —treure-la d'un context concret, com un menú— "
              "de manera que mai esborris del catàleg quan només volies treure d'un esdeveniment."),
        ('chap', 3, "Crear amb intel·ligència artificial"),
        ('p', "Entertain incorpora assistents d'IA per omplir el catàleg i muntar menús més de pressa. "
              "Tota acció d'IA es reconeix pel símbol ✦."),
        ('sub', "Assistent de plats"),
        ('p', "És la manera més ràpida d'omplir el catàleg. Escrius un nom o una descripció, fins i tot "
              "vaga («com el gaspatxo però més espès», «un guisat de conill amb xocolata»), i l'assistent "
              "et prepara una fitxa completa: la llista d'ingredients amb les quantitats, el nombre de "
              "racions, la preparació pas a pas i una foto. La revises, l'ajustes si vols i la deses. A "
              "partir d'aquí el plat és teu i l'edites com qualsevol altre. Quan l'assistent crea "
              "ingredients nous, ja et proposa els seus atributs dietètics, que pots modificar."),
        ('sub', "Wizard de menú"),
        ('p', "Quan no saps per on començar un menú, el wizard («Crea el menú amb IA» / «Completa el "
              "menú amb IA») te'l proposa sencer. Respons unes quantes preguntes i afegeixes el que "
              "vulguis en text lliure, i obtens una proposta que barreja plats que ja tens al catàleg, "
              "plats nous fets a mida i begudes per acompanyar. Revises la proposta amb calma i tries "
              "què acceptes. El wizard funciona en mode «completa, no reemplaça»: afegeix coses al menú "
              "sense treure el que ja hi tenies."),
        ('sub', "Quotes"),
        ('p', "Les funcions d'IA tenen una quota mensual al pla gratuït (per exemple, l'assistent de "
              "plats i el wizard de menú). El comptador d'ús es mostra a la mateixa funció."),
        ('chap', 4, "Fotos"),
        ('p', "Pots posar imatge als teus plats, begudes i ingredients de tres maneres: fent una foto "
              "amb la càmera, triant-ne una de la galeria del telèfon, o cercant-ne una a Pexels, un "
              "banc de fotos professionals i gratuïtes, sense sortir de l'app. En la cerca de Pexels, el "
              "terme es preomple en el teu idioma i en anglès alhora, per trobar més i millors "
              "resultats; cada resultat mostra el crèdit del seu autor, i un comptador indica quantes "
              "cerques has fet del teu límit."),
        ('p', "Cada entitat pot tenir diverses fotos en un carrusel que pots reordenar; la primera és la "
              "portada que apareix a les llistes. Hi ha un visor a pantalla completa amb zoom de pinça i "
              "desplaçament entre fotos. Si descartes una edició de fotos, els canvis es reverteixen. "
              "Les fotos dels ingredients i de les begudes també apareixen al menú de l'esdeveniment i "
              "als selectors d'afegir, no només al catàleg. Pots afegir una foto des de la mateixa "
              "pantalla de creació, no només en editar."),
        ('chap', 5, "Esdeveniments"),
        ('p', "Un esdeveniment és qualsevol àpat o reunió: un sopar d'aniversari, un dinar de Nadal, una "
              "calçotada. Té un títol, un tipus (dinar o sopar), un format (assegut o bufet), una data i "
              "hora, un nombre de comensals, un lloc, notes i fotos."),
        ('p', "L'estat de l'esdeveniment es calcula sol —en preparació, llest o passat— a partir de les "
              "dates i de l'estat de la compra, i la llista d'esdeveniments s'agrupa per aquest estat. "
              "Pots duplicar un esdeveniment sencer, amb tot el seu menú: la còpia reinicia la data i "
              "els estats i s'anomena «Còpia de…», ideal per a celebracions que repeteixes. Cada "
              "esdeveniment té quatre pestanyes —Esdeveniment, Menú, Convidats i Compra— i l'app recorda "
              "en quina pestanya estaves de cada esdeveniment."),
        ('p', "El format decideix com s'escalen les quantitats: en un esdeveniment assegut, les racions "
              "de cada plat igualen el nombre de comensals; en un bufet, es respecten les racions del "
              "plat tal com estan al catàleg."),
        ('chap', 6, "El menú de l'esdeveniment"),
        ('p', "A la pestanya Menú afegeixes plats i begudes del teu catàleg. El botó «Afegeix» és "
              "contextual: si tens oberta la secció de Plats, va directe a afegir un plat; si tens "
              "oberta la de Begudes, a afegir una beguda; i si no tens cap secció oberta, et deixa triar "
              "entre plat i beguda. Pots agafar elements del catàleg o crear-ne de nous sobre la marxa "
              "sense perdre el fil. Els plats es llisten sempre en el seu ordre natural: aperitius, "
              "entrants, principals, postres i, al final, begudes."),
        ('p', "Quan afegeixes un plat a un esdeveniment, se'n fa una còpia per a aquell esdeveniment que "
              "pots editar independentment del catàleg —les racions, les línies, les notes— sense que "
              "afecti el plat original. Si edites les racions d'aquesta còpia, les quantitats dels "
              "ingredients s'escalen soles (arrodonint cap amunt, i amb nombres enters per als "
              "ingredients que es compten per unitats)."),
        ('p', "Pots afegir línies ad-hoc a un plat dins un esdeveniment, i marcar-les per promoure-les a "
              "la recepta del catàleg si vols que hi quedin per sempre. El menú mostra els totals: "
              "nombre de plats, racions i racions per comensal. En afegir una beguda, passes per "
              "l'editor de quantitat, igual que amb els plats."),
        ('chap', 7, "Convidats"),
        ('p', "A la pestanya Convidats portes la llista de convidats de l'esdeveniment. Pots afegir-los "
              "a mà o des dels contactes del telèfon (l'app demana permís i et deixa triar el telèfon o "
              "el correu). Cada convidat té un estat —pendent, confirmat o excusat— i la llista s'agrupa "
              "per estat en un acordió amb subtotals i total. L'estat es mostra amb un color clar de "
              "semàfor. Si confirmes més convidats dels comensals que havies previst, l'app t'avisa del "
              "sobre-aforament; és només informatiu i no canvia les racions del menú."),
        ('sub', "Invitacions i resposta del convidat"),
        ('p', "Pots escriure un text d'invitació a nivell d'esdeveniment (amb un esborrany editable) i "
              "enviar la invitació a cada convidat pel teu canal habitual —WhatsApp, SMS o correu—; en "
              "fer-ho, el convidat queda marcat com a invitat. La invitació pot portar un enllaç "
              "personal: el convidat obre una pàgina web mínima que només mostra el seu nom i el nom de "
              "l'esdeveniment, i confirma o declina ell mateix. També hi pot indicar les seves "
              "restriccions dietètiques (vegetarià, vegà, sense gluten). La resposta torna a la teva "
              "pestanya Convidats automàticament —sense app ni inici de sessió per al convidat— i pot "
              "reobrir l'enllaç per canviar-la; l'última resposta mana. La pàgina no mostra mai la data, "
              "el lloc ni els altres convidats (privadesa per disseny)."),
        ('chap', 8, "La compra"),
        ('p', "La pestanya Compra genera, a partir del menú, la llista de la compra agrupada per "
              "proveïdor i amb les quantitats ja calculades segons els comensals. La mateixa llista té "
              "dos modes que canvies amb les pestanyes inferiors."),
        ('sub', "Mode Comandes"),
        ('p', "La vista completa de comandes, per preparar les comandes als proveïdors des de casa. Cada "
              "ingredient té un estat dins una màquina d'estats: per demanar, demanat, rebut, a casa o "
              "falta. El selector només ofereix les transicions vàlides. Els capçals de cada proveïdor "
              "porten comptadors de color que resumeixen l'estat: vermell per al que cal demanar o "
              "falta, groc per al demanat, verd per al rebut o a casa. Els articles s'ordenen per "
              "urgència —per demanar, falta, demanat, rebut, a casa— i alfabèticament dins de cada estat."),
        ('sub', "Mode En persona"),
        ('p', "Una llista de verificació simplificada per fer servir a la botiga mateixa, marcant el que "
              "vas posant al carret a mesura que avances pels passadissos. Manté les seccions per "
              "proveïdor i els comptadors de color (així veus el progrés de franc) però substitueix el "
              "selector d'estats per una casella simple: marcar un article el posa com a rebut, "
              "desmarcar-lo el torna a pendent. Per afegir un extra o enviar una comanda, canvia a "
              "Comandes."),
        ('sub', "Agregació i extres"),
        ('p', "El mateix ingredient, quan coincideix en unitat, estat, proveïdor i nota, es fusiona en "
              "una sola línia amb la quantitat sumada; si en canvies l'estat, el canvi afecta totes les "
              "files agregades de cop. Pots afegir articles extra a la compra que no formen part de cap "
              "plat (per exemple, gel o tovallons): apareixen a la compra però no al menú."),
        ('sub', "Missatge de comanda i accions ràpides"),
        ('p', "Per a cada proveïdor pots generar un missatge de comanda a punt per enviar per WhatsApp, "
              "SMS, correu o el sistema de compartir. El missatge inclou només el que encara no li has "
              "demanat (el delta), amb una salutació, una data límit opcional i una signatura. D'un sol "
              "toc pots marcar tot el d'un proveïdor com a rebut, o fer servir «Usa com a llista de la "
              "compra». El rebost és una secció consultiva amb el que ja tens a casa; no genera cap "
              "missatge de comanda."),
        ('chap', 9, "Proveïdors"),
        ('p', "Pots tenir diversos proveïdors per a una mateixa categoria i marcar-ne un per defecte amb "
              "una estrella; quan generes una comanda d'aquella categoria i hi ha més d'un proveïdor, "
              "tries quin fas servir en aquell moment. De cada proveïdor en defineixes el nom comercial, "
              "el canal (WhatsApp, correu, compartir o cap) i l'adreça (telèfon o correu), i el pots "
              "importar dels contactes del dispositiu. A més de les categories de proveïdor del sistema, "
              "pots crear-ne de pròpies —una categoria pot representar una botiga, una parada de mercat "
              "o una secció del supermercat, segons com organitzis les teves compres."),
        ('chap', 10, "Configuració"),
        ('p', "A Configuració pots definir la salutació i la signatura dels missatges de comanda (les "
              "pots deixar buides expressament), i el canal de text del grup (SMS o WhatsApp), que "
              "determina com s'envien els missatges de tipus «text». També pots triar el mode de compra "
              "per defecte (Comandes o En persona) amb què s'obre la pestanya Compra, i activar o "
              "desactivar les pistes d'entrada. Hi ha una caixa de suggeriments per fer-nos arribar "
              "idees; admet el dictat per veu a través del teclat del sistema. També hi trobaràs els "
              "crèdits (les fotos d'stock són proporcionades per Pexels) i el teu identificador d'usuari "
              "(útil per a sol·licituds d'esborrat de dades). L'app fa servir automàticament l'idioma "
              "del sistema, sense selector manual, i a cada pantalla principal tens una icona ? amb una "
              "explicació curta."),
        ('chap', 11, "El full resum"),
        ('p', "Des de la pantalla d'un esdeveniment pots generar un document resum en PDF que recull tot "
              "l'esdeveniment: el logotip d'Entertain, el nom, totes les dades, els convidats, i els "
              "plats amb les seves receptes i ingredients, a més de les begudes i la llista de la "
              "compra. Cada plat apareix amb la seva foto, les insígnies dietètiques i les racions; les "
              "seccions porten títol per tipus de plat en l'ordre natural, i la maquetació fa servir "
              "línies netes de dos gruixos per separar els blocs. És ideal per imprimir-lo i tenir-lo a "
              "la cuina, o per compartir-lo amb qui t'ajuda a organitzar. El fitxer pren el nom de "
              "l'esdeveniment, amb els seus espais i majúscules."),
        ('chap', 12, "Trucs i detalls útils"),
        ('p', "Arreu de l'app, els acordions mantenen una sola secció oberta alhora, perquè et "
              "concentris en una cosa cada vegada. Desar és sempre una acció explícita (el ✓ de la barra "
              "superior); si surts d'una pantalla amb canvis sense desar, l'app t'avisa abans de "
              "descartar-los. I a cada pantalla principal, la icona ? t'ofereix una explicació curta i "
              "traduïda del que pots fer-hi. Necessites una introducció ràpida? Consulta la Guia de "
              "primers passos."),
    ],
    "footer": "Necessites una introducció ràpida? Consulta la Guia de primers passos. · Fotos d'stock proporcionades per Pexels.",
}

MANUAL_ES = {
    "doc_title": "Manual de usuario",
    "intro": ("Entertain te ayuda a organizar comidas y reuniones en casa, de la idea a la mesa. "
              "Preparas un catálogo reutilizable de platos, bebidas e ingredientes; montas el menú de "
              "cada evento; invitas a la gente; y obtienes la lista de la compra ya calculada y "
              "agrupada por proveedor. Este manual recoge todas las funcionalidades de la app, área "
              "por área. Para empezar rápido, consulta la Guía de primeros pasos; aquí encontrarás la "
              "referencia completa."),
    "toc_title": "Índice",
    "blocks": [
        ('chap', 1, "La idea general"),
        ('p', "Entertain se organiza en tres niveles que se construyen uno sobre otro. El catálogo es "
              "tu despensa reutilizable: defines una vez los platos, las bebidas y los ingredientes, y "
              "los usas en todos los eventos. El evento es cada comida o reunión concreta, con su "
              "fecha, sus comensales y su menú. La compra se genera automáticamente a partir del menú, "
              "agrupada por proveedor y con las cantidades ya calculadas. Cuanto más usas la app, más "
              "rápido te va, porque el catálogo crece y lo reutilizas."),
        ('chap', 2, "El catálogo"),
        ('p', "El catálogo tiene tres secciones —platos, ingredientes y bebidas—, cada una agrupada por "
              "categorías en un acordeón que solo mantiene una abierta a la vez, con un contador por "
              "sección (por ejemplo, «12 platos»). El catálogo lo preparas una vez y lo reutilizas "
              "siempre."),
        ('sub', "Platos"),
        ('p', "Cada plato tiene un nombre, una categoría, un número de raciones base, una descripción "
              "corta, la preparación paso a paso y fotos. Un plato puede ser cocinado en casa o "
              "comprado hecho: con el conmutador «Cocinado / Comprado» eliges cuál. Un plato comprado "
              "oculta los ingredientes y, en su lugar, pide el proveedor y las raciones por unidad; un "
              "plato cocinado se define con su lista de ingredientes. Cambiar el conmutador no borra los "
              "ingredientes que ya habías puesto, de manera que puedes probar las dos modalidades sin "
              "miedo a perder nada."),
        ('sub', "Ingredientes"),
        ('p', "Cada ingrediente tiene un nombre, una unidad por defecto (gramos, unidades, "
              "botellas…), una categoría de proveedor por defecto (carnicería, frutería…) y, "
              "opcionalmente, una nota de preparación y fotos. La categoría de proveedor por defecto es "
              "la que se usará en la lista de la compra cuando este ingrediente aparezca en ella."),
        ('sub', "Bebidas"),
        ('p', "Cada bebida tiene un nombre, un proveedor y una denominación (botella, lata, garrafa, "
              "unidad…). A diferencia de los platos, las bebidas no escalan con los comensales: "
              "gestionas la cantidad de unidades directamente, sin raciones. Las bebidas nuevas van por "
              "defecto a la categoría de proveedor Supermercado."),
        ('sub', "Nombres multilingües"),
        ('p', "Cuando escribes el nombre de un plato, una bebida o un ingrediente en tu idioma, "
              "Entertain lo rellena automáticamente en los otros dos (catalán, castellano e inglés). "
              "Después, cada persona ve el catálogo en el idioma que tiene configurado en el teléfono. "
              "Esto es práctico si compartes la organización con alguien que habla otra lengua, o si "
              "cocinas para invitados internacionales. Los nombres se mantienen con su capitalización "
              "original."),
        ('sub', "Atributos dietéticos"),
        ('p', "Puedes marcar cada ingrediente con su dieta (desconocido, no vegetariano, vegetariano o "
              "vegano) y con su estado de gluten (desconocido, sin gluten o con gluten). El eje "
              "dietético es ordenado: marcar un ingrediente como vegano implica que también es "
              "vegetariano. Los platos cocinados heredan la clasificación de sus ingredientes de manera "
              "conservadora: si un solo ingrediente es desconocido, el plato se considera desconocido; "
              "el plato es vegano solo si todos sus ingredientes lo son. En la ficha del plato, esta "
              "clasificación aparece como «derivada» y solo de lectura. Los platos comprados, que no "
              "tienen ingredientes, llevan un valor dietético que marcas a mano."),
        ('sub', "Insignias"),
        ('p', "En las filas del catálogo, el menú y la hoja resumen, las clasificaciones dietéticas se "
              "muestran con una insignia concisa para que se vean de un vistazo. Una insignia aparece "
              "solo para una característica conocida y positiva: vegano (VGN), vegetariano (VGT) o sin "
              "gluten (SG). Cuando un aspecto es desconocido, se muestra una insignia negra «?» para que "
              "lo puedas completar; si ambos ejes son desconocidos, aparece un solo «?». Una "
              "característica conocida negativa (por ejemplo, conocido como no vegetariano) no muestra "
              "nada —ninguna insignia ni «?» significa, simplemente, que no lo es."),
        ('sub', "Filtrar el catálogo"),
        ('p', "Puedes filtrar el catálogo de platos por atributos dietéticos —vegano, vegetariano o sin "
              "gluten, que se combinan— y por si son cocinados en casa o comprados hechos. Si ningún "
              "plato coincide con el filtro, la app te lo indica. Los platos con clasificación "
              "desconocida no aparecen nunca bajo un filtro dietético positivo, para no dar una falsa "
              "garantía."),
        ('sub', "Borrar"),
        ('p', "Puedes borrar platos, ingredientes y bebidas del catálogo. La app distingue entre "
              "«Borra» —quitar algo del catálogo— y «Quita de…» —sacarlo de un contexto concreto, como "
              "un menú— de manera que nunca borres del catálogo cuando solo querías quitar de un evento."),
        ('chap', 3, "Crear con inteligencia artificial"),
        ('p', "Entertain incorpora asistentes de IA para llenar el catálogo y montar menús más rápido. "
              "Toda acción de IA se reconoce por el símbolo ✦."),
        ('sub', "Asistente de platos"),
        ('p', "Es la manera más rápida de llenar el catálogo. Escribes un nombre o una descripción, "
              "incluso vaga («como el gazpacho pero más espeso», «un guiso de conejo con chocolate»), y "
              "el asistente te prepara una ficha completa: la lista de ingredientes con las cantidades, "
              "el número de raciones, la preparación paso a paso y una foto. La revisas, la ajustas si "
              "quieres y la guardas. A partir de aquí el plato es tuyo y lo editas como cualquier otro. "
              "Cuando el asistente crea ingredientes nuevos, ya te propone sus atributos dietéticos, que "
              "puedes modificar."),
        ('sub', "Asistente de menú"),
        ('p', "Cuando no sabes por dónde empezar un menú, el asistente («Crea el menú con IA» / "
              "«Completa el menú con IA») te lo propone entero. Respondes unas cuantas preguntas y "
              "añades lo que quieras en texto libre, y obtienes una propuesta que mezcla platos que ya "
              "tienes en el catálogo, platos nuevos a medida y bebidas para acompañar. Revisas la "
              "propuesta con calma y eliges qué aceptas. El asistente funciona en modo «completa, no "
              "reemplaza»: añade cosas al menú sin quitar lo que ya tenías."),
        ('sub', "Cuotas"),
        ('p', "Las funciones de IA tienen una cuota mensual en el plan gratuito (por ejemplo, el "
              "asistente de platos y el de menú). El contador de uso se muestra en la propia función."),
        ('chap', 4, "Fotos"),
        ('p', "Puedes poner imagen a tus platos, bebidas e ingredientes de tres maneras: haciendo una "
              "foto con la cámara, eligiendo una de la galería del teléfono, o buscando una en Pexels, "
              "un banco de fotos profesionales y gratuitas, sin salir de la app. En la búsqueda de "
              "Pexels, el término se rellena en tu idioma y en inglés a la vez, para encontrar más y "
              "mejores resultados; cada resultado muestra el crédito de su autor, y un contador indica "
              "cuántas búsquedas has hecho de tu límite."),
        ('p', "Cada entidad puede tener varias fotos en un carrusel que puedes reordenar; la primera es "
              "la portada que aparece en las listas. Hay un visor a pantalla completa con zoom de pinza "
              "y desplazamiento entre fotos. Si descartas una edición de fotos, los cambios se "
              "revierten. Las fotos de los ingredientes y de las bebidas también aparecen en el menú del "
              "evento y en los selectores de añadir, no solo en el catálogo. Puedes añadir una foto "
              "desde la misma pantalla de creación, no solo al editar."),
        ('chap', 5, "Eventos"),
        ('p', "Un evento es cualquier comida o reunión: una cena de cumpleaños, un almuerzo de Navidad, "
              "una barbacoa. Tiene un título, un tipo (almuerzo o cena), un formato (sentado o bufé), "
              "una fecha y hora, un número de comensales, un lugar, notas y fotos."),
        ('p', "El estado del evento se calcula solo —en preparación, listo o pasado— a partir de las "
              "fechas y del estado de la compra, y la lista de eventos se agrupa por este estado. Puedes "
              "duplicar un evento entero, con todo su menú: la copia reinicia la fecha y los estados y "
              "se llama «Copia de…», ideal para celebraciones que repites. Cada evento tiene cuatro "
              "pestañas —Evento, Menú, Invitados y Compra— y la app recuerda en qué pestaña estabas de "
              "cada evento."),
        ('p', "El formato decide cómo se escalan las cantidades: en un evento sentado, las raciones de "
              "cada plato igualan el número de comensales; en un bufé, se respetan las raciones del "
              "plato tal como están en el catálogo."),
        ('chap', 6, "El menú del evento"),
        ('p', "En la pestaña Menú añades platos y bebidas de tu catálogo. El botón «Añadir» es "
              "contextual: si tienes abierta la sección de Platos, va directo a añadir un plato; si "
              "tienes abierta la de Bebidas, a añadir una bebida; y si no tienes ninguna sección "
              "abierta, te deja elegir entre plato y bebida. Puedes coger elementos del catálogo o crear "
              "nuevos sobre la marcha sin perder el hilo. Los platos se listan siempre en su orden "
              "natural: aperitivos, entrantes, principales, postres y, al final, bebidas."),
        ('p', "Cuando añades un plato a un evento, se hace una copia para ese evento que puedes editar "
              "independientemente del catálogo —las raciones, las líneas, las notas— sin que afecte al "
              "plato original. Si editas las raciones de esta copia, las cantidades de los ingredientes "
              "se escalan solas (redondeando hacia arriba, y con números enteros para los ingredientes "
              "que se cuentan por unidades)."),
        ('p', "Puedes añadir líneas ad-hoc a un plato dentro de un evento, y marcarlas para promoverlas "
              "a la receta del catálogo si quieres que se queden para siempre. El menú muestra los "
              "totales: número de platos, raciones y raciones por comensal. Al añadir una bebida, pasas "
              "por el editor de cantidad, igual que con los platos."),
        ('chap', 7, "Invitados"),
        ('p', "En la pestaña Invitados llevas la lista de invitados del evento. Puedes añadirlos a mano "
              "o desde los contactos del teléfono (la app pide permiso y te deja elegir el teléfono o el "
              "correo). Cada invitado tiene un estado —pendiente, confirmado o excusado— y la lista se "
              "agrupa por estado en un acordeón con subtotales y total. El estado se muestra con un "
              "color claro de semáforo. Si confirmas más invitados que los comensales que habías "
              "previsto, la app te avisa del sobreaforo; es solo informativo y no cambia las raciones "
              "del menú."),
        ('sub', "Invitaciones y respuesta del invitado"),
        ('p', "Puedes escribir un texto de invitación a nivel de evento (con un borrador editable) y "
              "enviar la invitación a cada invitado por tu canal habitual —WhatsApp, SMS o correo—; al "
              "hacerlo, el invitado queda marcado como invitado. La invitación puede llevar un enlace "
              "personal: el invitado abre una página web mínima que solo muestra su nombre y el nombre "
              "del evento, y confirma o declina él mismo. También puede indicar sus restricciones "
              "dietéticas (vegetariano, vegano, sin gluten). La respuesta vuelve a tu pestaña Invitados "
              "automáticamente —sin app ni inicio de sesión para el invitado— y puede reabrir el enlace "
              "para cambiarla; la última respuesta manda. La página no muestra nunca la fecha, el lugar "
              "ni los demás invitados (privacidad por diseño)."),
        ('chap', 8, "La compra"),
        ('p', "La pestaña Compra genera, a partir del menú, la lista de la compra agrupada por proveedor "
              "y con las cantidades ya calculadas según los comensales. La misma lista tiene dos modos "
              "que cambias con las pestañas inferiores."),
        ('sub', "Modo Pedidos"),
        ('p', "La vista completa de pedidos, para preparar los pedidos a los proveedores desde casa. "
              "Cada ingrediente tiene un estado dentro de una máquina de estados: por pedir, pedido, "
              "recibido, en casa o falta. El selector solo ofrece las transiciones válidas. Las "
              "cabeceras de cada proveedor llevan contadores de color que resumen el estado: rojo para "
              "lo que hay que pedir o falta, amarillo para lo pedido, verde para lo recibido o en casa. "
              "Los artículos se ordenan por urgencia —por pedir, falta, pedido, recibido, en casa— y "
              "alfabéticamente dentro de cada estado."),
        ('sub', "Modo En persona"),
        ('p', "Una lista de verificación simplificada para usar en la tienda misma, marcando lo que vas "
              "poniendo en el carrito a medida que avanzas por los pasillos. Mantiene las secciones por "
              "proveedor y los contadores de color (así ves el progreso gratis) pero sustituye el "
              "selector de estados por una casilla simple: marcar un artículo lo pone como recibido, "
              "desmarcarlo lo devuelve a pendiente. Para añadir un extra o enviar un pedido, cambia a "
              "Pedidos."),
        ('sub', "Agregación y extras"),
        ('p', "El mismo ingrediente, cuando coincide en unidad, estado, proveedor y nota, se fusiona en "
              "una sola línea con la cantidad sumada; si cambias su estado, el cambio afecta a todas las "
              "filas agregadas a la vez. Puedes añadir artículos extra a la compra que no forman parte "
              "de ningún plato (por ejemplo, hielo o servilletas): aparecen en la compra pero no en el "
              "menú."),
        ('sub', "Mensaje de pedido y acciones rápidas"),
        ('p', "Para cada proveedor puedes generar un mensaje de pedido listo para enviar por WhatsApp, "
              "SMS, correo o el sistema de compartir. El mensaje incluye solo lo que aún no le has "
              "pedido (el delta), con un saludo, una fecha límite opcional y una firma. De un solo toque "
              "puedes marcar todo lo de un proveedor como recibido, o usar «Usar como lista de la "
              "compra». La despensa es una sección consultiva con lo que ya tienes en casa; no genera "
              "ningún mensaje de pedido."),
        ('chap', 9, "Proveedores"),
        ('p', "Puedes tener varios proveedores para una misma categoría y marcar uno por defecto con "
              "una estrella; cuando generas un pedido de esa categoría y hay más de un proveedor, eliges "
              "cuál usas en ese momento. De cada proveedor defines el nombre comercial, el canal "
              "(WhatsApp, correo, compartir o ninguno) y la dirección (teléfono o correo), y lo puedes "
              "importar de los contactos del dispositivo. Además de las categorías de proveedor del "
              "sistema, puedes crear las tuyas —una categoría puede representar una tienda, un puesto de "
              "mercado o una sección del supermercado, según cómo organices tus compras."),
        ('chap', 10, "Configuración"),
        ('p', "En Configuración puedes definir el saludo y la firma de los mensajes de pedido (las "
              "puedes dejar vacías expresamente), y el canal de texto del grupo (SMS o WhatsApp), que "
              "determina cómo se envían los mensajes de tipo «texto». También puedes elegir el modo de "
              "compra por defecto (Pedidos o En persona) con que se abre la pestaña Compra, y activar o "
              "desactivar las pistas de entrada. Hay una caja de sugerencias para hacernos llegar ideas; "
              "admite el dictado por voz a través del teclado del sistema. También encontrarás los "
              "créditos (las fotos de stock las proporciona Pexels) y tu identificador de usuario (útil "
              "para solicitudes de borrado de datos). La app usa automáticamente el idioma del sistema, "
              "sin selector manual, y en cada pantalla principal tienes un icono ? con una explicación "
              "corta."),
        ('chap', 11, "La hoja resumen"),
        ('p', "Desde la pantalla de un evento puedes generar un documento resumen en PDF que recoge todo "
              "el evento: el logotipo de Entertain, el nombre, todos los datos, los invitados, y los "
              "platos con sus recetas e ingredientes, además de las bebidas y la lista de la compra. "
              "Cada plato aparece con su foto, las insignias dietéticas y las raciones; las secciones "
              "llevan título por tipo de plato en el orden natural, y la maquetación usa líneas limpias "
              "de dos grosores para separar los bloques. Es ideal para imprimirlo y tenerlo en la "
              "cocina, o para compartirlo con quien te ayuda a organizar. El archivo toma el nombre del "
              "evento, con sus espacios y mayúsculas."),
        ('chap', 12, "Trucos y detalles útiles"),
        ('p', "Por toda la app, los acordeones mantienen una sola sección abierta a la vez, para que te "
              "concentres en una cosa cada vez. Guardar es siempre una acción explícita (el ✓ de la "
              "barra superior); si sales de una pantalla con cambios sin guardar, la app te avisa antes "
              "de descartarlos. Y en cada pantalla principal, el icono ? te ofrece una explicación corta "
              "y traducida de lo que puedes hacer ahí. ¿Necesitas una introducción rápida? Consulta la "
              "Guía de primeros pasos."),
    ],
    "footer": "¿Necesitas una introducción rápida? Consulta la Guía de primeros pasos. · Fotos de stock proporcionadas por Pexels.",
}
