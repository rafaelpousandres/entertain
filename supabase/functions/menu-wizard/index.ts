// Specification 022 — `menu-wizard` Edge Function.
//
// On an event's Menú tab, an AI action that PROPOSES or COMPLETES the whole
// menu from the event's parameters + a few questions. Third consumer of the
// generic Spec 019 quota (after stock_photos, dish_assistant), reusing the
// Spec 020 dish path for any new dishes it invents.
//
// ONE action: `propose` (charges quota). It is READ-ONLY on the DB — it never
// persists. The proposal returns an ordered list of ITEMS, each one of:
//   * catalog_dish  — reference an existing dishes.id from the group catalog.
//   * new_dish      — a full 020-style dish CARD (name i18n, ingredients mapped
//                     to the catalog or flagged new, preparation, a resolved
//                     Pexels photo). Created on accept by reusing the deployed
//                     `dish-assistant` `save` action — so the card shape here
//                     MUST match what that action expects, verbatim.
//   * catalog_drink — reference an existing drinks.id from the group catalog.
//
// Persistence ("accept") is composed CLIENT-side from already-tested code:
// `dish-assistant` save (per new dish) + EventsRepository.addDishToEvent /
// addDrinkToEvent (per item) — so the subtle menu-snapshot + servings-scaling
// logic stays in its single home and is never duplicated here.
//
// In "completa" mode the proposal is ADDITIVE: it sees the current menu and
// proposes only COMPLEMENTARY items, avoiding duplicates/clashes (the "Spotify
// playlist" model — it never silently replaces what's there).
//
// ANTHROPIC_API_KEY + PEXELS_API_KEY are server-only secrets. verify_jwt is on;
// a user-scoped client identifies the caller / authorizes under RLS, a service-
// role client does the quota RPCs + the privileged catalog/menu reads (mirrors
// Spec 019/020). service_role checks table privileges BEFORE RLS, so every
// table this reads has an explicit SELECT grant (see the 022 grants migration).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const QUOTA_KEY = "menu_wizard";
// MUST match the client mirror (kMenuWizardDefaultLimit). Free 2/month;
// premium (15) is an entitlement row, no code change.
const DEFAULT_LIMIT = 2;

// Sonnet 4.6 — same model choice as Spec 020: quality matters for proposing a
// coherent menu and identifying real dishes. Pure generation, no web tools.
const ANTHROPIC_MODEL = "claude-sonnet-4-6";
const ANTHROPIC_API = "https://api.anthropic.com/v1/messages";
const PEXELS_API = "https://api.pexels.com/v1/search";

// Active dish categories (Spec 024): no "drink" — beverages live in their own
// `drinks` entity and are proposed as catalog_drink items, NEVER as a dish with
// category "drink". A stray/unknown category on a new dish falls back to "main".
const ACTIVE_DISH_CATEGORIES = ["aperitif", "starter", "main", "dessert", "other"];

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

/** Calendar month in UTC, e.g. "2026-06" — matches the client + Spec 019. */
function currentPeriod(now: Date = new Date()): string {
  return now.toISOString().slice(0, 7);
}

// ---- caller + group ------------------------------------------------------

async function resolveGroup(
  userClient: ReturnType<typeof createClient>,
): Promise<{ userId: string; groupId: string } | null> {
  const { data: userData } = await userClient.auth.getUser();
  const userId = userData?.user?.id;
  if (!userId) return null;
  const { data: row } = await userClient
    .from("memberships")
    .select("group_id")
    .eq("user_id", userId)
    .limit(1)
    .maybeSingle();
  const groupId = (row as { group_id: string } | null)?.group_id;
  if (!groupId) return null;
  return { userId, groupId };
}

// ---- event + current menu (for "completa") -------------------------------

type EventContext = {
  guestCount: number;
  format: string;
  type: string;
};

/** The event's planning params. Read via the service client (022 grant) and
 * checked against the caller's group — a foreign event_id yields null (403). */
