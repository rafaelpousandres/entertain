# CLAUDE.md — entertain

> Operational document for this repository. Claude Code reads it every session.
> Version 0.1.
> Defines the working rules, the stack, and the non-negotiable norms of the
> `entertain` project. Product decisions and technical detail live in the
> documents referenced under "Project documents".

---

## What entertain is

A mobile app for organizing domestic events (lunches and dinners for many
guests): menus, dishes, ingredients, and per-supplier shopping lists sent over
WhatsApp. A single product; this repository is exclusive to this app.

---

## Roles

- **claude.ai** is the management and decision hub: it plans, makes all product,
  design, and architecture decisions, and produces the documents (plan,
  specifications, mockups).
- **Claude Code** (you, in this repository) is the executor: writes the code,
  operates the terminal, sets up the project, builds, and tests.
- **The bridge between the two is the set of versioned documents in the
  repository.** Claude Code works from these files. Do not improvise product or
  architecture decisions here: if a specification is unclear or looks
  incomplete, stop and flag it so it can be resolved on claude.ai.
- **The user** (Rafael Pous) directs the project, makes the important
  decisions, acts as QA by testing the app, and operates the accounts. He does
  not review code line by line.

---

## Working cycle

For each feature or phase: a clear specification is prepared on claude.ai →
Claude Code implements it on a feature branch → the user tests and validates →
back to claude.ai for the next one. Work only on the current specification; do
not pull scope forward from future phases.

---

## Non-negotiable rules

These rules cannot be relaxed without first updating the canonical conventions
document.

- **Secrets out of the code.** No API key, credential, or secret in the code or
  in the repository. They live in environment files excluded via `.gitignore`,
  in Supabase configuration, and in CI secrets. Any third-party API is called
  from a server-side proxy (Edge Function), never directly from the client.
- **Edge Functions need explicit `service_role` grants.** Any table an Edge
  Function reads or writes with the service-role client needs an explicit GRANT
  to `service_role` (SELECT and/or DML per the use). `service_role` has
  BYPASSRLS, but Postgres checks table privileges *before* RLS — so a missing
  grant fails with "permission denied for table …", which the client often
  swallows into a silent fallback (wrong limit, `no_units`, etc.). The 019/020
  grants were made only to `anon`/`authenticated`; every new table a function
  touches must include the `service_role` grant **in its initial migration**.
  Never swallow the error on these service-role reads — log it (`console.error`)
  so the next gap surfaces loudly. (This pattern bit us four times in one
  session: media, translations, quota_entitlements/quota_usage, units/
  supplier_categories.)
- **Data in the EU.** The backend (Supabase) is in an EU region. GDPR-conscious
  design: data minimization, privacy policy, store-required disclosures.
- **Internationalization from day one.** Every user-visible string goes through
  i18n (intl + ARB files). Base languages: Catalan, Spanish, English. No string
  literals hardcoded in the code.
- **Full data model from the start.** The data model is designed for the
  complete vision; phases activate subsets of it and do not redesign it. Do not
  modify it on your own: structural changes are decided on claude.ai and
  reflected in the data model document.
- **Main branch always shippable.** Work on feature branches with pull
  requests. CI runs automated tests and dependency checks. Nothing is merged
  that leaves `main` in a non-shippable state.
- **Lean first.** Each phase is a coherent, usable, shippable release.
  Implement the minimal scope of the current specification; do not add
  unrequested functionality.

---

## Tech stack

> **Flutter is a deliberate legacy exception, not the project default.** Per the
> Development conventions (§4, v0.2), new serious platforms (Talaia, Helm) use the
> unified TypeScript stack (React + React Native + NestJS). Entertain stays on
> Flutter and **is not migrated** — this is a settled decision, not a pending task.

- **Framework:** Flutter (Dart), a single codebase for Android and iOS.
- **Backend:** Supabase — PostgreSQL, Auth, Storage, Edge Functions; EU region.
- **Authentication:** anonymous first, upgradable to a real account with no
  migration.
- **State management:** Riverpod.
- **Navigation:** go_router.
- **i18n:** intl + ARB files.
- **Maps:** Google Maps (`google_maps_flutter`).
- **Media:** device camera/gallery + Supabase Storage.
- **Visual base:** Material 3, with the project's own design system.
- **CI:** GitHub Actions.
- **Builds and release:** Codemagic.
- **Error monitoring:** Sentry, configured not to collect personal data.

---

## Version control

- One repository per product; this is the `entertain` one.
- Work on feature branches; integration into `main` via pull request.
- Semantic versioning; every released version is tagged.
- Environment files with secrets and build artifacts are excluded via
  `.gitignore`.

---

## Release

Android first, iOS later (iOS is a later phase). Play Store tracks: internal
testing → closed testing → production.

---

## Project documents

Detail not covered in this file lives in these documents (in the repository or
managed on claude.ai). When in doubt, consult them; do not improvise.

- **Development plan** — vision, phases, and scope of each phase.
- **Data model** — full schema for the complete vision.
- **Design system** — colors, typography, components, UI patterns.
- **Development conventions** — canonical reusable document (v0.2); this
    `CLAUDE.md` is an operational extract of it adapted to `entertain`.
- **Specifications** — the concrete brief for each feature or phase.

---

## Repository data

- GitHub owner: `rafaelpousandres`
- Repository: `https://github.com/rafaelpousandres/entertain` (private)
- Development environment: WSL2 (Ubuntu) on Windows; the code lives on the
  Linux filesystem.
- **Single canonical repo: `~/claude/entertain` (Linux/WSL).** The Windows
  folder `C:\Users\rafa\Claude\entertain` (`/mnt/c/...`) is **NOT a checkout**:
  it is only a tray where the browser downloads files generated on claude.ai
  (aab, md, pdf, png). **Rule:** any file downloaded on Windows that must become
  part of the repo, copy it into the canonical Linux repo **first**, before any
  commit. **Windows is never the source of truth.**

## House rules
- Specs and project documents live under docs/. Always read the relevant
  spec or document file before working; never work from pasted text.
- One feature branch + PR per spec, phase, or docs pass; commit the spec
  together with the code that implements it.
- Pause for the user's validation of each increment before committing.
- Explain changes and plans in plain language; the user supervises
  architecture and product, not code lines.
- Never put keys or secrets in code, specs, or commits; environment and
  config files stay excluded via .gitignore.
- Commit small and often, with clear messages.
- Validation happens on the user's Pixel 8 Pro.