// Specification 020 (v4) — `dish-assistant` Edge Function, radically simplified.
//
// Earlier versions read recipe URLs (scrape / web_fetch); that hit WallClockTime
// timeouts and anti-bot blocks (e.g. SITE_BLOCKED). Live testing showed Claude
// generates excellent dishes from its own knowledge, instantly, even from vague
// descriptions. So the whole URL/scraping/web machinery is GONE. Two actions:
//   * generate (charges quota): free text (name or description) + locale.
//     consume_quota -> load catalogs -> Claude (Sonnet 4.6, structured JSON, NO web
//     tools) produces a full dish card (multilingual name, numbered-steps
//     preparation, ingredients mapped to the catalog or flagged new, a Pexels
//     photo query) -> resolve the illustrative photo via the 019 Pexels pipeline
//     (server-side; this photo does NOT touch the stock_photos quota) -> return
//     the card FOR REVIEW (not yet persisted) + usage. release_quota on failure.
//   * save (no quota): the reviewed card -> create new ingredients (i18n) + dish
//     (preparation + multilingual name) + dish_ingredients + download/upload the
//     already-chosen photo. Discard simply never calls save -> nothing persisted
//     (quota was already charged at generate, by design — the AI work was done).
//
// ANTHROPIC_API_KEY + PEXELS_API_KEY are server-only secrets. verify_jwt is on;
// a user-scoped client identifies the caller / reads under RLS, a service-role
// client does the quota RPCs + privileged writes (mirrors Spec 019).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const QUOTA_KEY = "dish_assistant";
// MUST match the client mirror (kDishAssistantDefaultLimit). Free 3/month;
// premium (50) is an entitlement row, no code change.
const DEFAULT_LIMIT = 3;

// Sonnet 4.6 — Haiku's dish quality wasn't convincing, so we use the stronger
// model (better identification/accuracy, incl. obscure dishes). Pure generation,
// no web, so cost stays modest. Model ID is the only knob here.
const ANTHROPIC_MODEL = "claude-sonnet-4-6";
const ANTHROPIC_API = "https://api.anthropic.com/v1/messages";
const DISH_BUCKET = "dish-photos";
const PEXELS_API = "https://api.pexels.com/v1/search";

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

// ---- catalogs ------------------------------------------------------------

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

