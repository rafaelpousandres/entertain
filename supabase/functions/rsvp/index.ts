// Spec 029 — `rsvp` Edge Function: Entertain's first PUBLIC web surface.
//
// Serves a tiny localized HTML page where an invited guest confirms/declines and
// optionally reports dietary restrictions (C2). The invitation link embeds an
// unguessable per-guest token; this function reads/writes ONLY the event_guests
// row matched by that token (never a list, never another key), via the
// service-role client. The public never receives a Supabase key.
//
// verify_jwt = false (config.toml) — it must work logged-out. The token IS the
// capability, so there is no other auth. event_guests has the SELECT+UPDATE
// service_role grant from 20260702000000; events already has SELECT.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  checked,
  isExpired,
  pickLang,
  renderExpired,
  renderNotFound,
  renderPage,
} from "./lib.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

// Encode the body to UTF-8 bytes and declare charset=utf-8 so the accents are
// correct end-to-end. NOTE: on the default *.supabase.co/functions/v1 domain the
// platform rewrites text/html GET responses to text/plain (+ nosniff) for
// anti-phishing, so a browser shows raw HTML there regardless of this header —
// rendering the page needs a custom domain (Supabase Pro add-on). See spec 029.
const ENCODER = new TextEncoder();
function html(body: string, status = 200): Response {
  return new Response(ENCODER.encode(body), {
    status,
    headers: { ...CORS, "Content-Type": "text/html; charset=utf-8" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const url = new URL(req.url);
  const lang = pickLang(url.searchParams.get("lang"));

  if (req.method !== "GET" && req.method !== "POST") {
    return html(renderNotFound(lang), 405);
  }

  // The token comes from the query (GET) or the form (POST). The answer +
  // checkbox values only matter on POST.
  let token = (url.searchParams.get("token") ?? "").trim();
  let choice: string | null = null;
  let diet = { vegetarian: false, vegan: false, glutenFree: false };
  if (req.method === "POST") {
    const form = await req.formData();
    token = (form.get("token")?.toString() ?? token).trim();
    choice = form.get("choice")?.toString() ?? null;
    diet = {
      vegetarian: checked(form.get("diet_vegetarian")),
      vegan: checked(form.get("diet_vegan")),
      glutenFree: checked(form.get("diet_gluten_free")),
    };
  }

  if (!token) return html(renderNotFound(lang), 404);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const db = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  // 1) Resolve the single guest row by token — nothing else can be reached.
  const { data: guest, error: gErr } = await db
    .from("event_guests")
    .select(
      "name, state, diet_vegetarian, diet_vegan, diet_gluten_free, event_id",
    )
    .eq("rsvp_token", token)
    .maybeSingle();
  if (gErr) {
    console.error("[rsvp] guest lookup failed:", gErr.message);
    return html(renderNotFound(lang), 500);
  }
  if (!guest) return html(renderNotFound(lang), 404); // unknown/deleted → neutral

  // 2) Its event (by the guest's own event_id) — title + date only.
  const { data: event, error: eErr } = await db
    .from("events")
    .select("title, event_date")
    .eq("id", guest.event_id)
    .maybeSingle();
  if (eErr) {
    console.error("[rsvp] event lookup failed:", eErr.message);
    return html(renderNotFound(lang), 500);
  }
  if (!event) return html(renderNotFound(lang), 404);

  const expired = isExpired(event.event_date as string | null, new Date());

  if (req.method === "POST") {
    if (expired) return html(renderExpired(lang), 410);
    if (choice !== "confirm" && choice !== "decline") {
      return html(renderNotFound(lang), 400);
    }
    const newState = choice === "confirm" ? "confirmat" : "excusat";
    const { error: upErr } = await db
      .from("event_guests")
      .update({
        state: newState,
        diet_vegetarian: diet.vegetarian,
        diet_vegan: diet.vegan,
        diet_gluten_free: diet.glutenFree,
      })
      .eq("rsvp_token", token); // same isolation — only the token's row
    if (upErr) {
      console.error("[rsvp] state update failed:", upErr.message);
      return html(renderNotFound(lang), 500);
    }
    return html(
      renderPage({
        lang,
        token,
        name: guest.name as string,
        title: event.title as string,
        state: newState,
        diet,
        saved: choice,
      }),
    );
  }

  // GET
  if (expired) return html(renderExpired(lang), 200);
  return html(
    renderPage({
      lang,
      token,
      name: guest.name as string,
      title: event.title as string,
      state: guest.state as string,
      diet: {
        vegetarian: guest.diet_vegetarian as boolean,
        vegan: guest.diet_vegan as boolean,
        glutenFree: guest.diet_gluten_free as boolean,
      },
      saved: null,
    }),
  );
});
