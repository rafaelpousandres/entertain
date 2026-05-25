# Specification 002 — Data backend

> Build assignment for Claude Code.
> Status: ready for implementation.
> Read `CLAUDE.md` and `entertain - Data model.md` before starting. This
> specification is the only scope for this assignment; do not pull work forward
> from later phases.

---

## 1. Goal

Stand up the data backend for entertain: create the Phase 0 database schema on
Supabase as versioned migrations, apply row-level security, and connect the
Flutter app to Supabase. The deliverable is an app that initialises and talks to
the backend — though it does not yet display real data on any screen.

---

## 2. Scope — what to do

### 2.1 Database schema — Phase 0 tables only
- Implement the **Phase 0 subset** of the data model (see the "Phased
  activation" table in `entertain - Data model.md`): groups, profiles,
  memberships, events, units, ingredients, dishes, dish_ingredients,
  event_dishes, event_dish_ingredients, supplier_categories, orders,
  order_items, translations, message_templates, and the structure of media.
- Do **not** create the tables belonging to later phases (persons, suppliers,
  pantry_items, costs, tasks, recipes, etc.). The schema is designed for the
  full vision, but this assignment activates only the Phase 0 subset.
- Follow the data model exactly: English `snake_case` identifiers, `uuid`
  primary keys with `gen_random_uuid()`, the standard `created_at` /
  `updated_at` fields with the `updated_at` trigger, soft-delete `deleted_at`
  where the model marks it, enum types as specified, and all foreign keys
  indexed.
- If anything in the data model is ambiguous or seems inconsistent when
  expressed as SQL, stop and flag it rather than improvising a structural
  decision.

### 2.2 Versioned migrations
- The schema is created as **migration files** committed to the repository
  (SQL), applied to the Supabase project. The schema must be reproducible from
  the repository, not hand-created in the dashboard.
- Establish the migration workflow/tooling so future schema changes follow the
  same versioned approach.

### 2.3 Row-level security
- Apply RLS to every table with user data, following the single principle in
  the data model: a row is accessible if the user is a member of its group
  (directly via `group_id`, or derivable via foreign key).
- System content (units, supplier_categories and ingredients with null
  `group_id`, translations, the system message template) is readable by any
  authenticated user and writable only by the service role.
- On first use, an anonymous user must get a `group` and a `membership` created
  automatically, so the RLS policies work from day one.

### 2.4 Connect the Flutter app to Supabase
- Initialise the Supabase client in the app (the dependency was already added
  in Specification 001 but not initialised).
- The Supabase URL and anon key are read from the environment-file mechanism
  established in Specification 001 — **never hardcoded, never committed**. See
  §3 on secrets.
- The app must initialise the Supabase connection on startup without errors. A
  minimal, temporary connectivity check is acceptable to prove the connection
  works (e.g. an anonymous sign-in succeeding), but no real feature screens.

### 2.5 Seed system content
- Provide the Phase 0 system content as part of the migrations or a seed step:
  the unit catalog, the base supplier categories, and the system message
  template, with their ca/es/en translations via the `translations` table.
- An initial catalog of common ingredients may be seeded if straightforward;
  if not, it can be deferred — flag the decision.

---

## 3. Secrets and credentials — important

- The Supabase URL and keys are **credentials**. They must never be written
  into the code or committed to the repository, per `CLAUDE.md`.
- The project owner (the user) will retrieve the Supabase URL and anon key from
  the Supabase dashboard and place them in the local environment file. Claude
  Code must **not** ask the user to paste credentials into the chat or into any
  committed file.
- Claude Code's responsibility is to ensure the mechanism works: the app reads
  these values from the environment file, the `.gitignore` keeps that file out
  of the repository, and a committed example template documents which keys are
  expected (without real values).
- The `service_role` key must never be used in the client app under any
  circumstances — only the anon key belongs in the app.

---

## 4. Out of scope

Explicitly **not** part of this assignment:
- Tables belonging to phases later than Phase 0.
- Any real MVP feature screen (events, dishes, ingredients, shopping list,
  settings) — connecting the backend is in scope; building screens on top of it
  is not.
- Real authentication UI — anonymous initialisation is enough here.
- CI configuration, maps, media upload, the app icon.

---

## 5. Acceptance criteria

The assignment is complete when the user can verify all of the following:

1. The Phase 0 schema exists on the Supabase project, created from versioned
   migration files in the repository.
2. The migrations are reproducible: applying them to a clean database recreates
   the full Phase 0 schema.
3. RLS is enabled on all user-data tables; a quick check confirms a user cannot
   read another group's rows.
4. The app builds and launches (on the Android device) and initialises the
   Supabase connection with no errors.
5. The temporary connectivity check succeeds (e.g. anonymous sign-in works and
   the auto-created group/membership appears).
6. `git status` / `.gitignore` confirm no credential or environment file with
   real values is tracked; only the example template is committed.
7. The work is on a feature branch with a pull request, leaving `main`
   shippable, per `CLAUDE.md`.

---

## 6. Notes for the implementer

- Coordinate the credential step clearly: tell the user exactly which values to
  copy from the Supabase dashboard and into which local file, but never have
  them paste secrets into the chat or a committed file.
- Keep the scope to Phase 0. The data model is the source of truth for
  structure; this assignment realises a subset of it, faithfully.
- If a structural detail of the data model does not translate cleanly to SQL,
  stop and flag it for a decision on claude.ai rather than improvising.