async function loadEvent(
  serviceClient: ReturnType<typeof createClient>,
  eventId: string,
  groupId: string,
): Promise<EventContext | null> {
  const { data, error } = await serviceClient
    .from("events")
    .select("group_id, guest_count, format, type")
    .eq("id", eventId)
    .is("deleted_at", null)
    .maybeSingle();
  if (error) console.error("[menu] event read failed:", error.message);
  const row = data as
    | { group_id: string; guest_count: number; format: string; type: string }
    | null;
  if (!row || row.group_id !== groupId) return null;
  return {
    guestCount: Number(row.guest_count) || 0,
    format: row.format,
    type: row.type,
  };
}

/** The current menu (dish + drink names), so "completa" complements it and
 * avoids duplicates. Empty for a fresh menu ("crea"). */
async function loadCurrentMenu(
  serviceClient: ReturnType<typeof createClient>,
  eventId: string,
): Promise<{ dishes: string[]; drinks: string[] }> {
  const { data: dishRows, error: dishErr } = await serviceClient
    .from("event_dishes")
    .select("dish_name, category")
    .eq("event_id", eventId)
    .eq("is_extras", false);
  if (dishErr) console.error("[menu] event_dishes read failed:", dishErr.message);
  const { data: drinkRows, error: drinkErr } = await serviceClient
    .from("event_drinks")
    .select("drink_name")
    .eq("event_id", eventId);
  if (drinkErr) {
    console.error("[menu] event_drinks read failed:", drinkErr.message);
  }
  const dishes = ((dishRows as Array<{ dish_name: string; category: string }> | null) ?? [])
    .map((d) => `${d.dish_name} [${d.category}]`);
  const drinks = ((drinkRows as Array<{ drink_name: string }> | null) ?? [])
    .map((d) => d.drink_name);
  return { dishes, drinks };
}

// ---- catalogs ------------------------------------------------------------

async function loadDishes(
  client: ReturnType<typeof createClient>,
  groupId: string,
): Promise<Array<{ id: string; name: string; category: string }>> {
  const { data, error } = await client
    .from("dishes")
    .select("id, name, category")
    .eq("group_id", groupId)
    .is("deleted_at", null);
  if (error) console.error("[catalog] dishes read failed:", error.message);
  return (data as Array<{ id: string; name: string; category: string }> | null) ?? [];
}

async function loadDrinks(
  client: ReturnType<typeof createClient>,
  groupId: string,
): Promise<Array<{ id: string; name: string }>> {
  const { data, error } = await client
    .from("drinks")
    .select("id, name")
    .eq("group_id", groupId)
    .is("deleted_at", null);
  if (error) console.error("[catalog] drinks read failed:", error.message);
  return (data as Array<{ id: string; name: string }> | null) ?? [];
}

async function loadIngredients(
  client: ReturnType<typeof createClient>,
  groupId: string,
): Promise<Array<{ id: string; name: string }>> {
  const { data, error } = await client
    .from("ingredients")
    .select("id, name")
    .or(`group_id.eq.${groupId},group_id.is.null`)
    .is("deleted_at", null);
  if (error) console.error("[catalog] ingredients read failed:", error.message);
  return (data as Array<{ id: string; name: string }> | null) ?? [];
}

async function loadUnits(
  client: ReturnType<typeof createClient>,
  locale: string,
): Promise<Array<{ code: string; magnitude: string; name: string }>> {
  const { data: units, error } = await client
    .from("units")
    .select("id, code, magnitude");
  if (error) console.error("[catalog] units read failed:", error.message);
  const rows = (units as Array<{ id: string; code: string; magnitude: string }> | null) ??
    [];
  const { data: names } = await client
    .from("translations")
    .select("entity_id, text")
    .eq("entity_type", "unit")
    .eq("field", "name")
    .eq("locale", locale);
  const nameById = new Map(
    ((names as Array<{ entity_id: string; text: string }> | null) ?? []).map((
      n,
    ) => [n.entity_id, n.text]),
  );
  return rows.map((u) => ({
    code: u.code,
    magnitude: u.magnitude,
    name: nameById.get(u.id) ?? u.code,
  }));
}