function buildGeneratePrompt(
  locale: string,
  ingredients: Array<{ id: string; name: string }>,
  units: Array<{ code: string; magnitude: string; name: string }>,
  categories: Array<{ id: string; name: string }>,
): string {
  const ingList = ingredients.map((i) => `- ${i.id} :: ${i.name}`).join("\n");
  const unitList = units
    .map((u) => `- ${u.code} [${u.magnitude}] ${u.name}`)
    .join("\n");
  const catList = categories.map((c) => `- ${c.id} :: ${c.name}`).join("\n");
  return `You are a cooking assistant for the Entertain app. The user types a dish NAME or a short DESCRIPTION (e.g. "carbonara", "guisat català de conill amb xocolata", "com el gaspatxo però més espès"). Identify the dish and generate a complete, accurate dish card FROM YOUR OWN KNOWLEDGE — no web access. A vague description should resolve to the real dish it describes (e.g. "like gazpacho but thicker" -> salmorejo).

User locale: ${locale} (ca = Catalan, es = Spanish, en = English). Write in the user's language; also provide the other two.

CONFIDENCE/HONESTY: if you do not reliably know the dish (an obscure regional dish), still generate a reasonable card but say so in the description ("Recepta aproximada; pot variar."). NEVER present an uncertain recipe as verified.

Map ingredients to the group's catalog. EXISTING ingredient catalog (id :: name):
${ingList || "(empty)"}

UNIT catalog (code [magnitude] localized-name) — use the exact code:
${unitList || "(empty)"}

SUPPLIER CATEGORY catalog (id :: name) — optional hint for new ingredients:
${catList || "(none)"}

Rules:
- If an ingredient is already in the catalog, reference it by existing_id and express the quantity in that ingredient's canonical unit.
- If it is NOT in the catalog, create it: names in ca/es/en, mark original_locale, a sensible default_unit_code, optionally a supplier_category_id from the list, and optionally prep_description.
- prep_note / prep_description is ONLY a SUPPLIER instruction: how the supplier should prepare an item you BUY WHOLE — "net", "a daus", "ratllat", "filetejat", "sense pell", "sense espines". It is NOT a cooking step.
  - Cooking actions you perform while cooking — "a rodanxes", "en juliana", "picat", "sofregit", "saltejat", "ratllat al moment", "per a la picada" — are recipe steps: put them in "preparation", NEVER in prep_note (the ingredient is bought whole and cut/cooked by the cook). Examples of the MISTAKE to avoid: ingredient "Ceba" with prep_note "en juliana" (wrong: "en juliana" is a cooking step → preparation); ingredient "Plàtan" with prep_note "a rodanxes" (wrong → preparation).
  - If no genuine supplier instruction applies, leave prep_note null.
- name = the BASE ingredient only, with NO preparation attached. A preparation word must never leak into the name. Example: "Formatge Gruyère ratllat" is wrong → name "Formatge Gruyère" and prep_note "ratllat".
- For a NEW ingredient, PROPOSE its dietary attributes (the user can override): "diet" is one of unknown|none|vegetarian|vegan on a single ORDERED axis — "none" = contains meat/fish (not vegetarian), "vegetarian" = vegetarian but not vegan (dairy/egg/honey), "vegan" = vegan; use "unknown" only if you genuinely can't tell. "gluten_free" is unknown|yes|no — "no" = contains gluten (wheat/barley/rye/spelt), "yes" = naturally gluten-free, "unknown" if unsure. Examples: pernil → diet "none"; formatge → "vegetarian"; tomàquet → "vegan"; farina de blat → gluten_free "no"; arròs → "yes".
- Vague amounts -> a sensible amount; never fail the card over one line.
- name in all three languages with original_locale marked.
- preparation: clear CONSECUTIVE NUMBERED STEPS as plain text, e.g. "1. ...\\n2. ...\\n3. ...".
- category is one of: aperitif, starter, main, dessert, other. (Beverages are NOT dishes — never use a "drink" category; drinks live in their own entity, spec 024.)
- acquisition_mode is "cooked" (these are recipes).
- photo_query: a short search term in ENGLISH for an illustrative stock photo — the English dish name, or its MAIN INGREDIENT for a regional dish Pexels likely won't index by name. Pexels indexes mainly in English, so NEVER use the Catalan/Spanish name. Examples: "bacallà a la llauna" -> "baked cod"; "fideuà" -> "seafood noodles"; "carbonara" -> "carbonara pasta".

Respond with ONLY a JSON object (no prose, no markdown fences):
{"name":{"ca":"...","es":"...","en":"..."},"original_locale":"ca|es|en","description":"...","category":"main","base_servings":4,"acquisition_mode":"cooked","preparation":"1. ...\\n2. ...","photo_query":"...","ingredients":[{"existing_id":"<uuid>|null","new":{"name":{"ca":"...","es":"...","en":"..."},"original_locale":"ca|es|en","default_unit_code":"g","supplier_category_id":"<uuid>|null","prep_description":"..."|null,"diet":"unknown|none|vegetarian|vegan","gluten_free":"unknown|yes|no"}|null,"quantity":400,"unit_code":"g","prep_note":"..."|null}]}`;
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
      max_tokens: 4000,
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

// ---- Pexels (resolved at generate, downloaded at save) -------------------

/** A chosen illustrative photo; resolved at generate so the review card can
 * preview it. The actual download/upload to Storage happens at save. */
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
      // Pexels photo id — mirrors the manual stock-photos path's `source_ref`
      // so the assistant's media row has the same provenance shape.
      ref: photo.id != null ? String(photo.id) : null,
    };
  } catch (_e) {
    return null;
  }
}

// ---- generate (charges quota; returns card for review) -------------------

