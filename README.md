# entertain

Mobile app to organize domestic events (lunches and dinners): menus, dishes,
ingredients, and per-supplier shopping lists. Single product, this repository
is exclusive to the app. See `CLAUDE.md` for the operational rules and the
reference documents (data model, design system, development plan,
specifications).

## Stack

- Flutter (Dart), Android first (iOS is a later phase).
- Supabase (EU region) — added but not wired to a backend yet.
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
3. Provide a local environment file (see `Environment` below). It is **not**
   required for spec 001 — without it the app builds and launches but
   Supabase is left uninitialised.
4. Run on a connected Android device or emulator:
   ```bash
   flutter run
   # or, with a local env file:
   flutter run --dart-define-from-file="$HOME/.config/entertain/local.json"
   ```

## Environment

Configuration values that may carry secrets (Supabase URL, anon key, future
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

Build / run examples:

```bash
flutter run   --dart-define-from-file="$HOME/.config/entertain/local.json"
flutter build apk --release \
                  --dart-define-from-file="$HOME/.config/entertain/local.json"
```

Production secrets used by CI live in the CI secret store (later
specification), not in this repository.

## Working rules

Per `CLAUDE.md`: feature branches → PR → `main` always shippable; product /
architecture decisions come from `claude.ai`, not from improvisation in this
repo; every user-visible string goes through `lib/l10n/*.arb`; no hardcoded
secrets anywhere.