async function loadSupplierCategories(
  client: ReturnType<typeof createClient>,
  groupId: string,
  locale: string,
): Promise<Array<{ id: string; name: string }>> {
  const { data: cats, error } = await client
    .from("supplier_categories")
    .select("id, code, name, group_id")
    .or(`group_id.eq.${groupId},group_id.is.null`);
  if (error) {
    console.error("[catalog] supplier_categories read failed:", error.message);
  }
  const rows =
    (cats as Array<
      { id: string; code: string; name: string | null; group_id: string | null }
    > | null) ?? [];
  const { data: names } = await client
    .from("translations")
    .select("entity_id, text")
    .eq("entity_type", "supplier_category")
    .eq("field", "name")
    .eq("locale", locale);
  const nameById = new Map(
    ((names as Array<{ entity_id: string; text: string }> | null) ?? []).map((
      n,
    ) => [n.entity_id, n.text]),
  );
  return rows.map((c) => ({
    id: c.id,
    name: c.name ?? nameById.get(c.id) ?? c.code,
  }));
}

// ---- Claude (pure generation, no tools) ----------------------------------

/** Render the structured question answers as a short briefing for the model. */
function renderAnswers(answers: any, freeText: string): string {
  const a = answers ?? {};
  const parts: string[] = [];
  if (a.meal_type) parts.push(`- Meal type: ${a.meal_type}`);
  if (a.formality) parts.push(`- Formality: ${a.formality}`);
  if (Array.isArray(a.dietary) && a.dietary.length) {
    parts.push(`- Dietary constraints (MUST respect): ${a.dietary.join(", ")}`);
  }
  if (a.feature) parts.push(`- Season / ingredients to feature: ${a.feature}`);
  if (freeText) parts.push(`- Free-text request: ${freeText}`);
  return parts.length ? parts.join("\n") : "(no extra preferences)";
}