async function handleGenerate(
  body: any,
  userClient: ReturnType<typeof createClient>,
  serviceClient: ReturnType<typeof createClient>,
): Promise<Response> {
  const text = (body.text ?? "").toString().trim();
  const locale = (body.locale ?? "ca").toString();
  if (!text) return json({ error: "text_required" }, 400);

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return json({ error: "not_configured" }, 500);

  const group = await resolveGroup(userClient);
  if (!group) return json({ error: "forbidden" }, 403);
  const groupId = group.groupId;

  const { data: ent, error: entErr } = await serviceClient
    .from("quota_entitlements")
    .select("monthly_limit")
    .eq("group_id", groupId)
    .eq("quota_key", QUOTA_KEY)
    .maybeSingle();
  // Defense in depth: a failed read here (e.g. a missing service_role grant)
  // would silently fall back to DEFAULT_LIMIT and wrongly cap a higher-tier
  // group. Surface it instead of swallowing it.
  if (entErr) {
    console.error("[generate] entitlement read failed:", entErr.message);
  }
  const limit = (ent as { monthly_limit: number } | null)?.monthly_limit ??
    DEFAULT_LIMIT;
  const period = currentPeriod();

  // Charged HERE (generation is the costly step). NULL ⇒ cap reached.
  const { data: usedAfter, error: rpcErr } = await serviceClient.rpc(
    "consume_quota",
    { p_group_id: groupId, p_quota_key: QUOTA_KEY, p_period: period, p_limit: limit },
  );
  if (rpcErr) {
    console.error("[generate] consume_quota error:", rpcErr.message);
    return json({ error: "quota_error" }, 500);
  }
  if (usedAfter === null || usedAfter === undefined) {
    return json({ error: "limit_reached", used: limit, limit }, 402);
  }

  try {
    const [ingredients, units, categories] = await Promise.all([
      loadIngredients(serviceClient, groupId),
      loadUnits(serviceClient, locale),
      loadSupplierCategories(serviceClient, groupId, locale),
    ]);

    const reply = await callClaude(
      apiKey,
      buildGeneratePrompt(locale, ingredients, units, categories),
      text,
    );
    const card = parseJsonObject(reply);
    if (!card?.name || !Array.isArray(card.ingredients)) {
      throw new Error("bad_card");
    }

    // Enrich each ingredient line with review-only fields (the raw mapping
    // stays for save). Existing -> catalog name; new -> its localized name.
    const nameById = new Map(ingredients.map((i) => [i.id, i.name]));
    const unitLabel = new Map(units.map((u) => [u.code, u.name]));
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

    // Resolve the illustrative photo (server-side Pexels; NOT the stock_photos
    // quota). Stored on the card so the review can preview it; downloaded at save.
    card.photo = await resolvePexelsPhoto(
      (card.photo_query ?? card?.name?.en ?? "").toString(),
    );

    return json({ card, usage: { used: usedAfter, limit } });
  } catch (e) {
    console.error(
      "[generate] failed, releasing quota slot:",
      e instanceof Error ? `${e.message}\n${e.stack}` : String(e),
    );
    await serviceClient.rpc("release_quota", {
      p_group_id: groupId,
      p_quota_key: QUOTA_KEY,
      p_period: period,
    });
    return json({ error: "generate_failed" }, 500);
  }
}

// ---- save (no quota; persists the reviewed card) -------------------------

async function handleSave(
  body: any,
  userClient: ReturnType<typeof createClient>,
  serviceClient: ReturnType<typeof createClient>,
): Promise<Response> {
  const card = body.card;
  if (!card?.name || !Array.isArray(card.ingredients)) {
    return json({ error: "bad_request" }, 400);
  }
  const group = await resolveGroup(userClient);
  if (!group) return json({ error: "forbidden" }, 403);

  try {
    const dishId = await persistDish(userClient, serviceClient, group.groupId, card);
    await attachPhoto(serviceClient, dishId, card.photo);
    return json({ dish_id: dishId });
  } catch (e) {
    // Quota was charged at generate, by design — a save failure isn't refunded
    // (the user can retry save with the same card for free).
    console.error(
      "[save] failed:",
      e instanceof Error ? `${e.message}\n${e.stack}` : String(e),
    );
    return json({ error: "save_failed" }, 500);
  }
}

/**
 * Persist a reviewed dish card: create new ingredients (with i18n), the dish
 * (preparation + multilingual name + original mark), and the lines. Returns the
 * new dish id. Throws on any DB failure.
 */
