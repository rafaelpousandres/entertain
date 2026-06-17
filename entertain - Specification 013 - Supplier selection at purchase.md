# Specification 013 — Supplier selection at purchase

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read CLAUDE.md, the Data model, "entertain - Decisions de disseny.md"
> (once committed), and the shopping-related prior specs before starting.
> This Spec activates supplier infrastructure that already exists in the
> model but is currently dormant. It is the foundation for Spec 014
> (prepared dishes + drinks), which will reuse this supplier-selection
> mechanism.

---

## 1. Goal and context

The data model already supports **multiple suppliers per category**: the
`group_supplier_settings` table holds one row per configured supplier
(name + contact channel), keyed by `supplier_category_id`, and several
categories already have two suppliers (e.g. two butchers, two
fishmongers). However:

- The purchase/order flow currently reasons by **category**, not by a
  concrete supplier. `orders.supplier_id` exists but is **always null** —
  the model anticipated concrete suppliers but the flow never used them.
- There is no notion of a **default supplier** per category, so when a
  category has more than one supplier the system has no basis to pick one.
- Some `group_supplier_settings` rows have `supplier_name = null` (leftover
  / half-configured) and should be cleaned up.

This Spec makes the purchase flow **supplier-aware**: each category can have
a default supplier; when an order is generated the user can confirm or
change which supplier it goes to; the chosen supplier is recorded on the
order and the generated message is addressed to that supplier's name and
channel.

**Terminology**: a "supplier" is a row in `group_supplier_settings` (a
concrete shop with a name and a contact channel, belonging to a category). A
"category" is a row in `supplier_categories` (butcher, fishmonger, …).

No change to how ingredients reference suppliers: ingredients keep pointing
to a **category** (`default_supplier_category_id`). The concrete supplier is
resolved **at order time**, not stored per ingredient. (Per-ingredient
preferred supplier is explicitly out of scope — see §3.)

---

## 2. Scope

### 2.1 Default supplier per category (model)

Introduce a way to mark, per category, which supplier is the default. Two
candidate models — Claude Code picks the cleaner one given the existing
schema and flags the choice:

- **Option (a)**: a nullable FK `default_supplier_settings_id` on
  `supplier_categories` pointing to `group_supplier_settings`. Structurally
  enforces a single default per category. Preferred.
- **Option (b)**: a boolean `is_default` on `group_supplier_settings`, with
  app-level enforcement of at most one default per category.

Migration required (one new column). Whichever model is chosen, the rule is:
**at most one default supplier per category**; the default may be null if no
supplier is configured.

### 2.2 Suppliers settings UI (manage N per category + default)

The Settings ▸ Suppliers area must let the user, per category:

- See the list of suppliers configured for that category (there may be 0, 1,
  or many).
- Add a new supplier (name + channel + contact address).
- Edit / delete an existing supplier.
- Mark one supplier as the **default** for that category.

If the current UI assumes one supplier per category, generalise it to a list
per category. If it already lists multiple, just add the "set as default"
affordance. Flag what the current state is before changing it.

### 2.3 Supplier selection when generating an order

In the event's Shopping tab, when generating an order for a category
(the existing "send message" / order action):

- If the category has **one** supplier → use it, no prompt.
- If the category has **more than one** supplier → present a selector with
  the **default preselected**; the user can change it for this order.
- If the category has **no** supplier configured → behave as today
  (no supplier; the message/clipboard still works), but consider prompting
  the user to configure one. Do not block the order.

The selected supplier is used for this order only; it does not change the
category default.

### 2.4 Record the supplier on the order + address the message

- When an order is generated/sent, fill `orders.supplier_id` with the chosen
  supplier (currently always null). Keep `orders.supplier_category_id` as is.
- The generated supplier message uses the **chosen supplier's** name and
  contact channel (e.g. open WhatsApp to that supplier's number/address),
  not a generic category-level value. Greeting and signature behaviour
  (Spec 011/012) unchanged.

### 2.5 Cleanup of half-configured suppliers

Some `group_supplier_settings` rows have `supplier_name = null`. As a
**manual SQL step documented in the PR** (not app code, owner runs it):
identify and review these rows, then delete or fix them. Provide the SELECT
to review and a guarded DELETE. Do not auto-delete from app code.

---

## 3. Out of scope

- **Per-ingredient preferred supplier** (Nivell 2): ingredients keep
  pointing to a category; the concrete supplier is resolved at order time.
  Not now.
- **Mandatory supplier everywhere** (Nivell 3): categories without a
  supplier still work.
- Prepared dishes and drinks (Spec 014) — but this Spec must leave the
  supplier-selection mechanism reusable by them.
- No change to ingredient → category references.

---

## 4. Acceptance criteria

1. Migration adds the default-supplier mechanism (one new column); applies
   cleanly to remote after owner's visual check (destructive-migration rule
   does not apply — additive only).
2. Settings ▸ Suppliers lets the user manage multiple suppliers per category
   (add/edit/delete) and mark one as default.
3. Generating an order for a category with one supplier uses it silently;
   with several, shows a selector with the default preselected and lets the
   user change it for that order; with none, still works.
4. `orders.supplier_id` is populated with the chosen supplier on order
   generation/send.
5. The supplier message is addressed to the chosen supplier's name and
   channel.
6. Null-name supplier rows reviewed and cleaned via the documented SQL
   (owner runs it).
7. flutter analyze clean; flutter test passes; new tests for the
   supplier-resolution logic (one supplier → auto; many → default; none →
   no supplier) and for order.supplier_id population.

---

## 5. Notes for the implementer

- **Explore first**: confirm the current order-generation flow (where the
  message is composed, how the category's contact is currently resolved) and
  the current Settings ▸ Suppliers UI (1 vs N per category) before changing
  anything. Report findings in the plan.
- The mechanism built here (resolve category → suppliers → default →
  per-order override → record supplier_id) must be **reusable** by Spec 014
  for prepared dishes and drinks, which are categories with multiple
  suppliers just like butcher/fishmonger. Keep the supplier-resolution logic
  in a shared place, not inlined in the shopping panel.
- Migration is additive (one column), so the destructive-migration stop does
  not apply; still show the migration file before pushing per house rule.
- i18n: any new strings (e.g. "Default supplier", "Choose supplier",
  "Add supplier") in ca/es/en.

Branch: `feat/spec-013-supplier-selection`.

Stop and ask the owner if:
- The current Settings ▸ Suppliers UI is structured in a way that makes
  "multiple per category + default" a larger change than expected.
- The order-generation flow turns out to already resolve a concrete supplier
  somewhere (so supplier_id null is a partial implementation, not absent).