function buildProposePrompt(
  locale: string,
  event: EventContext,
  current: { dishes: string[]; drinks: string[] },
  answers: any,
  freeText: string,
  dishes: Array<{ id: string; name: string; category: string }>,
  drinks: Array<{ id: string; name: string }>,
  ingredients: Array<{ id: string; name: string }>,
  units: Array<{ code: string; magnitude: string; name: string }>,
  categories: Array<{ id: string; name: string }>,
): string {
  const dishList = dishes
    .map((d) => `- ${d.id} :: ${d.name} [${d.category}]`)
    .join("\n");
  const drinkList = drinks.map((d) => `- ${d.id} :: ${d.name}`).join("\n");
  const ingList = ingredients.map((i) => `- ${i.id} :: ${i.name}`).join("\n");
  const unitList = units
    .map((u) => `- ${u.code} [${u.magnitude}] ${u.name}`)
    .join("\n");
  const catList = categories.map((c) => `- ${c.id} :: ${c.name}`).join("\n");

  const isComplete = current.dishes.length > 0 || current.drinks.length > 0;
  const currentBlock = isComplete
    ? `MODE: COMPLETE. The menu ALREADY contains the items below. Propose ONLY COMPLEMENTARY items that round it out (e.g. add a starter and a dessert when only a main is present; a drink that pairs). NEVER duplicate or clash with what is already there; do not re-propose any current item.
CURRENT DISHES:
${current.dishes.map((d) => `- ${d}`).join("\n")}
CURRENT DRINKS:
${current.drinks.length ? current.drinks.map((d) => `- ${d}`).join("\n") : "(none)"}`
    : `MODE: CREATE. The menu is empty. Propose a coherent, complete menu (typically a starter or aperitif, a main, a dessert; add a drink if it fits).`;

  return `You are a menu-planning assistant for the Entertain app (home events: lunches/dinners for guests). Propose a menu for one event FROM YOUR OWN KNOWLEDGE — no web access. Keep it realistic and coherent for the number of guests and the format.

EVENT: ${event.guestCount} guests · format=${event.format} (seated/buffet/other) · type=${event.type} (lunch/dinner/other).
User locale: ${locale} (ca = Catalan, es = Spanish, en = English). Write all user-facing text in the user's language; for NEW dishes also provide names in the other two.

USER PREFERENCES:
${renderAnswers(answers, freeText)}

${currentBlock}

You may propose items of three kinds, mixing existing catalog items with brand-new dishes:
1) catalog_dish — reference an EXISTING dish from the catalog by its id. Prefer these when a fitting dish already exists.
2) new_dish — invent a dish NOT in the catalog, as a full card (see rules below).
3) catalog_drink — reference an EXISTING drink from the catalog by its id (optional; only if it genuinely fits).

EXISTING DISH catalog (id :: name [category]):
${dishList || "(empty)"}

EXISTING DRINK catalog (id :: name):
${drinkList || "(empty)"}

For new_dish cards, map ingredients to the group's catalog.
EXISTING ingredient catalog (id :: name):
${ingList || "(empty)"}

UNIT catalog (code [magnitude] localized-name) — use the exact code:
${unitList || "(empty)"}

SUPPLIER CATEGORY catalog (id :: name) — optional hint for new ingredients:
${catList || "(none)"}

Rules for new_dish ingredient lines (identical to the dish assistant):
- If an ingredient is already in the catalog, reference it by existing_id and express the quantity in that ingredient's canonical unit.
- If NOT in the catalog, create it: names in ca/es/en, mark original_locale, a sensible default_unit_code, optionally a supplier_category_id from the list, optionally prep_description.
- prep_note / prep_description is ONLY a SUPPLIER instruction (how the supplier prepares an item you BUY WHOLE — "net", "a daus", "ratllat", "filetejat"). Cooking actions ("a rodanxes", "en juliana", "picat", "sofregit") are recipe steps → put them in "preparation", NEVER in prep_note. If no supplier instruction applies, leave prep_note null.
- name = the BASE ingredient only, with NO preparation word attached.
- preparation: clear CONSECUTIVE NUMBERED STEPS as plain text, e.g. "1. ...\\n2. ...".
- new_dish category is one of: aperitif, starter, main, dessert, other. NEVER "drink" — beverages are catalog_drink items, not dishes. acquisition_mode is "cooked".
- photo_query: a short search term in ENGLISH for an illustrative stock photo (the English dish name, or its main ingredient for a regional dish Pexels won't index by name). NEVER the Catalan/Spanish name.

Respect dietary constraints across the WHOLE proposal. Keep it short: a sensible number of items for the event, not an exhaustive list.

Respond with ONLY a JSON object (no prose, no markdown fences):
{"items":[
  {"type":"catalog_dish","dish_id":"<uuid from the dish catalog>"},
  {"type":"catalog_drink","drink_id":"<uuid from the drink catalog>"},
  {"type":"new_dish","card":{"name":{"ca":"...","es":"...","en":"..."},"original_locale":"ca|es|en","description":"...","category":"main","base_servings":4,"acquisition_mode":"cooked","preparation":"1. ...\\n2. ...","photo_query":"...","ingredients":[{"existing_id":"<uuid>|null","new":{"name":{"ca":"...","es":"...","en":"..."},"original_locale":"ca|es|en","default_unit_code":"g","supplier_category_id":"<uuid>|null","prep_description":"..."|null}|null,"quantity":400,"unit_code":"g","prep_note":"..."|null}]}}
]}`;
}

async function callClaude(
  apiKey: string,
  system: string,
  userText: string,
): Promise<string> {
  const res = await fetch(ANTHROPIC_API, {
    method: "POST",
    headers: {
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: ANTHROPIC_MODEL,
      max_tokens: 8000,
      system,
      messages: [{ role: "user", content: userText }],
    }),
  });
  if (!res.ok) throw new Error(`anthropic_${res.status}: ${await res.text()}`);
  const data = await res.json();
  return (data.content ?? [])
    .filter((b: { type: string }) => b.type === "text")
    .map((b: { text: string }) => b.text)
    .join("");
}

function parseJsonObject(text: string): any {
  let body = text.trim();
  const fence = body.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fence) body = fence[1].trim();
  const start = body.indexOf("{");
  const end = body.lastIndexOf("}");
  if (start === -1 || end === -1) throw new Error("no_json");
  return JSON.parse(body.slice(start, end + 1));
}