async function persistDish(
  userClient: ReturnType<typeof createClient>,
  serviceClient: ReturnType<typeof createClient>,
  groupId: string,
  card: any,
): Promise<string> {
  const { data: unitRows, error: unitErr } = await serviceClient
    .from("units")
    .select("id, code");
  if (unitErr) console.error("[save] units read failed:", unitErr.message);
  const unitByCode = new Map(
    ((unitRows as Array<{ id: string; code: string }> | null) ?? []).map((u) => [
      u.code,
      u.id,
    ]),
  );
  const fallbackUnitId = unitByCode.get("unitat") ?? [...unitByCode.values()][0];
  if (!fallbackUnitId) throw new Error("no_units");

  // Authorize any referenced existing ingredient / category ids under RLS.
  const existingIds = card.ingredients
    .map((l: any) => l.existing_id)
    .filter((id: unknown): id is string => typeof id === "string");
  const allowedIngredientIds = new Set<string>();
  if (existingIds.length) {
    const { data } = await userClient
      .from("ingredients")
      .select("id")
      .in("id", existingIds);
    for (const r of (data as Array<{ id: string }> | null) ?? []) {
      allowedIngredientIds.add(r.id);
    }
  }
  const catIds = card.ingredients
    .map((l: any) => l?.new?.supplier_category_id)
    .filter((id: unknown): id is string => typeof id === "string");
  const allowedCatIds = new Set<string>();
  if (catIds.length) {
    const { data } = await userClient
      .from("supplier_categories")
      .select("id")
      .in("id", catIds);
    for (const r of (data as Array<{ id: string }> | null) ?? []) {
      allowedCatIds.add(r.id);
    }
  }

  const localeOf = (o: any): string =>
    ["ca", "es", "en"].includes(o?.original_locale) ? o.original_locale : "ca";
  const nameIn = (names: any, loc: string): string =>
    (names?.[loc] ?? names?.ca ?? names?.es ?? names?.en ?? "").toString();

  // 1. Resolve each line to a concrete ingredient id (creating new ones).
  const lines: Array<{ ingredientId: string; quantity: number; unitId: string; prepNote: string | null }> =
    [];
  for (const line of card.ingredients) {
    let ingredientId: string | null = null;
    if (typeof line.existing_id === "string" && allowedIngredientIds.has(line.existing_id)) {
      ingredientId = line.existing_id;
    } else if (line.new?.name) {
      const loc = localeOf(line.new);
      const unitId = unitByCode.get(line.new.default_unit_code) ?? fallbackUnitId;
      const catId = allowedCatIds.has(line.new.supplier_category_id)
        ? line.new.supplier_category_id
        : null;
      const { data: ingRow, error: ingErr } = await serviceClient
        .from("ingredients")
        .insert({
          group_id: groupId,
          name: nameIn(line.new.name, loc),
          default_unit_id: unitId,
          default_supplier_category_id: catId,
          prep_description: line.new.prep_description ?? null,
          original_locale: loc,
          // Spec 025 B.2: AI dietary PROPOSAL (user-overridable); default unknown.
          diet: ["none", "vegetarian", "vegan"].includes(line.new.diet)
            ? line.new.diet
            : "unknown",
          gluten_free: ["yes", "no"].includes(line.new.gluten_free)
            ? line.new.gluten_free
            : "unknown",
        })
        .select("id")
        .single();
      if (ingErr) throw ingErr;
      ingredientId = (ingRow as { id: string }).id;
      await insertNameTranslations(serviceClient, "ingredient", ingredientId, line.new.name);
    }
    if (!ingredientId) continue; // unresolvable line — skip, don't fail the card
    const lineUnitId = unitByCode.get(line.unit_code) ?? fallbackUnitId;
    const qty = Number(line.quantity);
    lines.push({
      ingredientId,
      quantity: Number.isFinite(qty) && qty > 0 ? qty : 1,
      unitId: lineUnitId,
      prepNote: typeof line.prep_note === "string" ? line.prep_note : null,
    });
  }

  // 2. Create the dish.
  const dishLoc = localeOf(card);
  // Active dish categories (spec 024): no "drink" — beverages live in their own
  // entity. Anything else (incl. a stray "drink") falls back to "main".
  const category = ["aperitif", "starter", "main", "dessert", "other"]
    .includes(card.category)
    ? card.category
    : "main";
  const servings = Number(card.base_servings);
  const { data: dishRow, error: dishErr } = await serviceClient
    .from("dishes")
    .insert({
      group_id: groupId,
      name: nameIn(card.name, dishLoc),
      category,
      base_servings: Number.isFinite(servings) && servings > 0 ? Math.round(servings) : 4,
      acquisition_mode: card.acquisition_mode === "bought" ? "bought" : "cooked",
      description: typeof card.description === "string" ? card.description : null,
      preparation: typeof card.preparation === "string" ? card.preparation : null,
      original_locale: dishLoc,
    })
    .select("id")
    .single();
  if (dishErr) throw dishErr;
  const dishId = (dishRow as { id: string }).id;
  await insertNameTranslations(serviceClient, "dish", dishId, card.name);

  // 3. Lines.
  if (lines.length) {
    const payload = lines.map((l, i) => ({
      dish_id: dishId,
      ingredient_id: l.ingredientId,
      quantity: l.quantity,
      unit_id: l.unitId,
      prep_note: l.prepNote,
      sort_order: i,
    }));
    const { error: linesErr } = await serviceClient
      .from("dish_ingredients")
      .insert(payload);
    if (linesErr) throw linesErr;
  }
  return dishId;
}

