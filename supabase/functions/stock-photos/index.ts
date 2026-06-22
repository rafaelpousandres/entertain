// Specification 019 — `stock-photos` Edge Function (the project's first server
// component and first external API). One function, two actions routed on
// `body.action`:
//   * search — proxy Pexels search (no quota). The PEXELS_API_KEY lives only
//     here (a Supabase secret), never on the client.
//   * save   — atomically reserve a quota slot, copy the chosen photo into the
//     entity's Storage bucket, insert a `media` row with provenance, and return
//     the updated usage. Quota is charged only for a successful save.
//
// Auth: verify_jwt is on (config.toml), so every call carries the caller's JWT
// (anonymous sessions included). We build a user-scoped client from it to
// identify the caller and to read the target entity *under RLS* (membership is
// then enforced automatically), and a service-role client for the privileged
// quota RPCs + upload + insert.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const QUOTA_KEY = "stock_photos";
// System default when a group has no quota_entitlements row. MUST match the
// client mirror (kStockPhotosDefaultLimit in lib/features/stock_photos/data/quota.dart).
const DEFAULT_LIMIT = 10;

const PEXELS_API = "https://api.pexels.com/v1/search";
const PER_PAGE = 24;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// entity_type → (table for group lookup, Storage bucket). Mirrors the client's
// MediaEntityType mapping.
const ENTITY: Record<string, { table: string; bucket: string }> = {
  event: { table: "events", bucket: "event-photos" },
  dish: { table: "dishes", bucket: "dish-photos" },
  ingredient: { table: "ingredients", bucket: "ingredient-photos" },
  drink: { table: "drinks", bucket: "drink-photos" },
};

// ---- pure helpers (kept small + side-effect free) -----------------------

/** Calendar month in UTC, e.g. "2026-06". */
export function currentPeriod(now: Date = new Date()): string {
  return now.toISOString().slice(0, 7);
}

/** Normalize a raw Pexels photo to the client-facing shape. */
export function normalizePexelsPhoto(p: any) {
  const src = p.src ?? {};
  return {
    id: String(p.id),
    photographer: p.photographer ?? "",
    photographer_url: p.photographer_url ?? "",
    url: p.url ?? "",
    alt: p.alt ?? "",
    src: {
      preview: src.medium ?? src.large ?? src.tiny ?? "",
      full: src.large2x ?? src.original ?? src.large ?? "",
    },
  };
}

export function cacheKey(query: string, locale: string, page: number): string {
  return `${query.trim().toLowerCase()}|${locale}|${page}`;
}

// Best-effort in-memory cache, per function instance, ~24h TTL. Zero infra; it
// spares the shared Pexels rate limit for repeated queries while an instance is
// warm. Not a correctness mechanism — a cold instance simply re-fetches.
const SEARCH_TTL_MS = 24 * 60 * 60 * 1000;
const searchCache = new Map<string, { expires: number; data: unknown }>();

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

// ---- handlers -----------------------------------------------------------

async function handleSearch(body: any): Promise<Response> {
  const query = (body.query ?? "").toString().trim();
  if (!query) return json({ error: "query_required" }, 400);
  const locale = (body.locale ?? "en-US").toString();
  const page = Number.isFinite(body.page) ? Math.max(1, Number(body.page)) : 1;
  const orientation = body.orientation ? `&orientation=${body.orientation}` : "";

  const key = cacheKey(query, locale, page);
  const cached = searchCache.get(key);
  if (cached && cached.expires > Date.now()) {
    return json({ photos: cached.data });
  }

  const pexelsKey = Deno.env.get("PEXELS_API_KEY");
  if (!pexelsKey) return json({ error: "not_configured" }, 500);

  const url =
    `${PEXELS_API}?query=${encodeURIComponent(query)}` +
    `&per_page=${PER_PAGE}&page=${page}&locale=${encodeURIComponent(locale)}${orientation}`;
  const res = await fetch(url, { headers: { Authorization: pexelsKey } });
  if (!res.ok) return json({ error: "provider_error" }, 502);

  const data = await res.json();
  const photos = (data.photos ?? []).map(normalizePexelsPhoto);
  searchCache.set(key, { expires: Date.now() + SEARCH_TTL_MS, data: photos });
  return json({ photos });
}

