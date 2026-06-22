// Specification 020 — `dish-assistant` Edge Function. The project's first AI
// consumer, built on the Spec 019 infrastructure (server secret + Edge Function
// + generic quota). Two actions routed on `body.action`:
//   * search — ask Claude (with web search/fetch) to turn a dish name into up to
//     3 viable, structured options. No quota. The catalogs (the group's
//     ingredients, the unit catalog, system supplier categories) are loaded HERE
//     and given to Claude as context so it maps to existing entries instead of
//     duplicating. ANTHROPIC_API_KEY lives only here (a Supabase secret).
//   * save   — atomically reserve a quota slot, then persist the chosen option:
//     create any new ingredients (with ca/es/en names + original mark), create
//     the dish (preparation = recipe, ca/es/en names), link the lines, and
//     attach a photo (hybrid web -> Pexels, via the 019 storage pipeline). Quota
//     is charged only for a fully successful save (refunded on any failure).
//
// Auth & clients mirror Spec 019: verify_jwt is on, a user-scoped client
// identifies the caller and reads under RLS, a service-role client does the
// quota RPCs + privileged writes.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const QUOTA_KEY = "dish_assistant";
// System default when a group has no quota_entitlements row. MUST match the
// client mirror (kDishAssistantDefaultLimit in
// lib/features/ai_dish_assistant/data/dish_assistant.dart). Free 3/month;
// premium (50) is an entitlement row, no code change.
const DEFAULT_LIMIT = 3;

// Sonnet 4.6 — the best speed/intelligence balance for this recipe-mapping task
// at a paid feature's cost profile. Adaptive thinking + the GA web tools.
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

/** The caller's group (their single auto-provisioned membership), under RLS. */
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

// ---- catalogs (search context) -------------------------------------------

/** The group's + system ingredients (id + monolingual name) for mapping. */
async function loadIngredients(
  client: ReturnType<typeof createClient>,
  groupId: string,
): Promise<Array<{ id: string; name: string }>> {
  const { data } = await client
    .from("ingredients")
    .select("id, name")
    .or(`group_id.eq.${groupId},group_id.is.null`)
    .is("deleted_at", null);
  return (data as Array<{ id: string; name: string }> | null) ?? [];
}

