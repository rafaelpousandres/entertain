# Specification 019 — Stock photos (Pexels) + entitlement/quota infrastructure

> Build assignment for Claude Code.
> Status: ready for implementation (Plan mode strongly recommended).
> Read CLAUDE.md and "entertain - Data model.md" before starting.
> This Spec introduces the project's **first server-side component** (a Supabase
> Edge Function), its **first external API** (Pexels), and its **first
> monetization infrastructure** (a generic per-group monthly quota), with stock
> photos as the first — and currently only — consumer. The quota is built for
> the full vision (reusable by the URL importer later) but implemented minimally.
> One branch, one PR; commit the spec with the code.
> **Setup prerequisites are operator steps (see §0) — the user owns the
> account and the secret.**

---

## 0. Setup prerequisites (operator / owner)

Before the feature works end-to-end, the owner provisions (Claude Code guides,
the user creates — credentials are never in the repo or client):
- A **Pexels API account** + API key (free tier: 200 req/h, 20 000 req/month;
  raisable for free with attribution, which we provide).
- The key stored as a **Supabase secret** (e.g. `PEXELS_API_KEY`), available to
  the Edge Function only — never shipped to the client.
- **Edge Functions** enabled on the Supabase project (free tier includes them).

The three-axis principle holds: this Spec delivers **feature** + **entitlement
(runtime limit, enforced)**; **price** (Billing) is a later, separate piece. The
limit-reached path is the clean seam where a paywall attaches.

**Freemium model (context, "try before you buy").** A single **Premium** tier
(later) raises all per-feature limits at once; there is no per-feature purchase.
Free limits are a genuine taste, sized by the owner's real cost per feature:
low-cost features are generous, AI features (real per-call cost) are tighter.
For **stock photos** (≈ zero marginal cost): **free 10/month → premium
unlimited**. Future AI consumers (own Specs) are planned at: dish assistant
free 3 → premium 50; event wizard free 2 → premium 15. Only `stock_photos`
is in scope here; the AI keys come with their features. All numbers live in
config / `quota_entitlements` and are trivially tunable.

---

## A. Entitlement / quota infrastructure (generic, minimal)

### A.0 Platform-admin role (latent, no UI)

Establish a minimal **platform-admin** concept now so authorization exists
before any admin/Billing UI is built — but **no UI in this Spec**.
- A way to mark a user as a **platform admin** (operator/owner, a role that
  transcends groups): the simplest durable mechanism — e.g. a `platform_admins`
  table keyed by `user_id`, or an `app_metadata.platform_admin` claim. Pick one
  and document it; the table is more queryable from RLS/SQL, the claim is
  simpler at the edge. **Recommendation:** a tiny `platform_admins(user_id)`
  table (RLS: only platform admins may read it; seeded with the owner's id out
  of band).
- This role is **distinct from a future group-admin role** (elevated permissions
  *within* a group — members, group settings). Group-admin is **not** built here;
  just don't model platform-admin in a way that blocks adding group roles later.
- **Use in this Spec:** none in the UI. The Edge Function may optionally accept
  platform-admin to bypass limits for testing, but the durable purpose is to let
  a **later** admin panel / Billing flow write `quota_entitlements` (grant
  premium, tune limits) under a real authorization check instead of manual SQL.
- **Out of scope here:** the admin panel, group roles, and changing limits from
  Settings. Today, limits are the system default (10) + manual rows in
  `quota_entitlements`; the admin UI that edits them is a later Spec.

A reusable per-group monthly quota. `quota_key` namespaces consumers, so the URL
importer can add its own key later without schema change. Stock photos use the
key `stock_photos`.

### A.1 Migration (shown before push)