// ---- Pexels (resolved at propose; downloaded at save by dish-assistant) ---

/** A chosen illustrative photo for a new dish, resolved here so the review can
 * preview it AND so the card carries `photo` straight into `dish-assistant`
 * save (which downloads `photo.full`). Mirrors the 020 shape exactly. */
async function resolvePexelsPhoto(
  query: string,
): Promise<
  {
    preview: string;
    full: string;
    author: string | null;
    page: string | null;
    ref: string | null;
  } | null
> {
  const pexelsKey = Deno.env.get("PEXELS_API_KEY");
  if (!pexelsKey || !query) return null;
  try {
    const res = await fetch(
      `${PEXELS_API}?query=${encodeURIComponent(query)}&per_page=1`,
      { headers: { Authorization: pexelsKey } },
    );
    if (!res.ok) return null;
    const data = await res.json();
    const photo = (data.photos ?? [])[0];
    if (!photo) return null;
    const full = photo.src?.large2x ?? photo.src?.original ?? photo.src?.large;
    const preview = photo.src?.medium ?? photo.src?.large ?? full;
    if (!full) return null;
    return {
      preview,
      full,
      author: photo.photographer ?? null,
      page: photo.url ?? null,
      ref: photo.id != null ? String(photo.id) : null,
    };
  } catch (_e) {
    return null;
  }
}

/** Enrich a new dish card's ingredient lines with review-only fields (is_new,
 * display_name, unit_label) — exactly as dish-assistant's generate does — so the
 * client DishCard renders the "es crearà" badge and the localized unit without a
 * catalog lookup. The raw mapping (existing_id / new / unit_code) is untouched,
 * so the card still saves cleanly via dish-assistant. */
function enrichCard(
  card: any,
  locale: string,
  nameById: Map<string, string>,
  unitLabel: Map<string, string>,
): void {
  if (!Array.isArray(card?.ingredients)) return;
  for (const line of card.ingredients as any[]) {
    const isNew = !(typeof line.existing_id === "string" &&
      nameById.has(line.existing_id));
    line.is_new = isNew;
    line.display_name = isNew
      ? (line?.new?.name?.[locale] ?? line?.new?.name?.ca ??
        line?.new?.name?.en ?? "")
      : nameById.get(line.existing_id);
    line.unit_label = unitLabel.get(line.unit_code) ?? line.unit_code ?? "";
  }
  // Guard (Spec 024): a new dish must never carry category "drink" — beverages
  // are catalog_drink items. Coerce anything unexpected to "main" (mirrors the
  // dish-assistant save fallback), so the saved dish lands in a real section.
  if (!ACTIVE_DISH_CATEGORIES.includes(card.category)) card.category = "main";
}

// ---- propose (charges quota; returns the menu proposal for review) --------

