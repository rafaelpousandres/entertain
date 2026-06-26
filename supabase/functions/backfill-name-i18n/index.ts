// Spec 025 A.3 — `backfill-name-i18n` one-off maintenance Edge Function.
//
// NOT user-facing. Run once by the operator (Rafael) to fill the missing ca/es/en
// name translations for every existing ingredient/dish/drink, marking the
// original. Idempotent: only fills MISSING locales; never overwrites an existing
// translation. No dietary — this touches names only.
//
// Gated by a shared admin secret (env ADMIN_BACKFILL_SECRET, sent as the
// `x-admin-secret` header) so it can't be invoked by ordinary clients. Uses the
// service-role client throughout (admin op). Deploy with --no-verify-jwt.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ANTHROPIC_MODEL = "claude-sonnet-4-6";
const ANTHROPIC_API = "https://api.anthropic.com/v1/messages";
const ENTITY_TABLES: Array<{ type: string; table: string }> = [
  { type: "ingredient", table: "ingredients" },
  { type: "dish", table: "dishes" },
  { type: "drink", table: "drinks" },
];
const LOCALES = ["ca", "es", "en"] as const;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-admin-secret",
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

/** Match the first-letter case of [s] to the original [ref] (see translate-name). */
function matchFirstCase(s: string, ref: string): string {
  if (!s || !ref) return s;
  const r = ref[0];
  const isUpper = r === r.toUpperCase() && r !== r.toLowerCase();
  const isLower = r === r.toLowerCase() && r !== r.toUpperCase();
  if (!isUpper && !isLower) return s;
  const first = isUpper ? s[0].toLocaleUpperCase() : s[0].toLocaleLowerCase();
  return first + s.slice(1);
}

async function translateName(
  apiKey: string,
  name: string,
  locale: string,
): Promise<{ ca: string; es: string; en: string }> {
  const system =
    `You translate a single short FOOD ITEM name (ingredient, dish or drink) between Catalan (ca), Spanish (es) and English (en). The given name is in "${locale}". Keep the "${locale}" value EXACTLY as given; PRESERVE the capitalization style of the source (do not lowercase a capitalised name); preserve proper nouns. Use the common culinary term per language. Respond with ONLY JSON: {"ca":"...","es":"...","en":"..."}`;
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

  const secret = Deno.env.get("ADMIN_BACKFILL_SECRET");
  if (!secret || req.headers.get("x-admin-secret") !== secret) {
    return json({ error: "unauthorized" }, 401);
  }
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return json({ error: "not_configured" }, 500);

  const serviceClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const result: Record<string, number> = {};
  try {
    for (const { type, table } of ENTITY_TABLES) {
      // All live rows (id, name, original_locale).
      const { data: rows, error: rowsErr } = await serviceClient
        .from(table)
        .select("id, name, original_locale")
        .is("deleted_at", null);
      if (rowsErr) throw new Error(`${table}: ${rowsErr.message}`);

      // Existing name translations: id -> set of locales already present.
      const { data: trs } = await serviceClient
        .from("translations")
        .select("entity_id, locale")
        .eq("entity_type", type)
        .eq("field", "name");
      const have = new Map<string, Set<string>>();
      for (const t of (trs as Array<{ entity_id: string; locale: string }> | null) ?? []) {
        (have.get(t.entity_id) ?? have.set(t.entity_id, new Set()).get(t.entity_id)!)
          .add(t.locale);
      }

      let filled = 0;
      for (const r of (rows as Array<{ id: string; name: string; original_locale: string | null }> | null) ?? []) {
        const present = have.get(r.id) ?? new Set<string>();
        const missing = LOCALES.filter((l) => !present.has(l));
        if (missing.length === 0) continue; // idempotent: nothing to do
        const original = ["ca", "es", "en"].includes(r.original_locale ?? "")
          ? (r.original_locale as string)
          : "ca"; // legacy rows assumed Catalan
        const names = await translateName(apiKey, r.name, original);
        const upserts = missing
          .filter((l) => typeof names[l] === "string" && names[l].trim())
          .map((l) => ({
            entity_type: type,
            entity_id: r.id,
            locale: l,
            field: "name",
            text: names[l].trim(),
          }));
        if (upserts.length) {
          const { error: upErr } = await serviceClient
            .from("translations")
            .upsert(upserts, { onConflict: "entity_type,entity_id,locale,field" });
          if (upErr) {
            console.error(`[backfill] ${type} ${r.id} upsert:`, upErr.message);
            continue;
          }
          // Stamp the assumed original on legacy rows that lack it.
          if (!r.original_locale) {
            await serviceClient.from(table).update({ original_locale: original }).eq("id", r.id);
          }
          filled++;
        }
      }
      result[table] = filled;
    }
    return json({ ok: true, filled: result });
  } catch (e) {
    console.error(
      "[backfill] failed:",
      e instanceof Error ? `${e.message}\n${e.stack}` : String(e),
    );
    return json({ error: "backfill_failed", filled: result }, 500);
  }
});