- **`platform_admins`** — the latent platform-admin role (§A.0), no UI:
  | Field | Type | Notes |
  |---|---|---|
  | user_id | uuid | PK; the platform admin (owner/operator). |
  | created_at | timestamptz | |
  | | | RLS: only a platform admin may SELECT (a row's existence is the check); no client write grant — seeded out of band with the owner's id. |

- **`quota_usage`** — the counter, one row per (group, key, month):
  | Field | Type | Notes |
  |---|---|---|
  | group_id | uuid | FK → groups (cascade). |
  | quota_key | text | e.g. `stock_photos`. |
  | period | text | Calendar month `YYYY-MM` (e.g. `2026-06`). |
  | used | integer | Default 0. |
  | created_at / updated_at | timestamptz | `set_updated_at` trigger. |
  | | | **Unique (group_id, quota_key, period).** |

- **`quota_entitlements`** — per-group limit + tier (override table):
  | Field | Type | Notes |
  |---|---|---|
  | group_id | uuid | FK → groups (cascade). |
  | quota_key | text | |
  | monthly_limit | integer | The cap for this group+key. |
  | tier | text | `free` / `premium` (informational; price attaches later). |
  | | | **Unique (group_id, quota_key).** |

  **Default fallback:** when no entitlement row exists for a (group, key), the
  limit falls back to a **system default** — for `stock_photos`, **10/month**
  (define as a constant in the Edge Function / a small config, easy to tune).
  Premium later = insert/raise a row. No row needed for the free baseline.

- **RLS / integrity (critical for paywall trust):**
  - `quota_usage`: group members may **SELECT** (to show the counter); **no
    client INSERT/UPDATE** — only the Edge Function (service role) writes it.
    This prevents a client from resetting/decrementing its own usage.
  - `quota_entitlements`: group members may **SELECT**; writes only via service
    role (later, the Billing flow). GRANT SELECT to authenticated; no client
    write grant.

### A.2 Counting semantics
- Quota is **per group**, **calendar-month** (`period = YYYY-MM` in the group's
  effective timezone — use UTC month unless trivial to do local; document the
  choice), and **consumed on save** (a successful copy of a stock photo),
  **not** on search.
- Increment is **atomic with the limit check** in the Edge Function (upsert +
  guarded increment, or a transaction) to avoid races at the boundary.

---

## B. Edge Function (first server component)

A Supabase Edge Function (Deno) `stock-photos` with two actions (one function
with a router, or two functions — implementer's call). The Pexels key lives only
here.

### B.1 `search`
- Input: `query` (string), `locale` (e.g. `ca-ES` / `es-ES` / `en-US` from the
  app), pagination, orientation optional.
- Calls the Pexels search API with `PEXELS_API_KEY`. Returns a **normalized**
  list: `{ id, photographer, photographer_url, alt, src: {preview, full} }`.
- **Does not consume quota.** Cache responses ~24h with a normalized query key
  to spare the shared Pexels rate limit.

### B.2 `save`
- Input: the chosen photo (`provider='pexels'`, provider `id`/ref + the chosen
  `src` URL), and the **target entity** (`entity_type` ∈ dish/drink/ingredient/
  event, `entity_id`).
- Steps (atomic where it matters):
  1. Resolve the caller's `group_id` (from auth) and the target entity's group;
     verify membership (defense in depth alongside RLS).
  2. **Check entitlement:** read `monthly_limit` (entitlement row or default
     10) and current `quota_usage.used` for `(group, stock_photos, period)`.
     If `used >= limit` → return **402-style "limit reached"** with the count.
  3. Download the image from Pexels (server-side), upload to the entity's
     existing bucket (`dish-photos` / `drink-photos` / `ingredient-photos` /
     `event-photos`) using the existing path convention.
  4. Insert the **`media`** row with provenance (§C.2).
  5. **Increment** `quota_usage.used` (atomic upsert).
  6. Return the new media reference + the updated usage (`used`/`limit`).
- All third-party access via this proxy (house rule: secrets off the client,
  third-party APIs via server proxy).

---

## C. Stock photo feature + client UI

### C.1 Photo picker integration
The existing photo sheet (currently Camera / Gallery) gains a third option
**"Cerca a Pexels"** (working title — final label in i18n), available wherever
photos are added: **dishes, drinks, ingredients, events**.

- Opens a **stock search screen**: a search field, a results grid, each result
  showing the **photographer credit** ("Photo by X") beneath it (the per-photo
  attribution, satisfied at point of selection), and a header showing the
  **remaining quota** ("Queden N de 10 aquest mes" / live count).
- Tapping a result → calls the Edge Function `save` → on success the image
  becomes the entity's photo (same carousel as camera/gallery photos);
  on **limit reached** → a clear message ("Has fet servir les 10 fotos d'stock
  gratuïtes d'aquest mes") — **this is the paywall seam**, no upsell yet.
- Search locale derives from the app language (ca/es/en → ca-ES/es-ES/en-US).

### C.2 Provenance on `media`
Add nullable provenance columns to **`media`** (only set for stock photos):
`source_provider` (e.g. `pexels`), `source_author` (photographer),
`source_url` (the Pexels photo page), `source_ref` (provider photo id). A
normal camera/gallery photo leaves these null. (Migration: additive nullable
columns; fold into §A.1's migration file.)

### C.3 Attribution surfaces (two-tier, confirmed)
- **App-level:** an **About / credits** surface (alongside logo, version,
  user id) shows **"Photos provided by Pexels"** with a link to pexels.com. If
  no such screen exists yet, add a small one reachable from Settings.
- **Per-photo:** the photographer credit on the stock-search results (C.1).
- Provenance stored on `media` regardless (C.2).

---

## D. i18n, tests, verification

### D.1 i18n (ca/es/en)
Picker option, search screen (field, empty/loading/error states, remaining-quota
label), limit-reached message, attribution strings.

### D.2 Tests
- Entitlement: `used < limit` allows; `used >= limit` blocks; counter increments
  on save only (not search); new `period` resets; quota is per-group.
- Provenance recorded for stock photos; null for camera/gallery.
- (Edge Function logic unit-tested where feasible; client wiring tested with a
  faked function response.)

### D.3 Verification (end-to-end, on device via Internal Testing)
1. Show the migration; **stop for approval**; then `supabase db push`.
2. Operator: create the Pexels key + set the Supabase secret; deploy the Edge
   Function.
3. On the Pixel: add a photo to a dish via "Cerca a Pexels" → search "paella" →
   pick one → it becomes the dish photo; remaining count drops by one.
4. Repeat across drink / ingredient / event.
5. Exhaust the limit (or temporarily set it low) → the limit-reached message
   appears and save is blocked.
6. About screen shows "Photos provided by Pexels"; search results show the
   photographer credit.
7. `flutter analyze` + `flutter test` green.

---

## Flags for the owner

- **First Edge Function + first external API + first quota** — present the plan
  (Plan mode) and **stop before implementing**; flag the Edge Function structure
  and the atomic counter approach.
- **Migration shown before push** (two quota tables + nullable provenance
  columns on `media`).
- **Operator steps** (§0): Pexels account/key, Supabase secret, function deploy
  — the user owns these; Claude Code guides one at a time.
- **Paywall is out of scope** — deliver feature + enforced limit + the
  limit-reached seam; Billing is a later Spec.
- Data model doc (claude.ai) to update after: quota_usage, quota_entitlements,
  media provenance columns. Noted in PR.

Branch: `feat/spec-019-stock-photos-and-quota`.
