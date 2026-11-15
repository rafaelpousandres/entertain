// Specification 035 §D — `delete-account` Edge Function.
//
// In-app account deletion (App Review Guideline 5.1.1(v); Google Play's data
// deletion policy). Permanently removes the calling user's account and all the
// data that goes with it. One action, no parameters that select a target: the
// account deleted is ALWAYS the one the caller's JWT identifies — the function
// never accepts a user or group id from the client.
//
// Order of work, chosen so a failure part-way never strands personal data and
// a retry always finishes the job:
//   1. List the account's Storage objects (SQL, service role). Nothing deleted.
//   2. Remove those objects through the Storage API. If this fails we stop:
//      the rows still reference the photos, nothing is orphaned, the user can
//      retry. (Rows first would leave photos nobody references any more.)
//   3. `delete_account_data` — every row, one transaction, children first.
//   4. Delete the auth user.
// Every step is idempotent: on a retry, step 1 lists what is left, step 3
// answers 'nothing', and step 4 still removes the auth user.
//
// Auth: verify_jwt is on (config.toml), so every call carries the caller's JWT
// (anonymous sessions included). A user-scoped client identifies the caller; a
// service-role client does the privileged work.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/** The literal the client must send, so a stray call can never delete. */
export const CONFIRM_TOKEN = "DELETE_MY_ACCOUNT";

/** Storage `remove` takes a list; keep each request comfortably small. */
const REMOVE_CHUNK = 100;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

/** Groups `{bucket, path}` rows into bucket → unique paths. */
export function groupByBucket(
  rows: Array<{ bucket: string; path: string }>,
): Map<string, string[]> {
  const out = new Map<string, Set<string>>();
  for (const r of rows) {
    if (!r?.bucket || !r?.path) continue;
    // Belt and braces: the shared demo assets are never removed, whatever the
    // SQL listed.
    if (r.path.startsWith("demo/")) continue;
    if (!out.has(r.bucket)) out.set(r.bucket, new Set());
    out.get(r.bucket)!.add(r.path);
  }
  return new Map([...out].map(([b, s]) => [b, [...s]]));
}

/** Splits a list into consecutive chunks of at most `size`. */
export function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey) {
    console.error("delete-account: missing Supabase environment");
    return json({ error: "server_misconfigured" }, 500);
  }

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch (_) {
    // An empty or malformed body simply fails the confirmation check below.
  }
  if (body.confirm !== CONFIRM_TOKEN) {
    return json({ error: "confirmation_required" }, 400);
  }

  // Who is calling — from the JWT only.
  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  const userId = userData?.user?.id;
  if (userError || !userId) return json({ error: "unauthorized" }, 401);

  const service = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  // 1. What the account owns in Storage. Nothing is deleted yet.
  const { data: objects, error: listError } = await service.rpc(
    "account_storage_objects",
    { p_user_id: userId },
  );
  if (listError) {
    console.error("delete-account: listing storage objects failed", listError);
    return json({ error: "storage_list_failed" }, 500);
  }

  // 2. Remove the blobs. Stop on the first failure: rows still point at them.
  let filesRemoved = 0;
  const byBucket = groupByBucket(
    (objects ?? []) as Array<{ bucket: string; path: string }>,
  );
  for (const [bucket, paths] of byBucket) {
    for (const part of chunk(paths, REMOVE_CHUNK)) {
      const { error: removeError } = await service.storage
        .from(bucket)
        .remove(part);
      if (removeError) {
        console.error(
          `delete-account: removing ${part.length} object(s) from ${bucket} failed`,
          removeError,
        );
        return json({ error: "storage_remove_failed" }, 500);
      }
      filesRemoved += part.length;
    }
  }

  // 3. Every row, in one transaction.
  const { data: outcome, error: dataError } = await service.rpc(
    "delete_account_data",
    { p_user_id: userId },
  );
  if (dataError) {
    console.error("delete-account: delete_account_data failed", dataError);
    return json({ error: "data_delete_failed" }, 500);
  }

  // 4. The auth identity. One retry: by now the data is gone, so the cheapest
  //    way to avoid a dangling (empty) auth user is to try again before
  //    reporting failure. If it still fails the client retries the whole call,
  //    which is safe (steps 1–3 find nothing left).
  let authError = (await service.auth.admin.deleteUser(userId)).error;
  if (authError) {
    authError = (await service.auth.admin.deleteUser(userId)).error;
  }
  if (authError) {
    console.error("delete-account: deleting the auth user failed", authError);
    return json({ error: "auth_delete_failed" }, 500);
  }

  return json({ deleted: true, outcome, files_removed: filesRemoved });
});