/** The unit catalog as `code [magnitude] — localized name`. */
async function loadUnits(
  client: ReturnType<typeof createClient>,
  locale: string,
): Promise<Array<{ code: string; magnitude: string; name: string }>> {
  const { data: units } = await client
    .from("units")
    .select("id, code, magnitude");
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

/** System + group supplier categories (id + localized name) for new ingredients. */
async function loadSupplierCategories(
  client: ReturnType<typeof createClient>,
  groupId: string,
  locale: string,
): Promise<Array<{ id: string; name: string }>> {
  const { data: cats } = await client
    .from("supplier_categories")
    .select("id, code, name, group_id")
    .or(`group_id.eq.${groupId},group_id.is.null`);
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

// ---- Claude --------------------------------------------------------------

function buildSystemPrompt(
  locale: string,
  ingredients: Array<{ id: string; name: string }>,
  units: Array<{ code: string; magnitude: string; name: string }>,
  categories: Array<{ id: string; name: string }>,
): string {
  const ingList = ingredients
    .map((i) => `- ${i.id} :: ${i.name}`)
    .join("\n");
  const unitList = units
    .map((u) => `- ${u.code} [${u.magnitude}] ${u.name}`)
    .join("\n");
  const catList = categories
    .map((c) => `- ${c.id} :: ${c.name}`)
    .join("\n");
  return `You are a cooking assistant for the Entertain app. The user gives a dish name; you research real recipes on the web and return up to 3 viable, cookable options as structured data the app saves directly (no human review). Fewer than 3 is fine; only return options you judge coherent and cookable.

User locale: ${locale} (ca = Catalan, es = Spanish, en = English).

Use web_search to find real recipes, and web_fetch to read a recipe page and extract its lead image (og:image / recipe JSON-LD) as the option's photo source_url. If you can't find a usable image, set photo to null.

Map ingredients to the group's catalog. EXISTING ingredient catalog (id :: name):
${ingList || "(empty)"}

UNIT catalog (code [magnitude] localized-name) — use the exact code:
${unitList || "(empty)"}

SUPPLIER CATEGORY catalog (id :: name) — optional hint for new ingredients:
${catList || "(none)"}

Rules:
- If an ingredient is already in the catalog, reference it by existing_id and estimate a sensible quantity in a catalog unit (e.g. "una sípia mitjana" -> that ingredient's id, ~400, "g").
- If it is NOT in the catalog, create it: provide names in ca/es/en, mark original_locale (the language the source actually uses), a sensible default_unit_code, optionally a supplier_category_id from the list above, and optionally prep_description — but ONLY when the recipe clearly implies a purchase/prep instruction to a supplier ("clean and cut into rings"), NEVER a recipe step, and never invented. If unclear, leave prep_description null.
- Vague quantities ("al gust", "un pessic") -> a small sensible amount; never fail an option over one line.
- The dish name must be given in all three languages (ca/es/en) with original_locale marked.
- preparation is the full recipe (summarized, in the dish's original_locale), plain text, not split into steps.
- category is one of: aperitif, starter, main, dessert, other.
- summary is one short line in the user locale (${locale}) for the option card.

Respond with ONLY a JSON object (no prose, no markdown fences) of this exact shape:
{"options":[{"name":{"ca":"...","es":"...","en":"..."},"original_locale":"ca|es|en","category":"main","base_servings":4,"preparation":"...","summary":"...","photo":{"source_url":"https://...","author":"..."}|null,"ingredients":[{"existing_id":"<uuid>|null","new":{"name":{"ca":"...","es":"...","en":"..."},"original_locale":"ca|es|en","default_unit_code":"g","supplier_category_id":"<uuid>|null","prep_description":"..."|null}|null,"quantity":400,"unit_code":"g","prep_note":"..."|null}]}]}`;
}

/** One agentic call to Claude with web tools; returns its final text. */
async function callClaude(
  apiKey: string,
  system: string,
  userText: string,
): Promise<string> {
  const tools = [
    { type: "web_search_20260209", name: "web_search", max_uses: 6 },
    { type: "web_fetch_20260209", name: "web_fetch", max_uses: 4 },
  ];
  const messages: Array<{ role: string; content: unknown }> = [
    { role: "user", content: userText },
  ];
  // The server runs its own tool loop; pause_turn means it hit the per-turn cap
  // and we resume by re-sending with the assistant turn appended.
  for (let i = 0; i < 4; i++) {
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
        thinking: { type: "adaptive" },
        system,
        tools,
        messages,
      }),
    });
    if (!res.ok) {
      throw new Error(`anthropic_${res.status}: ${await res.text()}`);
    }
    const data = await res.json();
    if (data.stop_reason === "pause_turn") {
      messages.push({ role: "assistant", content: data.content });
      continue;
    }
    const text = (data.content ?? [])
      .filter((b: { type: string }) => b.type === "text")
      .map((b: { text: string }) => b.text)
      .join("");
    return text;
  }
  throw new Error("anthropic_pause_exhausted");
}

/** Extract the JSON object from Claude's text (tolerates stray fences/prose). */
function parseOptions(text: string): { options: unknown[] } {
  let body = text.trim();
  const fence = body.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fence) body = fence[1].trim();
  const start = body.indexOf("{");
  const end = body.lastIndexOf("}");
  if (start === -1 || end === -1) throw new Error("no_json");
  const parsed = JSON.parse(body.slice(start, end + 1));
  return { options: Array.isArray(parsed.options) ? parsed.options : [] };
}

// ---- handlers ------------------------------------------------------------

