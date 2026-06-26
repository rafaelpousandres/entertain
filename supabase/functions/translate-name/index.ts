// Spec 025 A.2 — `translate-name` Edge Function (un-metered name-i18n helper).
//
// When the user creates/edits an ingredient/dish/drink name, the client saves
// the row (with original_locale = the typed locale) and then fires this helper
// best-effort: it translates the short name into ca/es/en and upserts the three
// `translation` name rows. The client cannot write `translations` (service-role
// only), so this must run server-side. Tiny + free: NOT a metered feature.
//
// ANTHROPIC_API_KEY is a server-only secret. verify_jwt is on; a user-scoped
// client authorizes the entity (RLS — must belong to the caller's group), a
// service-role client writes the translations + ensures original_locale.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ANTHROPIC_MODEL = "claude-sonnet-4-6";
const ANTHROPIC_API = "https://api.anthropic.com/v1/messages";

const ENTITY_TABLES: Record<string, string> = {
  ingredient: "ingredients",
  dish: "dishes",
  drink: "drinks",
};

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

function parseJsonObject(text: string): any {
  let body = text.trim();
  const fence = body.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fence) body = fence[1].trim();
  const start = body.indexOf("{");
  const end = body.lastIndexOf("}");
  if (start === -1 || end === -1) throw new Error("no_json");
  return JSON.parse(body.slice(start, end + 1));
}

/** Match the first-letter CASE of [s] to the reference [ref] (the original
 * name). The model sometimes lowercases a capitalised name ("Aigua tònica" ->
 * "agua tónica"); normalising post-response is more reliable than the prompt
 * alone. Only the first character is touched, so internal proper nouns are
 * preserved. A non-cased first char (digit/symbol) leaves [s] unchanged. */
function matchFirstCase(s: string, ref: string): string {
  if (!s || !ref) return s;
  const r = ref[0];
  const isUpper = r === r.toUpperCase() && r !== r.toLowerCase();
  const isLower = r === r.toLowerCase() && r !== r.toUpperCase();
  if (!isUpper && !isLower) return s;
  const first = isUpper ? s[0].toLocaleUpperCase() : s[0].toLocaleLowerCase();
  return first + s.slice(1);
}

/** Translate a short food name into ca/es/en, keeping the source locale's value
 * as given and matching each translation's first-letter case to the original.
 * Returns {ca,es,en}; throws on failure. */
async function translateName(
  apiKey: string,
  name: string,
  locale: string,
): Promise<{ ca: string; es: string; en: string }> {
  const system =
    `You translate a single short FOOD ITEM name (an ingredient, dish or drink) between Catalan (ca), Spanish (es) and English (en). The given name is in "${locale}". Return the name in all three languages. Keep the "${locale}" value EXACTLY as given (do not re-translate the original). PRESERVE the capitalization STYLE of the source: if it starts with a capital letter, the translations must too (do not lowercase a name). Preserve proper nouns / brand names. Use the common culinary term in each language (e.g. "taronja" -> es "naranja", en "orange"; "bacallà a la llauna" -> en "baked cod"). Respond with ONLY a JSON object, no prose: {"ca":"...","es":"...","en":"..."}`;
  const res = await fetch(ANTHROPIC_API, {
    method: "POST",
    headers: {
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: ANTHROPIC_MODEL,
      max_tokens: 300,
      system,
      messages: [{ role: "user", content: name }],
    }),
  });
  if (!res.ok) throw new Error(`anthropic_${res.status}: ${await res.text()}`);
  const data = await res.json();
  const text = (data.content ?? [])
    .filter((b: { type: string }) => b.type === "text")
    .map((b: { text: string }) => b.text)
    .join("");
  const obj = parseJsonObject(text);
  // Force the source locale to the given name (never let the model alter it),
  // and normalise the other two to the original's first-letter case.
  obj[locale] = name;
  return {
    ca: matchFirstCase(obj.ca ?? name, name),
    es: matchFirstCase(obj.es ?? name, name),
    en: matchFirstCase(obj.en ?? name, name),
  };
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

  const entityType = (body.entity_type ?? "").toString();
  const entityId = (body.entity_id ?? "").toString();
  const name = (body.name ?? "").toString().trim();
  const locale = (body.locale ?? "ca").toString();
  const table = ENTITY_TABLES[entityType];
  if (!table || !entityId || !name || !["ca", "es", "en"].includes(locale)) {
    return json({ error: "bad_request" }, 400);
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return json({ error: "not_configured" }, 500);

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

  // Authorize: the entity must be visible to the caller under RLS (their group).
  const { data: owned } = await userClient
    .from(table)
    .select("id")
    .eq("id", entityId)
    .maybeSingle();
  if (!owned) return json({ error: "forbidden" }, 403);

  try {
    const names = await translateName(apiKey, name, locale);
    const rows = (["ca", "es", "en"] as const)
      .filter((loc) => typeof names[loc] === "string" && names[loc].trim())
      .map((loc) => ({
        entity_type: entityType,
        entity_id: entityId,
        locale: loc,
        field: "name",
        text: names[loc].trim(),
      }));
    const { error: upErr } = await serviceClient
      .from("translations")
      .upsert(rows, { onConflict: "entity_type,entity_id,locale,field" });
    if (upErr) {
      console.error("[translate-name] translations upsert failed:", upErr.message);
      return json({ error: "write_failed" }, 500);
    }
    // Ensure the original-locale marker is set (the client sets it too).
    const { error: olErr } = await serviceClient
      .from(table)
      .update({ original_locale: locale })
      .eq("id", entityId);
    if (olErr) {
      console.error("[translate-name] original_locale update failed:", olErr.message);
    }
    return json({ ok: true, names });
  } catch (e) {
    console.error(
      "[translate-name] failed:",
      e instanceof Error ? `${e.message}\n${e.stack}` : String(e),
    );
    return json({ error: "translate_failed" }, 500);
  }
});
