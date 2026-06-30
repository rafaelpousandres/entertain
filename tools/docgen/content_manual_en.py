# -*- coding: utf-8 -*-
"""
Manual content — EN master + ca/es. 12 chapters, updated to v1.0.28.
block kinds: ('chap', n, title) | ('sub', title) | ('p', text)
"""

MANUAL = {
    "en": {
        "doc_title": "User manual",
        "intro": ("Entertain helps you organise meals and gatherings at home, from the idea to the "
                  "table. You build a reusable catalog of dishes, drinks and ingredients; you put "
                  "together the menu for each event; you invite your guests; and you get the "
                  "shopping list already calculated and grouped by supplier. This manual covers "
                  "every feature of the app, area by area. To get going quickly, see the Getting "
                  "started guide; here you'll find the complete reference."),
        "toc_title": "Contents",
        "blocks": [
            ('chap', 1, "The big picture"),
            ('p', "Entertain is organised in three levels that build on one another. The catalog is "
                  "your reusable pantry: you define dishes, drinks and ingredients once, and use them "
                  "across every event. The event is each specific meal or gathering, with its date, "
                  "its guests and its menu. The shopping is generated automatically from the menu, "
                  "grouped by supplier and with the quantities already calculated. The more you use "
                  "the app, the faster it gets, because the catalog grows and you reuse it."),

            ('chap', 2, "The catalog"),
            ('p', "The catalog has three sections — dishes, ingredients and drinks — each grouped by "
                  "categories in an accordion that keeps only one open at a time, with a counter per "
                  "section (for example, \"12 dishes\"). You set up the catalog once and reuse it "
                  "always."),
            ('sub', "Dishes"),
            ('p', "Each dish has a name, a category, a base number of servings, a short description, "
                  "the step-by-step preparation and photos. A dish can be cooked at home or bought "
                  "ready-made: the \"Cooked / Bought\" switch chooses which. A bought dish hides the "
                  "ingredients and instead asks for the supplier and the servings per unit; a cooked "
                  "dish is defined by its ingredient list. Flipping the switch doesn't erase the "
                  "ingredients you'd already entered, so you can try both modes without fear of "
                  "losing anything."),
            ('sub', "Ingredients"),
            ('p', "Each ingredient has a name, a default unit (grams, units, bottles…), a default "
                  "supplier category (butcher, greengrocer…) and, optionally, a preparation note and "
                  "photos. The default supplier category is the one used in the shopping list when "
                  "that ingredient appears there."),
            ('sub', "Drinks"),
            ('p', "Each drink has a name, a supplier and a denomination (bottle, can, carafe, "
                  "unit…). Unlike dishes, drinks don't scale with the number of guests: you manage "
                  "the quantity of units directly, without servings. New drinks default to the "
                  "Supermarket supplier category."),
            ('sub', "Multilingual names"),
            ('p', "When you type the name of a dish, drink or ingredient in your language, Entertain "
                  "fills it in automatically in the other two (Catalan, Spanish and English). After "
                  "that, each person sees the catalog in the language set on their phone. This is "
                  "handy if you share the organising with someone who speaks another language, or if "
                  "you cook for international guests. Names keep their original capitalisation."),
            ('sub', "Dietary attributes"),
            ('p', "You can mark each ingredient with its diet (unknown, non-vegetarian, vegetarian or "
                  "vegan) and its gluten state (unknown, gluten-free or contains gluten). The dietary "
                  "axis is ordered: marking an ingredient as vegan implies it is also vegetarian. "
                  "Cooked dishes inherit the classification from their ingredients conservatively: if "
                  "a single ingredient is unknown, the dish is considered unknown; the dish is vegan "
                  "only if all its ingredients are. On the dish card this classification appears as "
                  "\"derived\" and read-only. Bought dishes, which have no ingredients, carry a "
                  "dietary value you set by hand."),
            ('sub', "Badges"),
            ('p', "In catalog rows, the menu and the summary sheet, dietary classifications show as a "
                  "concise badge so they read at a glance. A badge appears only for a known, positive "
                  "characteristic: vegan (VGN), vegetarian (VGT) or gluten-free (SG). When an aspect "
                  "is unknown, a black \"?\" badge shows so you can complete it; if both axes are "
                  "unknown, a single \"?\" appears. A known-negative characteristic (for example, "
                  "known not vegetarian) shows nothing at all — no badge and no \"?\" means it is "
                  "simply not so."),
            ('sub', "Filtering the catalog"),
            ('p', "You can filter the dish catalog by dietary attributes — vegan, vegetarian or "
                  "gluten-free, which combine — and by whether they're cooked at home or bought "
                  "ready-made. If no dish matches the filter, the app tells you. Dishes with an "
                  "unknown classification never appear under a positive dietary filter, so as not to "
                  "give a false guarantee."),
            ('sub', "Deleting"),
            ('p', "You can delete dishes, ingredients and drinks from the catalog. The app "
                  "distinguishes between \"Delete\" — removing something from the catalog — and "
                  "\"Remove from…\" — taking it out of a specific context, like a menu — so you never "
                  "delete from the catalog when you only meant to remove from an event."),

            ('chap', 3, "Creating with artificial intelligence"),
            ('p', "Entertain includes AI assistants to fill the catalog and build menus faster. Every "
                  "AI action is recognisable by the ✦ symbol."),
            ('sub', "Dish assistant"),
            ('p', "It's the fastest way to fill the catalog. You write a name or a description, even "
                  "a vague one (\"like gazpacho but thicker\", \"a rabbit stew with chocolate\"), and "
                  "the assistant prepares a complete card: the ingredient list with quantities, the "
                  "number of servings, the step-by-step preparation and a photo. You review it, "
                  "adjust it if you like and save it. From then on the dish is yours and you edit it "
                  "like any other. When the assistant creates new ingredients, it already proposes "
                  "their dietary attributes, which you can change."),
            ('sub', "Menu wizard"),
            ('p', "When you don't know where to start a menu, the wizard (\"Create the menu with "
                  "AI\" / \"Complete the menu with AI\") proposes the whole thing. You answer a few "
                  "questions and add anything you like in free text, and you get a proposal mixing "
                  "dishes you already have in the catalog, new made-to-measure dishes and drinks to "
                  "go with them. You review the proposal calmly and choose what to accept. The wizard "
                  "works in \"complete, don't replace\" mode: it adds to the menu without removing "
                  "what you already had."),
            ('sub', "Quotas"),
            ('p', "AI features have a monthly quota on the free plan (for example, the dish assistant "
                  "and the menu wizard). The usage counter is shown on the feature itself."),

            ('chap', 4, "Photos"),
            ('p', "You can add an image to your dishes, drinks and ingredients in three ways: taking "
                  "a photo with the camera, choosing one from the phone's gallery, or searching "
                  "Pexels, a bank of free, professional photos, without leaving the app. In the "
                  "Pexels search, the term is pre-filled in your language and in English at once, to "
                  "find more and better results; each result shows its author's credit, and a counter "
                  "indicates how many searches you've made of your limit."),
            ('p', "Each entity can have several photos in a carousel you can reorder; the first is the "
                  "cover that appears in lists. There's a full-screen viewer with pinch zoom and "
                  "swiping between photos. If you discard a photo edit, the changes are reverted. The "
                  "photos of ingredients and drinks also appear in the event menu and in the add "
                  "selectors, not only in the catalog. You can add a photo right from the creation "
                  "screen, not only when editing."),

            ('chap', 5, "Events"),
            ('p', "An event is any meal or gathering: a birthday dinner, a Christmas lunch, a "
                  "barbecue. It has a title, a type (lunch or dinner), a format (seated or buffet), a "
                  "date and time, a number of guests, a place, notes and photos."),
            ('p', "The event's status is computed on its own — in preparation, ready or past — from "
                  "the dates and the shopping state, and the events list is grouped by this status. "
                  "You can duplicate a whole event, with its entire menu: the copy resets the date and "
                  "the states and is named \"Copy of…\", ideal for celebrations you repeat. Each event "
                  "has four tabs — Event, Menu, Guests and Shopping — and the app remembers which tab "
                  "you were on for each event."),
            ('p', "The format decides how quantities scale: in a seated event, each dish's servings "
                  "equal the number of guests; in a buffet, the dish's servings are respected as they "
                  "are in the catalog."),

            ('chap', 6, "The event menu"),
            ('p', "On the Menu tab you add dishes and drinks from your catalog. The \"Add\" button is "
                  "contextual: if you have the Dishes section open, it goes straight to adding a dish; "
                  "if you have Drinks open, to adding a drink; and if no section is open, it lets you "
                  "choose between dish and drink. You can take items from the catalog or create new "
                  "ones on the fly without losing your place. Courses are always listed in their "
                  "natural order: aperitifs, starters, mains, desserts, then drinks."),
            ('p', "When you add a dish to an event, a copy is made for that event that you can edit "
                  "independently of the catalog — the servings, the lines, the notes — without "
                  "affecting the original dish. If you edit this copy's servings, the ingredient "
                  "quantities scale on their own (rounding up, and with whole numbers for ingredients "
                  "counted by units)."),
            ('p', "You can add ad-hoc lines to a dish within an event, and mark them to promote them "
                  "to the catalog recipe if you want them to stay for good. The menu shows the totals: "
                  "number of dishes, servings and servings per guest. When you add a drink, you go "
                  "through the quantity editor, just as with dishes."),

            ('chap', 7, "Guests"),
            ('p', "On the Guests tab you keep the event's guest list. You can add guests by hand or "
                  "from the phone contacts (the app asks for permission and lets you pick the phone or "
                  "the email). Each guest has a status — pending, confirmed or excused — and the list "
                  "is grouped by status in an accordion with subtotals and a total. The status shows "
                  "as a clear traffic-light colour. If you confirm more guests than the people you'd "
                  "planned, the app warns you of the over-capacity; it's only informational and "
                  "doesn't change the menu servings."),
            ('sub', "Invitations and self-RSVP"),
            ('p', "You can write an invitation text at event level (with an editable draft) and send "
                  "the invitation to each guest through your usual channel — WhatsApp, SMS or email; "
                  "doing so marks the guest as invited. The invitation can carry a personal link: the "
                  "guest opens a tiny web page showing only their name and the event name, and "
                  "confirms or declines themselves. They can also report their dietary restrictions "
                  "(vegetarian, vegan, gluten-free) right there. Their answer flows back into your "
                  "Guests tab automatically — no app, no login for the guest — and they can reopen the "
                  "link to change it; the last answer wins. The page never shows the date, the place "
                  "or the other guests (privacy by design)."),

            ('chap', 8, "The shopping"),
            ('p', "The Shopping tab generates, from the menu, the shopping list grouped by supplier "
                  "and with the quantities already calculated for your guests. The same list has two "
                  "modes you switch between with the bottom tabs."),
            ('sub', "Orders mode"),
            ('p', "The full ordering view, to prepare supplier orders from home. Each ingredient has "
                  "a state in a small state machine: to order, ordered, received, at home or missing. "
                  "The selector only offers valid transitions. Each supplier's header carries "
                  "coloured counters that summarise the state: red for to-order or missing, yellow for "
                  "ordered, green for received or at home. Items are ordered by urgency — to order, "
                  "missing, ordered, received, at home — and alphabetically within each state."),
            ('sub', "In-person mode"),
            ('p', "A simplified checklist to use in the shop itself, ticking off what you pick up as "
                  "you walk the aisles. It keeps the supplier sections and the colour counters (so "
                  "you see your progress for free) but replaces the state selector with a simple "
                  "checkbox: ticking an item marks it as received, unticking returns it to pending. To "
                  "add an extra or send an order, switch to Orders."),
            ('sub', "Aggregation and extras"),
            ('p', "The same ingredient, when it matches in unit, state, supplier and note, merges into "
                  "a single line with the summed quantity; changing its state affects all the "
                  "aggregated rows at once. You can add extra items to the shopping that aren't part "
                  "of any dish (for example, ice or napkins): they appear in the shopping but not in "
                  "the menu."),
            ('sub', "Order message and quick actions"),
            ('p', "For each supplier you can generate an order message ready to send by WhatsApp, SMS, "
                  "email or the share system. The message includes only what you haven't ordered yet "
                  "(the delta), with a greeting, an optional deadline and a signature. With a single "
                  "tap you can mark everything from a supplier as received, or use \"Use as shopping "
                  "list\". The pantry is a consultative section with what you already have at home; it "
                  "generates no order message."),

            ('chap', 9, "Suppliers"),
            ('p', "You can have several suppliers for the same category and mark one as default with a "
                  "star; when you generate an order for that category and there's more than one "
                  "supplier, you choose which you use at that moment. For each supplier you define the "
                  "trade name, the channel (WhatsApp, email, share or none) and the address (phone or "
                  "email), and you can import it from the device contacts. Besides the system supplier "
                  "categories, you can create your own — a category can represent a shop, a market "
                  "stall or a supermarket aisle, however you organise your shopping."),

            ('chap', 10, "Settings"),
            ('p', "In Settings you can define the greeting and signature of the order messages (you "
                  "can leave them empty on purpose), and the group's text channel (SMS or WhatsApp), "
                  "which determines how \"text\" messages are sent. You can also choose the default "
                  "shopping mode (Orders or In person) the Shopping tab opens in, and turn the entry "
                  "tips on or off. There's a suggestions box to send us ideas; it accepts voice "
                  "dictation through the system keyboard. You'll also find the credits (stock photos "
                  "are provided by Pexels) and your user identifier (useful for data-deletion "
                  "requests). The app automatically uses the system language, with no manual selector, "
                  "and on each main screen there's a ? icon with a short explanation."),

            ('chap', 11, "The summary sheet"),
            ('p', "From an event's screen you can generate a summary document in PDF that gathers the "
                  "whole event: the Entertain logo, the name, all the data, the guests, and the "
                  "dishes with their recipes and ingredients, plus the drinks and the shopping list. "
                  "Each dish appears with its photo, dietary badges and servings; sections are titled "
                  "by course in the natural order, and the layout uses clean two-weight rules to "
                  "separate the blocks. It's ideal to print and keep in the kitchen, or to share with "
                  "whoever helps you organise. The file is named after the event, with its spaces and "
                  "capitals."),

            ('chap', 12, "Handy tips and details"),
            ('p', "Throughout the app, accordions keep a single section open at a time, so you "
                  "concentrate on one thing at a time. Saving is always an explicit action (the ✓ in "
                  "the top bar); if you leave a screen with unsaved changes, the app warns you before "
                  "discarding them. And on each main screen, the ? icon offers a short, translated "
                  "explanation of what you can do there. Need a quick introduction? See the Getting "
                  "started guide."),
        ],
        "footer": "Need a quick introduction? See the Getting started guide. · Stock photos provided by Pexels.",
    },
}

# ca/es manual reuse EN structure; translated in render via MANUAL dict.
# For brevity of maintenance, ca and es are provided as full translations below.