async function handleSave(
  body: any,
  userClient: ReturnType<typeof createClient>,
  serviceClient: ReturnType<typeof createClient>,
): Promise<Response> {
  const photo = body.photo;
  const entityType = (body.entity_type ?? "").toString();
  const entityId = (body.entity_id ?? "").toString();
  const entity = ENTITY[entityType];
  if (!entity || !entityId || !photo?.src) {
    return json({ error: "bad_request" }, 400);
  }

  // 1. Identify the caller.
  const { data: userData } = await userClient.auth.getUser();
  if (!userData?.user) return json({ error: "unauthenticated" }, 401);

  // 2. Resolve the target entity's group *under RLS* — if the caller can't see
  //    it (not a member / wrong group), the lookup returns null → 403.
  const { data: entityRow } = await userClient
    .from(entity.table)
    .select("group_id")
    .eq("id", entityId)
    .maybeSingle();
  if (!entityRow) return json({ error: "forbidden" }, 403);
  const groupId = (entityRow as { group_id: string }).group_id;

  // 3. Effective limit: entitlement row or the system default.
  const { data: ent } = await serviceClient
    .from("quota_entitlements")
    .select("monthly_limit")
    .eq("group_id", groupId)
    .eq("quota_key", QUOTA_KEY)
    .maybeSingle();
  const limit = (ent as { monthly_limit: number } | null)?.monthly_limit ??
    DEFAULT_LIMIT;
  const period = currentPeriod();

  // 4. Atomic reserve (check + increment fused). NULL ⇒ cap reached.
  const { data: usedAfter, error: rpcErr } = await serviceClient.rpc(
    "consume_quota",
    {
      p_group_id: groupId,
      p_quota_key: QUOTA_KEY,
      p_period: period,
      p_limit: limit,
    },
  );
  if (rpcErr) return json({ error: "quota_error" }, 500);
  if (usedAfter === null || usedAfter === undefined) {
    return json({ error: "limit_reached", used: limit, limit }, 402);
  }

  // 5–7. Download → upload → insert media. Refund the slot on any failure so a
  // failed save consumes no quota.
  try {
    const imgRes = await fetch(photo.src.full ?? photo.src);
    if (!imgRes.ok) throw new Error("download_failed");
    const bytes = new Uint8Array(await imgRes.arrayBuffer());

    const path = `${entityId}/${crypto.randomUUID()}.jpg`;
    const upload = await serviceClient.storage
      .from(entity.bucket)
      .upload(path, bytes, { contentType: "image/jpeg", upsert: true });
    if (upload.error) throw upload.error;

    const { count } = await serviceClient
      .from("media")
      .select("id", { count: "exact", head: true })
      .eq("entity_type", entityType)
      .eq("entity_id", entityId);

    const { data: mediaRow, error: insErr } = await serviceClient
      .from("media")
      .insert({
        entity_type: entityType,
        entity_id: entityId,
        path,
        position: count ?? 0,
        source_provider: "pexels",
        source_author: photo.photographer ?? null,
        source_url: photo.url ?? null,
        source_ref: photo.id != null ? String(photo.id) : null,
      })
      .select("id, entity_type, entity_id, path, position")
      .single();
    if (insErr) throw insErr;

    return json({ media: mediaRow, usage: { used: usedAfter, limit } });
  } catch (e) {
    // Keep this: the genuine error handler. Before this was added the failure
    // was swallowed silently (only Booted/Shutdown in the logs), which is what
    // hid the missing service_role grant on media.
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
  if (action === "search") return handleSearch(body);
  if (action !== "save") return json({ error: "unknown_action" }, 400);

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

  return handleSave(body, userClient, serviceClient);
});
