// Specification 030 §B — `sweep-staging` Edge Function.
//
// Purges abandoned blobs from the `photo-staging` bucket: photos uploaded while
// CREATING a catalog entity, where the create was cancelled / backed out of /
// killed before save, so they were never promoted to an entity bucket. The
// happy path leaves nothing (a successful save MOVES the blob out of staging),
// so this only collects leftovers.
//
// Invoked on a schedule by pg_cron (see the cron migration) — there is no user
// JWT, so verify_jwt is OFF (config.toml) and the function instead requires the
// service-role key in the Authorization header as a shared secret, so it cannot
// be triggered by arbitrary callers.
//
// Staging layout is `{group_id}/{uuid}.jpg`: the bucket root lists the per-group
// folders, and each folder lists its objects with a `created_at`. Anything older
// than the retention window is removed via the Storage API (service-role).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const STAGING_BUCKET = "photo-staging";
// Retention: blobs older than this are considered abandoned. Wide enough for a
// long editing session; staged blobs of a saved entity are already gone.
const MAX_AGE_MS = 24 * 60 * 60 * 1000;
const PAGE = 1000;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  // Shared-secret gate: only the scheduler (which holds the service key) may run
  // a sweep. Compare against the bearer token in the Authorization header.
  const auth = req.headers.get("Authorization") ?? "";
  if (auth !== `Bearer ${serviceKey}`) {
    return json({ error: "forbidden" }, 403);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const client = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });
  const storage = client.storage.from(STAGING_BUCKET);
  const cutoff = Date.now() - MAX_AGE_MS;

  // 1. List the per-group folders at the bucket root.
  const { data: groups, error: groupErr } = await storage.list("", {
    limit: PAGE,
  });
  if (groupErr) {
    console.error("[sweep] root list failed:", groupErr.message);
    return json({ error: "list_failed" }, 500);
  }

  const stale: string[] = [];
  for (const folder of groups ?? []) {
    // Folders have a null id; skip any stray top-level object.
    if (folder.id !== null) continue;
    const { data: objects, error: objErr } = await storage.list(folder.name, {
      limit: PAGE,
    });
    if (objErr) {
      console.error(`[sweep] list ${folder.name} failed:`, objErr.message);
      continue;
    }
    for (const obj of objects ?? []) {
      const created = obj.created_at ? Date.parse(obj.created_at) : NaN;
      if (Number.isFinite(created) && created < cutoff) {
        stale.push(`${folder.name}/${obj.name}`);
      }
    }
  }

  if (stale.length === 0) return json({ removed: 0 });

  const { error: rmErr } = await storage.remove(stale);
  if (rmErr) {
    console.error("[sweep] remove failed:", rmErr.message);
    return json({ error: "remove_failed", attempted: stale.length }, 500);
  }
  return json({ removed: stale.length });
});