async function insertNameTranslations(
  serviceClient: ReturnType<typeof createClient>,
  entityType: "ingredient" | "dish",
  entityId: string,
  names: any,
): Promise<void> {
  const rows = (["ca", "es", "en"] as const)
    .filter((loc) => typeof names?.[loc] === "string" && names[loc].trim())
    .map((loc) => ({
      entity_type: entityType,
      entity_id: entityId,
      locale: loc,
      field: "name",
      text: names[loc].toString().trim(),
    }));
  if (rows.length) await serviceClient.from("translations").insert(rows);
}

/** Download the card's already-chosen Pexels photo and attach it (019 pipeline).
 * Best-effort: a dish without a photo is still a successful save. */
async function attachPhoto(
  serviceClient: ReturnType<typeof createClient>,
  dishId: string,
  photo: any,
): Promise<void> {
  const full = photo?.full;
  if (typeof full !== "string" || !full.startsWith("http")) return;
  try {
    const res = await fetch(full);
    if (!res.ok) {
      console.error("[attachPhoto] download failed:", res.status, full);
      return;
    }
    const bytes = new Uint8Array(await res.arrayBuffer());
    const path = `${dishId}/${crypto.randomUUID()}.jpg`;
    const upload = await serviceClient.storage
      .from(DISH_BUCKET)
      .upload(path, bytes, { contentType: "image/jpeg", upsert: true });
    if (upload.error) {
      console.error("[attachPhoto] storage upload failed:", upload.error.message);
      return;
    }
    // Mirror the manual stock-photos save (019) exactly: position 0 (cover),
    // pexels provenance incl. source_ref, so the auto photo becomes the cover.
    const { error } = await serviceClient.from("media").insert({
      entity_type: "dish",
      entity_id: dishId,
      path,
      position: 0,
      source_provider: "pexels",
      source_author: photo.author ?? null,
      source_url: photo.page ?? null,
      source_ref: photo.ref ?? null,
    });
    // House rule: never swallow a service-role write error — log it loudly so
    // the next gap (a missing grant, a column drift) surfaces in the logs
    // instead of silently leaving the dish with no cover.
    if (error) {
      console.error("[attachPhoto] media insert failed:", error.message);
    }
  } catch (e) {
    console.error(
      "[attachPhoto] unexpected error:",
      e instanceof Error ? `${e.message}\n${e.stack}` : String(e),
    );
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

  const action = body.action;
  if (action !== "generate" && action !== "save") {
    return json({ error: "unknown_action" }, 400);
  }

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

  return action === "generate"
    ? handleGenerate(body, userClient, serviceClient)
    : handleSave(body, userClient, serviceClient);
});
