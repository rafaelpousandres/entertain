# Entertain

Mobile app to organize domestic events (lunches and dinners): menus, dishes,
ingredients, and per-supplier shopping lists. Single product, this repository
is exclusive to the app. See `CLAUDE.md` for the operational rules and the
reference documents (data model, design system, development plan,
specifications).

## Stack

- Flutter (Dart), Android first (iOS is a later phase).
- Supabase (EU region) — Phase 0 schema lives in `supabase/migrations/`.
- Riverpod for state, `go_router` for navigation, `intl` + ARB files for i18n
  (Catalan, Spanish, English), Material 3 with the project's design system.

## Setup

1. Install Flutter (stable channel). The standard manual install on Linux /
   WSL2 puts the SDK at `~/development/flutter`; add `~/development/flutter/bin`
   to `PATH`.
2. From the repo root:
   ```bash
   flutter pub get
   ```
3. Provide a local environment file (see [Environment](#environment) below).
4. Apply the database migrations to your Supabase project (see [Database](#database)).
5. Run on a connected Android device or emulator:
   ```bash
   flutter run --dart-define-from-file="$HOME/.config/entertain/local.json"
   ```

## Environment

Configuration values that carry secrets (Supabase URL, anon key, future
third-party credentials) are **never** committed. They live in a JSON file
outside source control and are injected at compile time via Flutter's built-in
`--dart-define-from-file=<path>` flag — no extra package required. The Dart
side reads them through `lib/config/env.dart`.

Recommended location: outside the repository, e.g.
`~/.config/entertain/local.json`. The committed template
`env/local.example.json` documents the expected keys.

If you prefer keeping the file alongside the repo, place it at
`env/local.json` — that path is `.gitignore`d. Either way the file must never
be tracked.

### What to put in `local.json`

From the **Supabase dashboard** → **Project Settings → API**, copy:

- `Project URL` → set as `SUPABASE_URL`
- `anon public` key → set as `SUPABASE_ANON_KEY`

The file is plain JSON:

```json
{
  "SUPABASE_URL": "https://<your-project-ref>.supabase.co",
  "SUPABASE_ANON_KEY": "eyJ…"
}
```

> ⚠️ **Never** put the `service_role` key in this file. The service role
> bypasses RLS and must only live on the server (Edge Functions, CI). The app
> uses the anon key exclusively.

Build / run examples:

```bash
flutter run        --dart-define-from-file="$HOME/.config/entertain/local.json"
flutter build apk --release \
                   --dart-define-from-file="$HOME/.config/entertain/local.json"
```

Production secrets used by CI live in the CI secret store (later
specification), not in this repository.

## Database

The Phase 0 schema (per `entertain - Data model.md`) is stored as versioned
SQL migrations under `supabase/migrations/`. They are the source of truth;
the dashboard schema is rebuilt from them, not the other way around.

### One-time setup

1. **Install the Supabase CLI** (any method works; `brew install supabase/tap/supabase`
   on macOS, the prebuilt binary on Linux from
   <https://github.com/supabase/cli/releases>).
2. **Log in** with your Supabase account:
   ```bash
   supabase login
   ```
3. **Link this repo to the remote project** (the project ref is the
   subdomain in `https://<ref>.supabase.co` — treated as a credential, kept
   out of the repo):
   ```bash
   supabase link --project-ref <your-project-ref>
   ```

### Apply migrations

From the repo root:

```bash
supabase db push
```

This applies every pending migration in `supabase/migrations/` to the linked
EU project, in order.

### Re-creating a clean database

The migrations are reproducible: running them against an empty Postgres yields
the full Phase 0 schema. For local development with the bundled stack:

```bash
supabase start          # starts Postgres + Studio locally
supabase db reset       # drops the local DB and replays all migrations
```

## Working rules

Per `CLAUDE.md`: feature branches → PR → `main` always shippable; product /
architecture decisions come from `claude.ai`, not from improvisation in this
repo; every user-visible string goes through `lib/l10n/*.arb`; no hardcoded
secrets anywhere.
