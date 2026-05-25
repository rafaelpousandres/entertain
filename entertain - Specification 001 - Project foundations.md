# Specification 001 — Project foundations

> First build assignment for Claude Code.
> Status: ready for implementation.
> Read `CLAUDE.md` before starting. This specification is the only scope for
> this assignment; do not pull work forward from later phases.

---

## 1. Goal

Stand up the `entertain` project so it compiles, runs, and has the project's
rules and design applied — before any real feature or data work begins. The
deliverable is an app that builds and launches showing a minimal placeholder
screen, with the foundations in place for all later work.

---

## 2. Scope — what to do

### 2.1 Flutter project structure
- Create the Flutter project structure inside this repository (the repository
  root already contains `README.md`, `.gitignore`, `CLAUDE.md`, and the
  reference documents).
- Single codebase, targeting Android first (iOS is a later phase; do not do
  iOS-specific setup now).
- Organize the source tree in a clear, conventional way (e.g. separation of
  app entry, routing, theme, localization, features). Keep it simple — there
  are no features yet.

### 2.2 Base dependencies
Add and configure the base dependencies the project's stack requires:
- **Riverpod** — state management.
- **go_router** — navigation.
- **intl** + ARB files — internationalization.
- **Supabase client** — added and ready, but **not connected to any backend
  data yet**. No schema, no tables, no queries in this assignment.
Do not add dependencies beyond what these foundations need.

### 2.3 Internationalization skeleton
- Set up the i18n mechanism (intl + ARB) with the three base languages:
  Catalan (`ca`), Spanish (`es`), English (`en`).
- Provide the ARB files with a minimal set of strings (enough for the
  placeholder screen). Every user-visible string in the app must come from the
  localization mechanism — no hardcoded literals.

### 2.4 Design system as a Flutter theme
- Translate the design system (see `entertain - Design system.md`) into a
  Flutter theme: the color tokens and the typography (Fraunces for display,
  Nunito Sans for body).
- Define the colors as design tokens so they are referenced by name, not
  hardcoded ad hoc throughout the code.
- The visual base is Material 3.

### 2.5 Secrets and `.gitignore`
- Review and complete `.gitignore` so it excludes environment files and any
  file that could carry secrets (API keys, credentials), in addition to build
  artifacts.
- Establish the mechanism by which configuration values (e.g. the future
  Supabase URL and keys) will be read from environment files **outside** the
  repository. Document briefly, in the repository, where those values are
  expected to live and how they are loaded.
- No secret, key, or credential is committed. There are none yet; the point is
  that the structure is ready to keep it that way.

### 2.6 Placeholder screen
- The app launches to a single minimal placeholder screen that demonstrates
  the foundations are working: it uses the theme (colors, typography) and a
  localized string.
- No real MVP screen, no navigation flows beyond what is needed to show this
  one screen.

---

## 3. Out of scope

Explicitly **not** part of this assignment:
- Any database schema, table, or Supabase data work.
- Any real MVP screen (events, dishes, ingredients, shopping list, settings).
- Authentication (anonymous or otherwise).
- Maps, media, camera.
- CI configuration (GitHub Actions) — a later assignment.
- iOS-specific setup.

---

## 4. Acceptance criteria

The assignment is complete when the user can verify all of the following:

1. The project builds with no errors.
2. The app launches on Android (emulator or device) and shows the placeholder
   screen.
3. The placeholder screen visibly uses the design system: the cream background,
   the terracotta accent, and the two typefaces (Fraunces, Nunito Sans).
4. The placeholder screen's text comes from the localization mechanism, and
   switching the device language between Catalan, Spanish, and English changes
   that text.
5. `git status` shows no environment file or secret-bearing file as tracked or
   untracked-and-about-to-be-committed; `.gitignore` excludes them.
6. The work is on a feature branch with a pull request, leaving `main`
   shippable, per `CLAUDE.md`.

---

## 5. Notes for the implementer

- If anything in this specification is unclear or seems to conflict with
  `CLAUDE.md` or the reference documents, stop and flag it rather than
  improvising a product or architecture decision.
- Flutter and its tooling are not yet installed in the development environment;
  installing and configuring them is part of this assignment.
- Keep the scope lean: the goal is a working skeleton, not a head start on
  features.