async function handleSearch(
  body: any,
  userClient: ReturnType<typeof createClient>,
  serviceClient: ReturnType<typeof createClient>,
): Promise<Response> {
  const name = (body.name ?? "").toString().trim();
  const locale = (body.locale ?? "ca").toString();
  if (!name) return json({ error: "name_required" }, 400);

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return json({ error: "not_configured" }, 500);

  const group = await resolveGroup(userClient);
  if (!group) return json({ error: "forbidden" }, 403);

  const [ingredients, units, categories] = await Promise.all([
    loadIngredients(serviceClient, group.groupId),
    loadUnits(serviceClient, locale),
    loadSupplierCategories(serviceClient, group.groupId, locale),
  ]);

  try {
    const text = await callClaude(
      apiKey,
      buildSystemPrompt(locale, ingredients, units, categories),
      name,
    );
    const { options } = parseOptions(text);
    // Enrich each option with resolved ingredient display names so the option
    // card can list "key ingredients" without a client-side catalog lookup.
    const nameById = new Map(ingredients.map((i) => [i.id, i.name]));
    for (const opt of options as any[]) {
      const lines = Array.isArray(opt?.ingredients) ? opt.ingredients : [];
      opt.ingredient_names = lines
        .map((l: any) =>
          (typeof l.existing_id === "string" && nameById.get(l.existing_id)) ||
          l?.new?.name?.[locale] || l?.new?.name?.ca || l?.new?.name?.en || ""
        )
        .filter((n: string) => n);
    }
    return json({ options });
  } catch (e) {
    console.error("[search] failed:", e instanceof Error ? e.message : String(e));
    return json({ error: "assistant_error" }, 502);
  }
}

async function uploadPhoto(
  serviceClient: ReturnType<typeof createClient>,
  dishId: string,
  bytes: Uint8Array,
  provenance: { provider: string; author?: string | null; url?: string | null },
): Promise<void> {
  const path = `${dishId}/${crypto.randomUUID()}.jpg`;
  const upload = await serviceClient.storage
    .from(DISH_BUCKET)
    .upload(path, bytes, { contentType: "image/jpeg", upsert: true });
  if (upload.error) throw upload.error;
  await serviceClient.from("media").insert({
    entity_type: "dish",
    entity_id: dishId,
    path,
    position: 0,
    source_provider: provenance.provider,
    source_author: provenance.author ?? null,
    source_url: provenance.url ?? null,
  });
}

/** Hybrid photo: the option's web image first, else Pexels by English name. */
async function attachPhoto(
  serviceClient: ReturnType<typeof createClient>,
  dishId: string,
  option: any,
): Promise<void> {
  const sourceUrl = option?.photo?.source_url;
  if (typeof sourceUrl === "string" && sourceUrl.startsWith("http")) {
    try {
      const res = await fetch(sourceUrl);
      if (res.ok) {
        const bytes = new Uint8Array(await res.arrayBuffer());
        await uploadPhoto(serviceClient, dishId, bytes, {
          provider: "web",
          author: option?.photo?.author ?? null,
          url: sourceUrl,
        });
        return;
      }
    } catch (_e) {
      // fall through to Pexels
    }
  }
  const pexelsKey = Deno.env.get("PEXELS_API_KEY");
  const query = option?.name?.en ?? option?.name?.ca ?? "";
  if (!pexelsKey || !query) return;
  try {
    const res = await fetch(
      `${PEXELS_API}?query=${encodeURIComponent(query)}&per_page=1`,
      { headers: { Authorization: pexelsKey } },
    );
    if (!res.ok) return;
    const data = await res.json();
    const photo = (data.photos ?? [])[0];
    const full = photo?.src?.large2x ?? photo?.src?.original ?? photo?.src?.large;
    if (!full) return;
    const img = await fetch(full);
    if (!img.ok) return;
    const bytes = new Uint8Array(await img.arrayBuffer());
    await uploadPhoto(serviceClient, dishId, bytes, {
      provider: "pexels",
      author: photo?.photographer ?? null,
      url: photo?.url ?? null,
    });
  } catch (_e) {
    // photo is best-effort; a dish without one is still a successful save
  }
}