async function handlePropose(
  body: any,
  userClient: ReturnType<typeof createClient>,
  serviceClient: ReturnType<typeof createClient>,
): Promise<Response> {
  const eventId = (body.event_id ?? "").toString().trim();
  const locale = (body.locale ?? "ca").toString();
  const freeText = (body.free_text ?? "").toString().trim();
  const answers = body.answers ?? {};
  if (!eventId) return json({ error: "event_required" }, 400);

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return json({ error: "not_configured" }, 500);

  const group = await resolveGroup(userClient);
  if (!group) return json({ error: "forbidden" }, 403);
  const groupId = group.groupId;

  // Authorize the event up front (also gives the planning params).
  const event = await loadEvent(serviceClient, eventId, groupId);
  if (!event) return json({ error: "forbidden" }, 403);

  const { data: ent, error: entErr } = await serviceClient
    .from("quota_entitlements")
    .select("monthly_limit")
    .eq("group_id", groupId)
    .eq("quota_key", QUOTA_KEY)
    .maybeSingle();
  // Defense in depth: a failed read here (e.g. a missing service_role grant)
  // would silently fall back to DEFAULT_LIMIT and wrongly cap a premium group.
  if (entErr) {
    console.error("[propose] entitlement read failed:", entErr.message);
  }
  const limit = (ent as { monthly_limit: number } | null)?.monthly_limit ??
    DEFAULT_LIMIT;
  const period = currentPeriod();

  // Charged HERE (the AI proposal is the costly step). NULL ⇒ cap reached.
  const { data: usedAfter, error: rpcErr } = await serviceClient.rpc(
    "consume_quota",
    { p_group_id: groupId, p_quota_key: QUOTA_KEY, p_period: period, p_limit: limit },
  );
  if (rpcErr) {
    console.error("[propose] consume_quota error:", rpcErr.message);
    return json({ error: "quota_error" }, 500);
  }
  if (usedAfter === null || usedAfter === undefined) {
    return json({ error: "limit_reached", used: limit, limit }, 402);
  }

  try {
    const [current, dishes, drinks, ingredients, units, categories] =
      await Promise.all([
        loadCurrentMenu(serviceClient, eventId),
        loadDishes(serviceClient, groupId),
        loadDrinks(serviceClient, groupId),
        loadIngredients(serviceClient, groupId),
        loadUnits(serviceClient, locale),
        loadSupplierCategories(serviceClient, groupId, locale),
      ]);

    const reply = await callClaude(
      apiKey,
      buildProposePrompt(
        locale,
        event,
        current,
        answers,
        freeText,
        dishes,
        drinks,
        ingredients,
        units,
        categories,
      ),
      "Propose the menu.",
    );
    const parsed = parseJsonObject(reply);
    if (!Array.isArray(parsed?.items)) throw new Error("bad_proposal");

    const dishById = new Map(dishes.map((d) => [d.id, d]));
    const drinkById = new Map(drinks.map((d) => [d.id, d]));
    const ingNameById = new Map(ingredients.map((i) => [i.id, i.name]));
    const unitLabel = new Map(units.map((u) => [u.code, u.name]));

    // Normalize + validate each item. Drop hallucinated catalog ids; coerce new
    // dish cards (enrich for review, never category "drink").
    const items: any[] = [];
    for (const raw of parsed.items as any[]) {
      const type = raw?.type;
      if (type === "catalog_dish") {
        const d = dishById.get((raw.dish_id ?? "").toString());
        if (d) {
          items.push({
            type: "catalog_dish",
            dish_id: d.id,
            name: d.name,
            category: d.category,
          });
        }
      } else if (type === "catalog_drink") {
        const d = drinkById.get((raw.drink_id ?? "").toString());
        if (d) items.push({ type: "catalog_drink", drink_id: d.id, name: d.name });
      } else if (type === "new_dish" && raw.card?.name) {
        enrichCard(raw.card, locale, ingNameById, unitLabel);
        items.push({ type: "new_dish", card: raw.card });
      }
    }

    // Resolve a Pexels photo for each new dish (server-side; NOT the stock_photos
    // quota) so the review previews it and `save` can attach it. Parallel.
    await Promise.all(
      items
        .filter((it) => it.type === "new_dish")
        .map(async (it) => {
          it.card.photo = await resolvePexelsPhoto(
            (it.card.photo_query ?? it.card?.name?.en ?? "").toString(),
          );
        }),
    );

    return json({ items, usage: { used: usedAfter, limit } });
  } catch (e) {
    console.error(
      "[propose] failed, releasing quota slot:",
      e instanceof Error ? `${e.message}\n${e.stack}` : String(e),
    );
    await serviceClient.rpc("release_quota", {
      p_group_id: groupId,
      p_quota_key: QUOTA_KEY,
      p_period: period,
    });
    return json({ error: "propose_failed" }, 500);
  }
}

// ---- dispatch ------------------------------------------------------------

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let body: any;
  try {
    body = await req.json();
  } catch (_e) {
    return json({ error: "invalid_json" }, 400);
  }

  // One action: persistence ("accept") is composed client-side from the deployed
  // dish-assistant `save` + EventsRepository.addDishToEvent/addDrinkToEvent.
  if (body.action !== "propose") return json({ error: "unknown_action" }, 400);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const authHeader = req.headers.get("Authorization") ?? "";

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const serviceClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  return handlePropose(body, userClient, serviceClient);
});