async function handleSave(
  body: any,
  userClient: ReturnType<typeof createClient>,
  serviceClient: ReturnType<typeof createClient>,
): Promise<Response> {
  const option = body.option;
  if (!option?.name || !Array.isArray(option.ingredients)) {
    return json({ error: "bad_request" }, 400);
  }

  const group = await resolveGroup(userClient);
  if (!group) return json({ error: "forbidden" }, 403);
  const groupId = group.groupId;

  // Effective limit: entitlement row or the system default.
  const { data: ent } = await serviceClient
    .from("quota_entitlements")
    .select("monthly_limit")
    .eq("group_id", groupId)
    .eq("quota_key", QUOTA_KEY)
    .maybeSingle();
  const limit = (ent as { monthly_limit: number } | null)?.monthly_limit ??
    DEFAULT_LIMIT;
  const period = currentPeriod();

  // Atomic reserve (Spec 019 RPC). NULL ⇒ cap reached.
  const { data: usedAfter, error: rpcErr } = await serviceClient.rpc(
    "consume_quota",
    { p_group_id: groupId, p_quota_key: QUOTA_KEY, p_period: period, p_limit: limit },
  );
  if (rpcErr) {
    console.error("[save] consume_quota error:", rpcErr.message);
    return json({ error: "quota_error" }, 500);
  }
  if (usedAfter === null || usedAfter === undefined) {
    return json({ error: "limit_reached", used: limit, limit }, 402);
  }

  try {
    // Resolve catalogs we need to validate against / map codes.
    const { data: unitRows } = await serviceClient.from("units").select("id, code");
    const unitByCode = new Map(
      ((unitRows as Array<{ id: string; code: string }> | null) ?? []).map((
        u,
      ) => [u.code, u.id]),
    );
    const fallbackUnitId = unitByCode.get("unitat") ??
      [...unitByCode.values()][0];
    if (!fallbackUnitId) throw new Error("no_units");

    // Authorize any referenced existing ingredient / category ids under RLS.
    const existingIds = option.ingredients
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
    const catIds = option.ingredients
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
    const lines: Array<{ ingredientId: string; quantity: number; unitId: string; prepNote: string | null }> = [];
    for (const line of option.ingredients) {
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
          })
          .select("id")
          .single();
        if (ingErr) throw ingErr;
        ingredientId = (ingRow as { id: string }).id;
        await insertNameTranslations(serviceClient, "ingredient", ingredientId, line.new.name);
      }
      if (!ingredientId) continue; // unresolvable line — skip, don't fail the import
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
    const dishLoc = localeOf(option);
    const category = ["aperitif", "starter", "main", "dessert", "other"]
      .includes(option.category)
      ? option.category
      : "main";
    const servings = Number(option.base_servings);
    const { data: dishRow, error: dishErr } = await serviceClient
      .from("dishes")
      .insert({
        group_id: groupId,
        name: nameIn(option.name, dishLoc),
        category,
        base_servings: Number.isFinite(servings) && servings > 0 ? Math.round(servings) : 4,
        acquisition_mode: "cooked",
        preparation: typeof option.preparation === "string" ? option.preparation : null,
        original_locale: dishLoc,
      })
      .select("id")
      .single();
    if (dishErr) throw dishErr;
    const dishId = (dishRow as { id: string }).id;
    await insertNameTranslations(serviceClient, "dish", dishId, option.name);

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

    // 4. Photo (best-effort; never fails the save).
    await attachPhoto(serviceClient, dishId, option);

    return json({ dish_id: dishId, usage: { used: usedAfter, limit } });
  } catch (e) {
    console.error(
      "[save] failed, releasing quota slot:",
      e instanceof Error ? `${e.message}\n${e.stack}` : String(e),
    );
    await serviceClient.rpc("release_quota", {
      p_group_id: groupId,
      p_quota_key: QUOTA_KEY,
      p_period: period,
    });
    return json({ error: "save_failed" }, 500);
  }
}

/** Insert ca/es/en name rows for a catalog entity (only the present locales). */
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
  if (action !== "search" && action !== "save") {
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

  return action === "search"
    ? handleSearch(body, userClient, serviceClient)
    : handleSave(body, userClient, serviceClient);
});
